import { runLifestyleWeatherEngine } from '../lifestyle/lifestyleWeatherEngine';
import { WeatherForecast } from '../providers/weather/weatherProvider';
import {
  KmaWarningRegionMatch,
  OfficialWeatherWarning,
} from '../providers/warnings/kmaWarningProvider';
import { regionMetadataForGrid } from '../regions/regionCatalog';
import { runRecommendationEngine } from '../recommendations/recommendationEngine';
import { runWeatherRuleEngineForHourly } from '../rules/weatherRuleEngine';
import {
  CurrentPrecipitationObservation,
  CurrentVisibilityObservation,
  NotificationSettings,
  OfficialRoadControl,
  RoadIceRisk,
  ServerEnv,
} from '../types';
import { FcmPayload, FcmSendResult, sendBatch } from './fcmClient';
import { BuiltNotification, buildNotification } from './notificationBuilder';
import {
  warningDestination,
  weatherDetailsDestination,
} from './notificationDestination';
import {
  activeWarningNotification,
  changedWarningNotification,
  releasedWarningNotification,
} from '../presentation/officialWarningMessages';
import { ROAD_ICE_ROAD_NUMBERS } from '../providers/road/kmaRoadIceProvider';
import { roadIceNotification } from '../presentation/roadIceMessage';
import { roadControlNotification } from '../presentation/roadControlMessage';
import { installationExpirySql } from '../database/dataRetention';
import { safeErrorName } from '../observability/providerErrorDiagnostics';
import {
  collectedCacheKey,
  getCollectedCache,
} from '../database/collectedWeatherRepository';
import type { CollectedRegionBundle, CollectedWarningBundle } from '../collection/collectionTypes';
import { enrichForecastWithVisibility } from '../providers/weather/visibility';

interface NotificationInstallationRow {
  installationId: string;
  token: string;
  nx: number;
  ny: number;
  timezone: string;
  notificationTime: string;
  umbrellaEnabled: number;
  parasolEnabled: number;
  heavySnowEnabled: number;
  outerwearEnabled: number;
  maskEnabled: number;
  waterEnabled: number;
  sunscreenEnabled: number;
  dailyWeatherEnabled: number;
  heavyRainEnabled: number;
  heatwaveEnabled: number;
  coldWaveEnabled: number;
  showerAndLightRainEnabled: number;
  latitude: number | null;
  longitude: number | null;
  currentRainState: number;
  roadIceLevel: number;
  roadIceLinkId: string | null;
  roadControlEventKey: string | null;
  roadControlKind: 'FULL' | 'PARTIAL' | null;
}

interface PendingNotification {
  installationId: string;
  targetDate: string;
  token: string;
  built: BuiltNotification;
  rainObservedAt?: string;
  warningStateMutation?: WarningStateMutation;
  roadIceRisk?: RoadIceRisk;
  roadControl?: OfficialRoadControl;
}

interface WarningStateRow {
  typeCode: string;
  typeName: string;
  levelCode: '2' | '3';
  levelName: '주의보' | '경보';
  regionName: string;
  effectiveAt: string;
}

type WarningStateMutation =
  | { operation: 'UPSERT'; warning: OfficialWeatherWarning }
  | { operation: 'DELETE'; typeCode: string };

interface SchedulerDependencies {
  now?: Date;
  retentionNow?: Date;
  forecastLoader?: (
    env: ServerEnv,
    nx: number,
    ny: number,
    coordinates?: { latitude: number; longitude: number },
  ) => Promise<WeatherForecast>;
  sender?: (
    env: ServerEnv,
    payloads: FcmPayload[],
  ) => Promise<FcmSendResult[]>;
  precipitationLoader?: (
    env: ServerEnv,
    latitude: number,
    longitude: number,
  ) => Promise<CurrentPrecipitationObservation>;
  warningLoader?: (
    env: ServerEnv,
    regionIds: readonly string[],
  ) => Promise<OfficialWeatherWarning[]>;
  warningRegionResolver?: (
    env: ServerEnv,
    latitude: number,
    longitude: number,
  ) => Promise<KmaWarningRegionMatch>;
  roadIceLoader?: (
    env: ServerEnv,
    latitude: number,
    longitude: number,
    roadNumbers: readonly string[],
  ) => Promise<RoadIceRisk | undefined>;
  roadControlLoader?: (
    env: ServerEnv,
    latitude: number,
    longitude: number,
  ) => Promise<OfficialRoadControl | undefined>;
}

export async function runRecommendationNotificationJob(
  env: ServerEnv,
  dependencies: SchedulerDependencies = {},
): Promise<void> {
  const now = dependencies.now ?? new Date();
  const rows = await notificationInstallations(env.DB, dependencies.retentionNow ?? now);
  if (rows.length === 0) return;

  const loadForecast = dependencies.forecastLoader ?? defaultForecastLoader;
  const forecastByRegion = new Map<string, Promise<WeatherForecast>>();
  const precipitationByLocation = new Map<
    string,
    Promise<CurrentPrecipitationObservation>
  >();
  const warningsByRegion = new Map<
    string,
    Promise<OfficialWeatherWarning[]>
  >();
  const warningRegionsByLocation = new Map<
    string,
    Promise<KmaWarningRegionMatch>
  >();
  const roadIceByLocation = new Map<string, Promise<RoadIceRisk | undefined>>();
  const roadControlByLocation = new Map<
    string,
    Promise<OfficialRoadControl | undefined>
  >();
  const pending: PendingNotification[] = [];

  for (const row of rows) {
    const local = localNotificationTime(now, row.timezone);
    await collectCurrentRainNotification(
      env,
      row,
      local.date,
      pending,
      precipitationByLocation,
      dependencies.precipitationLoader ?? defaultPrecipitationLoader,
    );
    await collectOfficialWarningNotifications(
      env,
      row,
      local.date,
      pending,
      warningsByRegion,
      warningRegionsByLocation,
      dependencies.warningLoader ?? defaultWarningLoader,
      dependencies.warningRegionResolver ?? defaultWarningRegionResolver,
    );
    await collectRoadIceNotification(
      env,
      row,
      local.date,
      pending,
      roadIceByLocation,
      dependencies.roadIceLoader ?? defaultRoadIceLoader,
    );
    await collectRoadControlNotification(
      env,
      row,
      local.date,
      pending,
      roadControlByLocation,
      dependencies.roadControlLoader ?? defaultRoadControlLoader,
    );
    const regionKey = `${row.nx}:${row.ny}`;
    let forecastPromise = forecastByRegion.get(regionKey);
    if (!forecastPromise) {
      forecastPromise = loadForecast(
        env,
        row.nx,
        row.ny,
        row.latitude !== null && row.longitude !== null
          ? { latitude: row.latitude, longitude: row.longitude }
          : undefined,
      );
      forecastByRegion.set(regionKey, forecastPromise);
    }

    try {
      const forecast = await forecastPromise;
      const hourly = forecast.hourly.slice(0, 24);
      const rules = runWeatherRuleEngineForHourly(hourly, undefined, now);
      const insights = runLifestyleWeatherEngine(rules, hourly, now);
      const recommendations = runRecommendationEngine(
        insights,
        settingsFromRow(row),
      ).filter(
        (recommendation) =>
          recommendation.recommended && recommendation.notificationEligible,
      );
      const alreadySent = await sentNotificationKeys(
        env.DB,
        row.installationId,
        local.date,
      );
      const notifications = buildNotification(
        recommendations,
        now,
        forecast,
      ).filter(
        (notification) => {
          if (alreadySent.has(notification.notification_key)) return false;
          if (notification.notification_key === 'MORNING_BRIEF') {
            return (
              row.dailyWeatherEnabled === 1 &&
              isNotificationTimeDue(local.time, row.notificationTime)
            );
          }
          return true;
        },
      );

      for (const built of notifications) {
        pending.push({
          installationId: row.installationId,
          targetDate: local.date,
          token: row.token,
          built,
        });
      }
    } catch (error) {
      logNotificationError('recommendation_build_failed', error);
    }
  }

  if (pending.length === 0) return;
  // The job can spend seconds loading providers. Recheck the installation and
  // current token immediately before sending; deletion may have happened meanwhile.
  const eligible = await env.DB.batch(pending.map((item) => env.DB.prepare(`SELECT 1 FROM installations i
    LEFT JOIN notification_settings s ON s.installation_id = i.installation_id
    WHERE i.installation_id = ? AND i.fcm_token = ? AND COALESCE(s.notification_enabled, 0) = 1
      AND i.minimum_age_confirmed_at IS NOT NULL AND i.age_policy_version = 1
      AND NOT EXISTS (SELECT 1 FROM installation_activity a
        WHERE a.installation_id = i.installation_id AND ${installationExpirySql} <= julianday(?))`)
    .bind(item.installationId, item.token,
      (dependencies.retentionNow ?? dependencies.now ?? new Date()).toISOString())));
  const sendable = pending.filter((_, index) => eligible[index].results.length > 0);
  if (!sendable.length) return;
  const payloads = sendable.map<FcmPayload>((item) => ({
    token: item.token,
    title: item.built.title,
    body: item.built.body,
    notificationKey: item.built.notification_key,
    notificationTarget: item.built.destination.target,
    notificationTopic: item.built.destination.topic,
  }));
  const results = await (dependencies.sender ?? defaultSender)(env, payloads);
  await recordResults(env.DB, sendable, results, now.toISOString());
}

async function notificationInstallations(
  db: D1Database,
  now: Date,
): Promise<NotificationInstallationRow[]> {
  const result = await db
    .prepare(
      `SELECT
         i.installation_id AS installationId,
         i.fcm_token AS token,
         i.nx,
         i.ny,
         i.timezone,
         COALESCE(s.notification_time, '07:00') AS notificationTime,
         COALESCE(s.umbrella_enabled, 1) AS umbrellaEnabled,
         COALESCE(s.parasol_enabled, 1) AS parasolEnabled,
         COALESCE(s.heavy_snow_enabled, 1) AS heavySnowEnabled,
         COALESCE(s.outerwear_enabled, 1) AS outerwearEnabled,
         COALESCE(s.mask_enabled, 1) AS maskEnabled,
         COALESCE(s.water_enabled, 1) AS waterEnabled,
         COALESCE(s.sunscreen_enabled, 1) AS sunscreenEnabled,
         COALESCE(s.daily_weather_enabled, 1) AS dailyWeatherEnabled,
         COALESCE(s.heavy_rain_enabled, 1) AS heavyRainEnabled,
         COALESCE(s.heatwave_enabled, 1) AS heatwaveEnabled,
         COALESCE(s.cold_wave_enabled, 1) AS coldWaveEnabled,
         COALESCE(s.shower_light_rain_enabled, 1) AS showerAndLightRainEnabled,
         i.latitude,
         i.longitude,
         COALESCE(i.current_rain_state, 0) AS currentRainState,
         COALESCE(i.road_ice_level, 0) AS roadIceLevel,
         i.road_ice_link_id AS roadIceLinkId,
         i.road_control_event_key AS roadControlEventKey,
         i.road_control_kind AS roadControlKind
       FROM installations i
       LEFT JOIN notification_settings s
         ON s.installation_id = i.installation_id
       WHERE i.fcm_token IS NOT NULL
          AND TRIM(i.fcm_token) <> ''
          AND i.minimum_age_confirmed_at IS NOT NULL
          AND i.age_policy_version = 1
          AND COALESCE(s.notification_enabled, 0) = 1
         AND NOT EXISTS (SELECT 1 FROM installation_activity a
           WHERE a.installation_id = i.installation_id AND ${installationExpirySql} <= julianday(?))`,
    )
    .bind(now.toISOString())
    .all<NotificationInstallationRow>();
  return result.results;
}

async function sentNotificationKeys(
  db: D1Database,
  installationId: string,
  targetDate: string,
): Promise<Set<string>> {
  const result = await db
    .prepare(
      `SELECT notification_key AS notificationKey
       FROM notification_history
       WHERE installation_id = ? AND target_date = ?`,
    )
    .bind(installationId, targetDate)
    .all<{ notificationKey: string }>();
  return new Set(result.results.map((row) => row.notificationKey));
}

async function defaultForecastLoader(
  env: ServerEnv,
  nx: number,
  ny: number,
  coordinates?: { latitude: number; longitude: number },
): Promise<WeatherForecast> {
  const [cached, visibility] = await Promise.all([
    getCollectedCache<CollectedRegionBundle>(
      env.DB,
      `COLLECTED_REGION_${nx}_${ny}`,
    ),
    getCollectedCache<CurrentVisibilityObservation>(
      env.DB,
      collectedCacheKey.visibility(nx, ny),
    ),
  ]);
  if (!cached || cached.status !== 'AVAILABLE') {
    throw new Error('COLLECTED_FORECAST_NOT_READY');
  }
  return enrichForecastWithVisibility(
    cached.value.forecast,
    visibility?.value,
    new Date(),
  );
}

async function defaultSender(
  env: ServerEnv,
  payloads: FcmPayload[],
): Promise<FcmSendResult[]> {
  return sendBatch(
    {
      projectId: env.FCM_PROJECT_ID,
      clientEmail: env.FCM_CLIENT_EMAIL,
      privateKey: env.FCM_PRIVATE_KEY,
    },
    payloads,
  );
}

async function defaultPrecipitationLoader(
  env: ServerEnv,
  latitude: number,
  longitude: number,
): Promise<CurrentPrecipitationObservation> {
  const cached = await getCollectedCache<CurrentPrecipitationObservation>(
    env.DB,
    collectedCacheKey.precipitation(latitude, longitude),
  );
  if (!cached || cached.status !== 'AVAILABLE') {
    throw new Error('COLLECTED_PRECIPITATION_NOT_READY');
  }
  return cached.value;
}

async function defaultWarningLoader(
  env: ServerEnv,
  regionIds: readonly string[],
): Promise<OfficialWeatherWarning[]> {
  const result = await env.DB.prepare(
    `SELECT payload FROM weather_cache
     WHERE cache_type = 'COLLECTED_WARNING' AND status = 'AVAILABLE'`,
  ).all<{ payload: string }>();
  const requested = new Set(regionIds);
  return result.results.flatMap((row) => {
    try {
      const bundle = JSON.parse(row.payload) as CollectedWarningBundle;
      return bundle.warnings.filter((warning) => requested.has(warning.regionId));
    } catch {
      return [];
    }
  });
}

async function defaultWarningRegionResolver(
  env: ServerEnv,
  latitude: number,
  longitude: number,
): Promise<KmaWarningRegionMatch> {
  throw new Error('COLLECTED_WARNING_REGION_NOT_READY');
}

async function defaultRoadIceLoader(
  env: ServerEnv,
  latitude: number,
  longitude: number,
  roadNumbers: readonly string[],
): Promise<RoadIceRisk | undefined> {
  const cached = await getCollectedCache<RoadIceRisk | null>(
    env.DB,
    collectedCacheKey.roadIce(latitude, longitude),
  );
  return cached?.value ?? undefined;
}

async function defaultRoadControlLoader(
  env: ServerEnv,
  latitude: number,
  longitude: number,
): Promise<OfficialRoadControl | undefined> {
  const cached = await getCollectedCache<OfficialRoadControl | null>(
    env.DB,
    collectedCacheKey.roadControl(latitude, longitude),
  );
  return cached?.value ?? undefined;
}

async function collectRoadIceNotification(
  env: ServerEnv,
  row: NotificationInstallationRow,
  targetDate: string,
  pending: PendingNotification[],
  roadIceByLocation: Map<string, Promise<RoadIceRisk | undefined>>,
  loader: (
    env: ServerEnv,
    latitude: number,
    longitude: number,
    roadNumbers: readonly string[],
  ) => Promise<RoadIceRisk | undefined>,
): Promise<void> {
  if (row.latitude === null || row.longitude === null) return;
  const region = regionMetadataForGrid(row.nx, row.ny);
  const displayRegionName = region?.name ?? '현재 위치';
  const locationKey = [
    row.latitude.toFixed(5),
    row.longitude.toFixed(5),
  ].join(':');
  let riskPromise = roadIceByLocation.get(locationKey);
  if (!riskPromise) {
    riskPromise = loader(
      env,
      row.latitude,
      row.longitude,
      ROAD_ICE_ROAD_NUMBERS,
    );
    roadIceByLocation.set(locationKey, riskPromise);
  }

  try {
    const risk = await riskPromise;
    if (!risk) {
      if (row.roadIceLevel > 0) {
        await resetRoadIceState(env.DB, row.installationId);
      }
      return;
    }
    if (
      row.roadIceLevel === risk.level &&
      row.roadIceLinkId === risk.linkId
    ) {
      return;
    }
    const content = roadIceNotification(risk, displayRegionName);
    pending.push({
      installationId: row.installationId,
      targetDate,
      token: row.token,
      built: {
        notification_key: `ROAD_ICE_${risk.linkId}_${risk.level}_${risk.producedAt.replace(/\D/g, '')}`,
        title: content.title,
        body: content.body,
        destination: weatherDetailsDestination('ROAD_ICE'),
      },
      roadIceRisk: risk,
    });
  } catch (error) {
    logNotificationError('road_ice_build_failed', error);
  }
}

async function resetRoadIceState(
  db: D1Database,
  installationId: string,
): Promise<void> {
  await db
    .prepare(
      `UPDATE installations
       SET road_ice_level = 0,
           road_ice_link_id = NULL,
           road_ice_observed_at = NULL,
           updated_at = ?
       WHERE installation_id = ?`,
    )
    .bind(new Date().toISOString(), installationId)
    .run();
}

async function collectRoadControlNotification(
  env: ServerEnv,
  row: NotificationInstallationRow,
  targetDate: string,
  pending: PendingNotification[],
  roadControlByLocation: Map<
    string,
    Promise<OfficialRoadControl | undefined>
  >,
  loader: (
    env: ServerEnv,
    latitude: number,
    longitude: number,
  ) => Promise<OfficialRoadControl | undefined>,
): Promise<void> {
  if (row.latitude === null || row.longitude === null) return;
  const locationKey = `${row.latitude.toFixed(5)}:${row.longitude.toFixed(5)}`;
  let controlPromise = roadControlByLocation.get(locationKey);
  if (!controlPromise) {
    controlPromise = loader(env, row.latitude, row.longitude);
    roadControlByLocation.set(locationKey, controlPromise);
  }

  try {
    const control = await controlPromise;
    if (!control) {
      if (row.roadControlEventKey) {
        await resetRoadControlState(env.DB, row.installationId);
      }
      return;
    }
    if (
      row.roadControlEventKey === control.eventKey &&
      row.roadControlKind === control.controlKind
    ) {
      return;
    }
    const content = roadControlNotification(control);
    pending.push({
      installationId: row.installationId,
      targetDate,
      token: row.token,
      built: {
        notification_key: `ROAD_CONTROL_${notificationSafeKey(control.eventKey)}_${control.controlKind}`,
        title: content.title,
        body: content.body,
        destination: weatherDetailsDestination('COMMUTE'),
      },
      roadControl: control,
    });
  } catch (error) {
    logNotificationError('road_control_build_failed', error);
  }
}

async function resetRoadControlState(
  db: D1Database,
  installationId: string,
): Promise<void> {
  await db
    .prepare(
      `UPDATE installations
       SET road_control_event_key = NULL,
           road_control_kind = NULL,
           road_control_started_at = NULL,
           updated_at = ?
       WHERE installation_id = ?`,
    )
    .bind(new Date().toISOString(), installationId)
    .run();
}

function notificationSafeKey(value: string): string {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16);
}

async function collectOfficialWarningNotifications(
  env: ServerEnv,
  row: NotificationInstallationRow,
  targetDate: string,
  pending: PendingNotification[],
  warningsByRegion: Map<string, Promise<OfficialWeatherWarning[]>>,
  warningRegionsByLocation: Map<string, Promise<KmaWarningRegionMatch>>,
  loader: (
    env: ServerEnv,
    regionIds: readonly string[],
  ) => Promise<OfficialWeatherWarning[]>,
  regionResolver: (
    env: ServerEnv,
    latitude: number,
    longitude: number,
  ) => Promise<KmaWarningRegionMatch>,
): Promise<void> {
  let regionKey = `${row.nx}:${row.ny}`;

  try {
    const catalogRegion = regionMetadataForGrid(row.nx, row.ny);
    let regionIds: readonly string[];
    let displayRegionName: string;
    if (catalogRegion) {
      regionIds = catalogRegion.warningRegionIds;
      displayRegionName = catalogRegion.name;
    } else {
      if (row.latitude === null || row.longitude === null) return;
      const locationKey = `${row.latitude.toFixed(5)}:${row.longitude.toFixed(5)}`;
      let matchPromise = warningRegionsByLocation.get(locationKey);
      if (!matchPromise) {
        matchPromise = regionResolver(env, row.latitude, row.longitude);
        warningRegionsByLocation.set(locationKey, matchPromise);
      }
      const match = await matchPromise;
      regionIds = [match.regionId];
      displayRegionName = match.regionName;
    }
    if (regionIds.length === 0) return;
    regionKey = regionIds.join(',');
    let warningsPromise = warningsByRegion.get(regionKey);
    if (!warningsPromise) {
      warningsPromise = loader(env, regionIds);
      warningsByRegion.set(regionKey, warningsPromise);
    }

    const current = highestWarningByType(await warningsPromise);
    const previous = await warningStates(env.DB, row.installationId);
    const previousByType = new Map(previous.map((item) => [item.typeCode, item]));

    for (const warning of current.values()) {
      const before = previousByType.get(warning.typeCode);
      if (!before) {
        await queueOrApplyWarningTransition(
          env.DB,
          row,
          targetDate,
          pending,
          warningKey('ACTIVE', warning.typeCode, warning.validFrom),
          activeWarningNotification(warning, displayRegionName),
          { operation: 'UPSERT', warning },
        );
      } else if (before.levelCode !== warning.levelCode) {
        await queueOrApplyWarningTransition(
          env.DB,
          row,
          targetDate,
          pending,
          warningKey('CHANGED', warning.typeCode, warning.validFrom),
          changedWarningNotification(
            warning,
            before.levelName,
            displayRegionName,
          ),
          { operation: 'UPSERT', warning },
        );
      } else if (
        before.effectiveAt !== warning.validFrom ||
        before.regionName !== warning.regionName
      ) {
        await applyWarningStateMutation(env.DB, row.installationId, {
          operation: 'UPSERT',
          warning,
        });
      }
      previousByType.delete(warning.typeCode);
    }

    for (const before of previousByType.values()) {
      await queueOrApplyWarningTransition(
        env.DB,
        row,
        targetDate,
        pending,
        warningKey('RELEASED', before.typeCode, before.effectiveAt),
        releasedWarningNotification(
          { type: before.typeName, level: before.levelName },
          displayRegionName,
        ),
        { operation: 'DELETE', typeCode: before.typeCode },
      );
    }
  } catch (error) {
    logNotificationError('official_warning_build_failed', error);
  }
}

async function queueOrApplyWarningTransition(
  db: D1Database,
  row: NotificationInstallationRow,
  targetDate: string,
  pending: PendingNotification[],
  notificationKey: string,
  content: { title: string; body: string },
  mutation: WarningStateMutation,
): Promise<void> {
  const typeCode =
    mutation.operation === 'UPSERT'
      ? mutation.warning.typeCode
      : mutation.typeCode;
  if (!isWarningNotificationEnabled(row, typeCode)) {
    await applyWarningStateMutation(db, row.installationId, mutation);
    return;
  }
  pending.push({
    installationId: row.installationId,
    targetDate,
    token: row.token,
    built: {
      notification_key: notificationKey,
      title: content.title,
      body: content.body,
      destination: warningDestination(typeCode),
    },
    warningStateMutation: mutation,
  });
}

function highestWarningByType(
  warnings: readonly OfficialWeatherWarning[],
): Map<string, OfficialWeatherWarning> {
  const selected = new Map<string, OfficialWeatherWarning>();
  for (const warning of warnings) {
    const current = selected.get(warning.typeCode);
    if (!current || Number(warning.levelCode) > Number(current.levelCode)) {
      selected.set(warning.typeCode, warning);
    }
  }
  return selected;
}

async function warningStates(
  db: D1Database,
  installationId: string,
): Promise<WarningStateRow[]> {
  const result = await db
    .prepare(
      `SELECT warning_type AS typeCode,
              warning_name AS typeName,
              level_code AS levelCode,
              level_name AS levelName,
              region_name AS regionName,
              effective_at AS effectiveAt
       FROM installation_warning_state
       WHERE installation_id = ?`,
    )
    .bind(installationId)
    .all<WarningStateRow>();
  return result.results;
}

async function applyWarningStateMutation(
  db: D1Database,
  installationId: string,
  mutation: WarningStateMutation,
): Promise<void> {
  if (mutation.operation === 'DELETE') {
    await db
      .prepare(
        `DELETE FROM installation_warning_state
         WHERE installation_id = ? AND warning_type = ?`,
      )
      .bind(installationId, mutation.typeCode)
      .run();
    return;
  }

  const warning = mutation.warning;
  await db
    .prepare(
      `INSERT INTO installation_warning_state
       (installation_id, warning_type, warning_name, level_code, level_name,
        region_name, effective_at, updated_at)
       SELECT ?, ?, ?, ?, ?, ?, ?, ? WHERE EXISTS
         (SELECT 1 FROM installations WHERE installation_id = ?)
       ON CONFLICT(installation_id, warning_type) DO UPDATE SET
         warning_name = excluded.warning_name,
         level_code = excluded.level_code,
         level_name = excluded.level_name,
         region_name = excluded.region_name,
         effective_at = excluded.effective_at,
         updated_at = excluded.updated_at`,
    )
    .bind(
      installationId,
      warning.typeCode,
      warning.type,
      warning.levelCode,
      warning.level,
      warning.regionName,
      warning.validFrom,
      new Date().toISOString(),
      installationId,
    )
    .run();
}

function isWarningNotificationEnabled(
  row: NotificationInstallationRow,
  typeCode: string,
): boolean {
  if (typeCode === 'R') return row.heavyRainEnabled === 1;
  if (typeCode === 'S') return row.heavySnowEnabled === 1;
  if (typeCode === 'H') return row.heatwaveEnabled === 1;
  if (typeCode === 'C') return row.coldWaveEnabled === 1;
  return true;
}

function warningKey(
  transition: 'ACTIVE' | 'CHANGED' | 'RELEASED',
  typeCode: string,
  effectiveAt: string,
): string {
  return `OFFICIAL_WARNING_${transition}_${typeCode}_${effectiveAt.replace(/\D/g, '')}`;
}

async function collectCurrentRainNotification(
  env: ServerEnv,
  row: NotificationInstallationRow,
  targetDate: string,
  pending: PendingNotification[],
  precipitationByLocation: Map<
    string,
    Promise<CurrentPrecipitationObservation>
  >,
  loader: (
    env: ServerEnv,
    latitude: number,
    longitude: number,
  ) => Promise<CurrentPrecipitationObservation>,
): Promise<void> {
  if (row.latitude === null || row.longitude === null) return;
  const locationKey = `${row.latitude.toFixed(5)}:${row.longitude.toFixed(5)}`;
  let observationPromise = precipitationByLocation.get(locationKey);
  if (!observationPromise) {
    observationPromise = loader(env, row.latitude, row.longitude);
    precipitationByLocation.set(locationKey, observationPromise);
  }

  try {
    const observation = await observationPromise;
    if (observation.state === 'MISMATCH') return;
    if (observation.state === 'DRY') {
      if (row.currentRainState === 1) {
        await updateCurrentRainState(
          env.DB,
          row.installationId,
          false,
          observation.observedAt,
        );
      }
      return;
    }
    if (row.currentRainState === 1) return;
    if (row.umbrellaEnabled !== 1 || row.showerAndLightRainEnabled !== 1) {
      await updateCurrentRainState(
        env.DB,
        row.installationId,
        true,
        observation.observedAt,
      );
      return;
    }
    pending.push({
      installationId: row.installationId,
      targetDate,
      token: row.token,
      built: {
        notification_key: 'CURRENT_RAIN',
        title: '현재 강수 안내',
        body: '비가 내리고 있을 수 있어요.\n지금 외출한다면 우산을 챙기세요',
        destination: weatherDetailsDestination('PRECIPITATION'),
      },
      rainObservedAt: observation.observedAt,
    });
  } catch (error) {
    logNotificationError('current_rain_build_failed', error);
  }
}

async function updateCurrentRainState(
  db: D1Database,
  installationId: string,
  raining: boolean,
  observedAt: string,
): Promise<void> {
  await db
    .prepare(
      `UPDATE installations
       SET current_rain_state = ?, current_rain_observed_at = ?, updated_at = ?
       WHERE installation_id = ?`,
    )
    .bind(
      raining ? 1 : 0,
      observedAt,
      new Date().toISOString(),
      installationId,
    )
    .run();
}

async function recordResults(
  db: D1Database,
  pending: PendingNotification[],
  results: FcmSendResult[],
  sentAt: string,
): Promise<void> {
  const statements: D1PreparedStatement[] = [];
  results.forEach((result, index) => {
    const item = pending[index];
    if (!item) return;
    if (result.success) {
      statements.push(
        db
          .prepare(
            `INSERT OR IGNORE INTO notification_history
             (installation_id, target_date, notification_key, sent_at, payload_hash)
             SELECT ?, ?, ?, ?, ? WHERE EXISTS
               (SELECT 1 FROM installations WHERE installation_id = ?)`,
          )
          .bind(
            item.installationId,
            item.targetDate,
            item.built.notification_key,
            sentAt,
            `${item.built.title}\n${item.built.body}`.slice(0, 160),
            item.installationId,
          ),
      );
      if (item.rainObservedAt) {
        statements.push(
          db
            .prepare(
              `UPDATE installations
               SET current_rain_state = 1,
                   current_rain_observed_at = ?,
                   updated_at = ?
               WHERE installation_id = ?`,
            )
            .bind(item.rainObservedAt, sentAt, item.installationId),
        );
      }
      if (item.warningStateMutation) {
        const mutation = item.warningStateMutation;
        if (mutation.operation === 'DELETE') {
          statements.push(
            db
              .prepare(
                `DELETE FROM installation_warning_state
                 WHERE installation_id = ? AND warning_type = ?`,
              )
              .bind(item.installationId, mutation.typeCode),
          );
        } else {
          const warning = mutation.warning;
          statements.push(
            db
              .prepare(
                `INSERT INTO installation_warning_state
                 (installation_id, warning_type, warning_name, level_code,
                  level_name, region_name, effective_at, updated_at)
                 SELECT ?, ?, ?, ?, ?, ?, ?, ? WHERE EXISTS
                   (SELECT 1 FROM installations WHERE installation_id = ?)
                 ON CONFLICT(installation_id, warning_type) DO UPDATE SET
                   warning_name = excluded.warning_name,
                   level_code = excluded.level_code,
                   level_name = excluded.level_name,
                   region_name = excluded.region_name,
                   effective_at = excluded.effective_at,
                   updated_at = excluded.updated_at`,
              )
              .bind(
                item.installationId,
                warning.typeCode,
                warning.type,
                warning.levelCode,
                warning.level,
                warning.regionName,
                warning.validFrom,
                sentAt,
                item.installationId,
              ),
          );
        }
      }
      if (item.roadIceRisk) {
        statements.push(
          db
            .prepare(
              `UPDATE installations
               SET road_ice_level = ?,
                   road_ice_link_id = ?,
                   road_ice_observed_at = ?,
                   updated_at = ?
               WHERE installation_id = ?`,
            )
            .bind(
              item.roadIceRisk.level,
              item.roadIceRisk.linkId,
              item.roadIceRisk.producedAt,
              sentAt,
              item.installationId,
            ),
        );
      }
      if (item.roadControl) {
        statements.push(
          db
            .prepare(
              `UPDATE installations
               SET road_control_event_key = ?,
                   road_control_kind = ?,
                   road_control_started_at = ?,
                   updated_at = ?
               WHERE installation_id = ?`,
            )
            .bind(
              item.roadControl.eventKey,
              item.roadControl.controlKind,
              item.roadControl.startedAt,
              sentAt,
              item.installationId,
            ),
        );
      }
    } else {
      logNotificationError('fcm_send_failed', undefined, result.status);
    }
    if (result.unregistered) {
      statements.push(
        db
          .prepare(
            `UPDATE installations
             SET fcm_token = NULL, updated_at = ?
             WHERE installation_id = ? AND fcm_token = ?`,
          )
          .bind(sentAt, item.installationId, item.token),
      );
    }
  });
  if (statements.length > 0) await db.batch(statements);
}

function settingsFromRow(
  row: NotificationInstallationRow,
): Partial<NotificationSettings> {
  return {
    umbrellaEnabled: row.umbrellaEnabled === 1,
    parasolEnabled: row.parasolEnabled === 1,
    heavySnowEnabled: row.heavySnowEnabled === 1,
    outerwearEnabled: row.outerwearEnabled === 1,
    maskEnabled: row.maskEnabled === 1,
    waterEnabled: row.waterEnabled === 1,
    sunscreenEnabled: row.sunscreenEnabled === 1,
    dailyWeatherEnabled: row.dailyWeatherEnabled === 1,
    heavyRainEnabled: row.heavyRainEnabled === 1,
    heatwaveEnabled: row.heatwaveEnabled === 1,
    coldWaveEnabled: row.coldWaveEnabled === 1,
  };
}

export function isNotificationTimeDue(
  currentTime: string,
  notificationTime: string,
): boolean {
  const current = minutesOfDay(currentTime);
  const target = minutesOfDay(notificationTime);
  if (current === undefined || target === undefined) return false;
  return current === (Math.ceil(target / 10) * 10) % (24 * 60);
}

function localNotificationTime(
  now: Date,
  timezone: string,
): { date: string; time: string } {
  try {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(now);
    const part = (type: Intl.DateTimeFormatPartTypes) =>
      parts.find((item) => item.type === type)?.value ?? '';
    return {
      date: `${part('year')}-${part('month')}-${part('day')}`,
      time: `${part('hour')}:${part('minute')}`,
    };
  } catch {
    return localNotificationTime(now, 'Asia/Seoul');
  }
}

function minutesOfDay(value: string): number | undefined {
  const match = /^(\d{2}):(\d{2})$/.exec(value);
  if (!match) return undefined;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return undefined;
  return hour * 60 + minute;
}

function logNotificationError(
  event:
    | 'recommendation_build_failed'
    | 'current_rain_build_failed'
    | 'official_warning_build_failed'
    | 'road_ice_build_failed'
    | 'road_control_build_failed'
    | 'fcm_send_failed',
  error: unknown,
  status?: number,
): void {
  console.error(
    JSON.stringify({
      event,
      ...(status !== undefined && Number.isInteger(status) && status >= 100 && status <= 599 ? { status } : {}),
      error: error === undefined ? undefined : safeErrorName(error),
    }),
  );
}
