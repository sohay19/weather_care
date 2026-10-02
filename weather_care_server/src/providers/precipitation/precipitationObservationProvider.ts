import {
  CurrentPrecipitationObservation,
  PrecipitationConsensusState,
} from '../../types';
import {
  kmaApiHubErrorReason,
  kmaApiHubErrorStatus,
} from '../kmaApiHubResponse';
import { providerHttpFailureMessage } from '../providerHttpFailure';
import { mapWithConcurrency } from '../../utils/concurrencyLimiter';

const ANALYSIS_POINT_URL =
  'https://apihub.kma.go.kr/api/typ01/cgi-bin/url/nph-sfc_obs_nc_pt_api';
const ANALYSIS_NATIONWIDE_URL =
  'https://apihub.kma.go.kr/api/typ01/cgi-bin/url/nph-sfc_obs_nc_api';
const RADAR_COMPOSITE_URL =
  'https://apihub.kma.go.kr/api/typ01/cgi-bin/url/nph-rdr_cmp1_api';
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const FIVE_MINUTES_MS = 5 * 60 * 1000;

const RADAR_GRID = {
  nx: 2305,
  ny: 2881,
  referenceX: 1120,
  referenceY: 1680,
  gridMetres: 500,
  originLatitude: 38,
  originLongitude: 126,
  standardLatitude1: 30,
  standardLatitude2: 60,
} as const;

export interface RadarGridPoint {
  x: number;
  y: number;
}

export interface NationwidePrecipitationSnapshot {
  observedAt: string;
  analysis: ArrayBuffer;
  radar: ArrayBuffer;
}

interface KmaPrecipitationObservationProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  now?: () => Date;
  timeoutMs?: number;
  observationDelayMinutes?: number;
  attempts?: number;
}

export interface PrecipitationCollectionLocation {
  latitude: number;
  longitude: number;
  referenceRainDetected: boolean;
  referenceObservedAt: string;
}

type KmaPrecipitationFailureDetail =
  | 'ANALYSIS_NO_DATA_ROWS'
  | 'ANALYSIS_TIMESTAMP_MISSING'
  | 'ANALYSIS_TARGET_TIME_MISSING'
  | 'ANALYSIS_RAIN_FLAG_MISSING'
  | 'ANALYSIS_MISSING_VALUE'
  | 'ANALYSIS_NON_BINARY_VALUE'
  | 'ANALYSIS_TEXT_VALUE';

export class KmaPrecipitationObservationProviderError extends Error {
  readonly providerFailureDetail?: KmaPrecipitationFailureDetail;

  constructor(
    message: string,
    providerFailureDetail?: KmaPrecipitationFailureDetail,
  ) {
    super(message);
    this.name = 'KmaPrecipitationObservationProviderError';
    this.providerFailureDetail = providerFailureDetail;
  }
}

export class KmaPrecipitationObservationProvider {
  private readonly serviceKey: string;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;
  private readonly timeoutMs: number;
  private readonly observationDelayMinutes: number;
  private readonly attempts: number;

  constructor(options: KmaPrecipitationObservationProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher =
      options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.now = options.now ?? (() => new Date());
    this.timeoutMs = options.timeoutMs ?? 10_000;
    this.observationDelayMinutes = options.observationDelayMinutes ?? 10;
    this.attempts = options.attempts ?? 4;
  }

  async getNationwideSnapshot(target: Date): Promise<NationwidePrecipitationSnapshot> {
    if (!this.serviceKey) {
      throw new KmaPrecipitationObservationProviderError(
        'KMA APIHub service key is not configured',
      );
    }
    const query = new URLSearchParams({
      tm: compactKst(target),
      obs: 'rn_ox',
      disp: 'B',
      authKey: this.serviceKey,
    });
    const [analysisResponse, radar] = await Promise.all([
      this.fetcher(`${ANALYSIS_NATIONWIDE_URL}?${query}`, {
        headers: { Accept: 'application/octet-stream' },
        signal: AbortSignal.timeout(this.timeoutMs),
      }),
      this.fetchRadarComposite(target),
    ]);
    if (!analysisResponse.ok) {
      throw new KmaPrecipitationObservationProviderError(
        await providerHttpFailureMessage(analysisResponse, 'KMA nationwide analysis request'),
      );
    }
    const analysis = await analysisResponse.arrayBuffer();
    validateNationwideGrid(analysis, 2049, 2049, 4, 'analysis');
    validateNationwideGrid(radar, RADAR_GRID.nx, RADAR_GRID.ny, 2, 'radar');
    return {
      observedAt: compactKstToIso(compactKst(target)),
      analysis,
      radar,
    };
  }

  async getCurrentByLocation(
    latitude: number,
    longitude: number,
  ): Promise<CurrentPrecipitationObservation> {
    validateLocation(latitude, longitude);
    if (!this.serviceKey) {
      throw new KmaPrecipitationObservationProviderError(
        'KMA APIHub service key is not configured',
      );
    }

    const latest = floorToFiveMinutes(
      new Date(
        this.now().getTime() - this.observationDelayMinutes * 60 * 1000,
      ),
    );
    let lastError: unknown;

    for (let index = 0; index < this.attempts; index += 1) {
      const target = new Date(latest.getTime() - index * FIVE_MINUTES_MS);
      try {
        const [analysis, radar] = await Promise.all([
          this.fetchAnalysisRain(target, latitude, longitude),
          this.fetchRadarRain(target, latitude, longitude),
        ]);
        return {
          observedAt: analysis.observedAt,
          latitude,
          longitude,
          analysisRainDetected: analysis.rainDetected,
          radarRainDetected: radar.rainDetected,
          state: consensusState(
            analysis.rainDetected,
            radar.rainDetected,
          ),
          radarDbz: radar.dbz,
          provider: 'KMA_ANALYSIS_RADAR',
        };
      } catch (error) {
        lastError = error;
        if (
          error instanceof Error &&
          /\bstatus\s+4\d{2}\b/i.test(error.message)
        ) {
          throw error;
        }
      }
    }

    throw new KmaPrecipitationObservationProviderError(
      lastError instanceof Error
        ? lastError.message
        : 'KMA precipitation observation is not available',
      lastError instanceof KmaPrecipitationObservationProviderError
        ? lastError.providerFailureDetail
        : undefined,
    );
  }

  async getCurrentByLocations(
    locations: readonly PrecipitationCollectionLocation[],
    maxValidationRequests = 69,
  ): Promise<CurrentPrecipitationObservation[]> {
    for (const location of locations) {
      validateLocation(location.latitude, location.longitude);
    }
    if (locations.length === 0) return [];
    if (!this.serviceKey) {
      throw new KmaPrecipitationObservationProviderError(
        'KMA APIHub service key is not configured',
      );
    }

    const latest = floorToFiveMinutes(
      new Date(this.now().getTime() - this.observationDelayMinutes * 60 * 1000),
    );
    let target = latest;
    let payload: ArrayBuffer | undefined;
    let lastError: unknown;
    for (let index = 0; index < this.attempts; index += 1) {
      target = new Date(latest.getTime() - index * FIVE_MINUTES_MS);
      try {
        payload = await this.fetchRadarComposite(target);
        break;
      } catch (error) {
        lastError = error;
        if (error instanceof Error && /\bstatus\s+4\d{2}\b/i.test(error.message)) {
          throw error;
        }
      }
    }
    if (!payload) {
      throw new KmaPrecipitationObservationProviderError(
        lastError instanceof Error ? lastError.message : 'KMA radar is not available',
      );
    }

    const radar = locations.map((location) =>
      radarRainAtPoint(payload!, radarGridPoint(location.latitude, location.longitude)),
    );
    const mismatchIndexes = locations
      .map((location, index) => ({ location, index }))
      .filter(({ location, index }) =>
        location.referenceRainDetected !== radar[index].rainDetected,
      )
      .slice(0, Math.max(0, maxValidationRequests));
    const validations = await mapWithConcurrency(
      mismatchIndexes,
      2,
      async ({ location, index }) => {
        try {
          return {
            index,
            value: await this.fetchAnalysisRain(
              target,
              location.latitude,
              location.longitude,
            ),
          };
        } catch {
          return { index, value: undefined };
        }
      },
    );
    const validationByIndex = new Map(
      validations.map((validation) => [validation.index, validation.value]),
    );

    return locations.map((location, index) => {
      const validation = validationByIndex.get(index);
      const analysisRainDetected = validation?.rainDetected ??
        location.referenceRainDetected;
      return {
        observedAt: validation?.observedAt ?? location.referenceObservedAt,
        latitude: location.latitude,
        longitude: location.longitude,
        analysisRainDetected,
        radarRainDetected: radar[index].rainDetected,
        state: validation === undefined &&
            location.referenceRainDetected !== radar[index].rainDetected
          ? 'MISMATCH'
          : consensusState(analysisRainDetected, radar[index].rainDetected),
        radarDbz: radar[index].dbz,
        provider: 'KMA_ANALYSIS_RADAR',
      };
    });
  }

  private async fetchAnalysisRain(
    target: Date,
    latitude: number,
    longitude: number,
  ): Promise<{ observedAt: string; rainDetected: boolean }> {
    const targetKst = compactKst(target);
    const previousKst = compactKst(new Date(target.getTime() - FIVE_MINUTES_MS));
    const query = new URLSearchParams({
      obs: 'rn_ox',
      tm1: previousKst,
      tm2: targetKst,
      itv: '5',
      lon: String(longitude),
      lat: String(latitude),
      authKey: this.serviceKey,
    });
    const response = await this.fetcher(`${ANALYSIS_POINT_URL}?${query}`, {
      headers: { Accept: 'text/plain' },
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    if (!response.ok) {
      throw new KmaPrecipitationObservationProviderError(
        await providerHttpFailureMessage(response, 'KMA analysis request'),
      );
    }
    return parseAnalysisRain(await response.text(), targetKst);
  }

  private async fetchRadarRain(
    target: Date,
    latitude: number,
    longitude: number,
  ): Promise<{ rainDetected: boolean; dbz?: number }> {
    const point = radarGridPoint(latitude, longitude);
    return radarRainAtPoint(await this.fetchRadarComposite(target), point);
  }

  private async fetchRadarComposite(target: Date): Promise<ArrayBuffer> {
    const query = new URLSearchParams({
      tm: compactKst(target),
      cmp: 'HSR',
      qcd: 'MSK',
      obs: 'ECHO',
      map: 'HB',
      disp: 'B',
      authKey: this.serviceKey,
    });
    const response = await this.fetcher(`${RADAR_COMPOSITE_URL}?${query}`, {
      headers: { Accept: 'application/octet-stream' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 300 },
    });
    if (!response.ok) {
      throw new KmaPrecipitationObservationProviderError(
        await providerHttpFailureMessage(response, 'KMA radar request'),
      );
    }
    return response.arrayBuffer();
  }
}

export function parseAnalysisRain(
  payload: string,
  expectedTime?: string,
): { observedAt: string; rainDetected: boolean } {
  const apiHubStatus = kmaApiHubErrorStatus(payload);
  if (apiHubStatus !== undefined) {
    const reason = kmaApiHubErrorReason(payload);
    throw new KmaPrecipitationObservationProviderError(
      `KMA analysis response failed with status ${apiHubStatus}${
        reason ? `: ${reason}` : ''
      }`,
    );
  }
  const rows = payload
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && !line.startsWith('#'));

  if (rows.length === 0) {
    throw new KmaPrecipitationObservationProviderError(
      'KMA analysis response has no data rows',
      'ANALYSIS_NO_DATA_ROWS',
    );
  }

  const timestampedRows = rows.map((row) => {
    const tokens = row.split(/[\s,]+/).filter(Boolean);
    const timeIndex = tokens.findIndex((token) => /^\d{12}$/.test(token));
    return { tokens, timeIndex };
  });
  if (timestampedRows.every(({ timeIndex }) => timeIndex < 0)) {
    throw new KmaPrecipitationObservationProviderError(
      'KMA analysis response has no timestamp',
      'ANALYSIS_TIMESTAMP_MISSING',
    );
  }

  const targetRows = timestampedRows.filter(({ tokens, timeIndex }) =>
    timeIndex >= 0 && (!expectedTime || tokens[timeIndex] === expectedTime),
  );
  if (expectedTime && targetRows.length === 0) {
    throw new KmaPrecipitationObservationProviderError(
      'KMA analysis response does not contain the target time',
      'ANALYSIS_TARGET_TIME_MISSING',
    );
  }

  for (const { tokens, timeIndex } of targetRows.reverse()) {
    const observedTime = tokens[timeIndex];
    const value = tokens
      .slice(timeIndex + 1)
      .map(Number)
      .find((item) => item === 0 || item === 1);
    if (value === undefined) continue;
    return {
      observedAt: compactKstToIso(observedTime),
      rainDetected: value === 1,
    };
  }

  const lastToken = targetRows
    .at(-1)
    ?.tokens.filter((token) => token !== '=')
    .at(-1);
  const lastValue = lastToken === undefined ? Number.NaN : Number(lastToken);
  const detail: KmaPrecipitationFailureDetail =
    lastToken === undefined
      ? 'ANALYSIS_RAIN_FLAG_MISSING'
      : Number.isFinite(lastValue)
        ? lastValue < 0
          ? 'ANALYSIS_MISSING_VALUE'
          : 'ANALYSIS_NON_BINARY_VALUE'
        : 'ANALYSIS_TEXT_VALUE';
  throw new KmaPrecipitationObservationProviderError(
    'KMA analysis response has no valid rain observation',
    detail,
  );
}

export function radarGridPoint(
  latitude: number,
  longitude: number,
): RadarGridPoint {
  validateLocation(latitude, longitude);
  const radians = Math.PI / 180;
  const semiMajorAxis = 6_378_137;
  const flattening = 1 / 298.257223563;
  const eccentricity = Math.sqrt(2 * flattening - flattening ** 2);
  const standard1 = RADAR_GRID.standardLatitude1 * radians;
  const standard2 = RADAR_GRID.standardLatitude2 * radians;
  const originLatitude = RADAR_GRID.originLatitude * radians;
  const originLongitude = RADAR_GRID.originLongitude * radians;
  const m = (value: number) =>
    Math.cos(value) /
    Math.sqrt(1 - eccentricity ** 2 * Math.sin(value) ** 2);
  const t = (value: number) =>
    Math.tan(Math.PI / 4 - value / 2) /
    ((1 - eccentricity * Math.sin(value)) /
      (1 + eccentricity * Math.sin(value))) **
      (eccentricity / 2);
  const cone =
    (Math.log(m(standard1)) - Math.log(m(standard2))) /
    (Math.log(t(standard1)) - Math.log(t(standard2)));
  const factor = m(standard1) / (cone * t(standard1) ** cone);
  const radiusAtOrigin =
    (semiMajorAxis * factor * t(originLatitude) ** cone) /
    RADAR_GRID.gridMetres;
  const latitudeRadians = latitude * radians;
  const longitudeRadians = longitude * radians;
  const radius =
    (semiMajorAxis * factor * t(latitudeRadians) ** cone) /
    RADAR_GRID.gridMetres;
  const theta = cone * (longitudeRadians - originLongitude);
  const x = Math.round(
    RADAR_GRID.referenceX + radius * Math.sin(theta),
  );
  const y = Math.round(
    RADAR_GRID.referenceY + radiusAtOrigin - radius * Math.cos(theta),
  );

  if (x < 0 || x >= RADAR_GRID.nx || y < 0 || y >= RADAR_GRID.ny) {
    throw new KmaPrecipitationObservationProviderError(
      'Location is outside the KMA radar grid',
    );
  }
  return { x, y };
}

export function analysisGridPoint(
  latitude: number,
  longitude: number,
): RadarGridPoint {
  validateLocation(latitude, longitude);
  const radians = Math.PI / 180;
  const first = 30 * radians;
  const second = 60 * radians;
  const cone = Math.log(Math.cos(first) / Math.cos(second)) /
    Math.log(Math.tan(Math.PI / 4 + second / 2) /
      Math.tan(Math.PI / 4 + first / 2));
  const scale = Math.pow(Math.tan(Math.PI / 4 + first / 2), cone) *
    Math.cos(first) / cone;
  const scaledRadius = 6371.00877 / 0.5;
  const originRadius = scaledRadius * scale /
    Math.pow(Math.tan(Math.PI / 4 + 38 * radians / 2), cone);
  const radius = scaledRadius * scale /
    Math.pow(Math.tan(Math.PI / 4 + latitude * radians / 2), cone);
  const theta = cone * (longitude - 126) * radians;
  const x = Math.round(880 + radius * Math.sin(theta));
  const y = Math.round(1540 + originRadius - radius * Math.cos(theta));
  if (x < 0 || x >= 2049 || y < 0 || y >= 2049) {
    throw new KmaPrecipitationObservationProviderError(
      'Location is outside the KMA analysis grid',
    );
  }
  return { x, y };
}

export function nationwidePrecipitationAtPoint(
  snapshot: NationwidePrecipitationSnapshot,
  latitude: number,
  longitude: number,
): CurrentPrecipitationObservation {
  const point = analysisGridPoint(latitude, longitude);
  validateNationwideGrid(snapshot.analysis, 2049, 2049, 4, 'analysis');
  const analysisValue = new DataView(snapshot.analysis).getFloat32(
    4 + (point.y * 2049 + point.x) * 4,
    true,
  );
  if (analysisValue !== 0 && analysisValue !== 1) {
    throw new KmaPrecipitationObservationProviderError(
      'KMA analysis point has no valid rain observation',
      analysisValue < 0 ? 'ANALYSIS_MISSING_VALUE' : 'ANALYSIS_NON_BINARY_VALUE',
    );
  }
  const radar = radarRainAtPoint(snapshot.radar, radarGridPoint(latitude, longitude));
  const analysisRainDetected = analysisValue === 1;
  return {
    observedAt: snapshot.observedAt,
    latitude,
    longitude,
    analysisRainDetected,
    radarRainDetected: radar.rainDetected,
    state: consensusState(analysisRainDetected, radar.rainDetected),
    radarDbz: radar.dbz,
    provider: 'KMA_ANALYSIS_RADAR',
  };
}

function validateNationwideGrid(
  payload: ArrayBuffer,
  expectedNx: number,
  expectedNy: number,
  bytesPerCell: number,
  name: string,
): void {
  if (payload.byteLength < 4) {
    throw new KmaPrecipitationObservationProviderError(`KMA ${name} grid is too short`);
  }
  const view = new DataView(payload);
  if (view.getUint16(0, true) !== expectedNx ||
      view.getUint16(2, true) !== expectedNy ||
      payload.byteLength !== 4 + expectedNx * expectedNy * bytesPerCell) {
    throw new KmaPrecipitationObservationProviderError(`KMA ${name} grid is invalid`);
  }
}

export function radarRainAtPoint(
  payload: ArrayBuffer,
  point: RadarGridPoint,
): { rainDetected: boolean; dbz?: number } {
  if (payload.byteLength < 4) {
    throw new KmaPrecipitationObservationProviderError(
      'KMA radar response is too short',
    );
  }
  const view = new DataView(payload);
  const nx = view.getUint16(0, true);
  const ny = view.getUint16(2, true);
  const expectedLength = 4 + nx * ny * 2;
  if (
    nx !== RADAR_GRID.nx ||
    ny !== RADAR_GRID.ny ||
    payload.byteLength !== expectedLength ||
    point.x >= nx ||
    point.y >= ny
  ) {
    throw new KmaPrecipitationObservationProviderError(
      'KMA radar response grid is invalid',
    );
  }
  const offset = 4 + (point.y * nx + point.x) * 2;
  const rawValue = view.getInt16(offset, true);
  if (rawValue === -25_000) return { rainDetected: false };
  if (rawValue <= -30_000 || rawValue < -20_000) {
    throw new KmaPrecipitationObservationProviderError(
      'KMA radar point is outside the valid observation area',
    );
  }
  return { rainDetected: true, dbz: rawValue / 100 };
}

function consensusState(
  analysisRainDetected: boolean,
  radarRainDetected: boolean,
): PrecipitationConsensusState {
  if (analysisRainDetected && radarRainDetected) return 'RAIN';
  if (!analysisRainDetected && !radarRainDetected) return 'DRY';
  return 'MISMATCH';
}

function floorToFiveMinutes(value: Date): Date {
  return new Date(
    Math.floor(value.getTime() / FIVE_MINUTES_MS) * FIVE_MINUTES_MS,
  );
}

function compactKst(value: Date): string {
  const kst = new Date(value.getTime() + KST_OFFSET_MS);
  return `${kst.getUTCFullYear()}${String(kst.getUTCMonth() + 1).padStart(2, '0')}${String(kst.getUTCDate()).padStart(2, '0')}${String(kst.getUTCHours()).padStart(2, '0')}${String(kst.getUTCMinutes()).padStart(2, '0')}`;
}

function compactKstToIso(value: string): string {
  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}T${value.slice(8, 10)}:${value.slice(10, 12)}:00+09:00`;
}

function normalizeServiceKey(value: string): string {
  const trimmed = value.trim();
  try {
    return decodeURIComponent(trimmed);
  } catch {
    return trimmed;
  }
}

function validateLocation(latitude: number, longitude: number): void {
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < 30 ||
    latitude > 44 ||
    longitude < 120 ||
    longitude > 134
  ) {
    throw new KmaPrecipitationObservationProviderError(
      'Location is outside the supported Korean observation area',
    );
  }
}
