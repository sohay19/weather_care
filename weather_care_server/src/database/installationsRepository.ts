import { Installation } from '../types';

export async function upsertInstallation(
  db: D1Database,
  payload: Installation,
  ownerHash?: string,
): Promise<boolean> {
  const now = new Date().toISOString();
  const measuredAt = payload.locationMeasuredAt
    ? new Date(payload.locationMeasuredAt).toISOString() : now;
  const keepNewer = `excluded.location_mode = 'GPS' AND installations.location_mode = 'GPS'
    AND installations.location_measured_at > excluded.location_measured_at`;
  const result = await db
    .prepare(
      `INSERT INTO installations
       (installation_id, fcm_token, nx, ny, region_topic, location_mode, platform, app_version, timezone, latitude, longitude,
        minimum_age_confirmed_at, age_policy_version, created_at, updated_at, location_measured_at)
       SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
       ${ownerHash === undefined ? 'WHERE 1' : `WHERE EXISTS (SELECT 1 FROM installation_credentials
         WHERE installation_id = ? AND secret_hash = ?)`}
       ON CONFLICT(installation_id) DO UPDATE SET
         fcm_token=excluded.fcm_token,
         nx=CASE WHEN ${keepNewer} THEN installations.nx ELSE excluded.nx END,
         ny=CASE WHEN ${keepNewer} THEN installations.ny ELSE excluded.ny END,
         region_topic=CASE WHEN ${keepNewer} THEN installations.region_topic ELSE excluded.region_topic END,
         location_mode=excluded.location_mode,
         platform=excluded.platform,
         app_version=excluded.app_version,
         timezone=excluded.timezone,
         latitude=CASE WHEN ${keepNewer} THEN installations.latitude ELSE excluded.latitude END,
         longitude=CASE WHEN ${keepNewer} THEN installations.longitude ELSE excluded.longitude END,
         location_measured_at=CASE WHEN ${keepNewer} THEN installations.location_measured_at ELSE excluded.location_measured_at END,
         background_location_revision=CASE WHEN excluded.location_mode = 'MANUAL' THEN NULL ELSE installations.background_location_revision END,
         minimum_age_confirmed_at=excluded.minimum_age_confirmed_at,
         age_policy_version=excluded.age_policy_version,
         updated_at=excluded.updated_at`,
    )
    .bind(
      payload.installationId,
      payload.fcmToken ?? null,
      payload.nx,
      payload.ny,
      payload.regionTopic,
      payload.locationMode,
      payload.platform ?? null,
      payload.appVersion ?? null,
      payload.timezone,
      payload.latitude ?? null,
      payload.longitude ?? null,
      payload.minimumAgeConfirmed ? now : null,
      payload.agePolicyVersion,
      now,
      now,
      measuredAt,
      ...(ownerHash === undefined ? [] : [payload.installationId, ownerHash]),
    )
    .run();
  return result.meta.changes > 0;
}

export async function upsertRegionSubscription(
  db: D1Database,
  topic: string,
): Promise<void> {
  const pieces = topic.split('_');
  const nx = parseInt(pieces[1] ?? '60', 10);
  const ny = parseInt(pieces[2] ?? '121', 10);
  const exists = await db.prepare('SELECT topic FROM active_regions WHERE topic = ?').bind(topic).first();
  if (!exists) {
    await db
      .prepare(
        `INSERT INTO active_regions
         (region_id, topic, nx, ny, subscriber_count, updated_at)
         VALUES (?, ?, ?, ?, 1, ?)`,
      )
      .bind(topic, topic, nx, ny, new Date().toISOString())
      .run();
  } else {
    await db
      .prepare(`UPDATE active_regions SET subscriber_count = subscriber_count + 1, updated_at = ? WHERE topic = ?`)
      .bind(new Date().toISOString(), topic)
      .run();
  }
}
