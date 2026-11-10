import { getCollectedCache, saveCollectedCache, type CollectedCacheRecord } from '../database/collectedWeatherRepository';
import { readCurrentGridObservation } from '../database/gridObservationRepository';
import { providerErrorDiagnostic } from '../observability/providerErrorDiagnostics';
import { providerHttpFailureMessage } from '../providers/providerHttpFailure';
import type { UltraShortObservation } from '../providers/weather/kmaUltraShortObservationProvider';
import { kmaGridCoordinates } from '../regions/kmaGridCoordinates';
import { apiHubBudgetedFetch } from './apiHubFetch';
import { DISTANT_OBSERVATION_KM, greatCircleDistanceKm } from './nearbyGridObservation';

const HOUR_MS = 3_600_000;
const DAY_MS = 24 * HOUR_MS;
const PUBLICATION_DELAY_MS = 5 * 60_000;
const MAX_AGE_MS = HOUR_MS + PUBLICATION_DELAY_MS;
const CACHE_TYPE = 'COLLECTED_AWS_HOURLY_FALLBACK';
const ROOT_URL = 'https://apihub.kma.go.kr/api/typ01';
const observationKey = (at: number) => `AWS_HOURLY_OBSERVATION_${koreanClock(at)}`;
const catalogKey = (at: number) => `AWS_HOURLY_STATIONS_${koreanClock(at).slice(0, 8)}`;

interface Coordinates { latitude: number; longitude: number }
interface Station extends Coordinates { id: string }
interface StationObservation { stationId: string; temperature: number; humidity: number; windSpeed: number }

export async function collectAwsHourlyFallback(db: D1Database, serviceKey: string, now: Date): Promise<void> {
  const at = Math.floor((now.getTime() - PUBLICATION_DELAY_MS) / HOUR_MS) * HOUR_MS;
  const catalog = await loadOrCollect<Station[]>(db, serviceKey, now, catalogKey(at),
    'AWS_FALLBACK_STATIONS', 'url/stn_inf.php', { inf: 'AWS', tm: koreanClock(at), help: '0' }, 512_000,
    parseStations);
  if (!catalog) return;
  const collectHour = (instant: number) => {
    const tm2 = koreanClock(instant);
    return loadOrCollect<StationObservation[]>(db, serviceKey, now, observationKey(instant),
      'AWS_FALLBACK_HOURLY', 'cgi-bin/url/nph-aws2_min', { tm2, stn: '0', disp: '1', help: '0' }, 256_000,
      (body) => parseObservations(body, tm2));
  };
  if (await collectHour(at)) await collectHour(at - DAY_MS);
}

export async function readCurrentWeatherObservation(
  db: D1Database, nx: number, ny: number, now: Date, gps?: Coordinates,
): Promise<CollectedCacheRecord<UltraShortObservation> | null> {
  const grid = await readCurrentGridObservation(db, nx, ny, now, gps);
  if (grid) return grid;
  const origin = gps ?? kmaGridCoordinates(nx, ny);
  if (!origin) return null;
  for (let at = Math.floor(now.getTime() / HOUR_MS) * HOUR_MS; isCurrentAwsHour(at, now); at -= HOUR_MS) {
    const record = await getCollectedCache<StationObservation[]>(db, observationKey(at));
    if (record?.status !== 'AVAILABLE' || !Array.isArray(record.value)) continue;
    const catalog = await getCollectedCache<Station[]>(db, catalogKey(at));
    if (catalog?.status !== 'AVAILABLE' || !Array.isArray(catalog.value)) continue;
    const observations = new Map(record.value.map((row) => [row.stationId, row]));
    let nearest: StationObservation | undefined;
    let distance = DISTANT_OBSERVATION_KM;
    for (const station of catalog.value) {
      const observation = observations.get(station.id);
      if (!observation) continue;
      const km = greatCircleDistanceKm(origin, station);
      if (km <= distance) {
        nearest = observation;
        distance = km;
      }
    }
    if (nearest) return {
      ...record,
      value: {
        ...toObservation(nearest, at),
        sourceLocation: {
          type: 'STATION', stationId: nearest.stationId, locationMatch: 'NEAREST_STATION',
          distanceKm: Math.round(distance * 10) / 10, distanceBasis: gps ? 'GPS' : 'GRID_CENTER',
        },
      },
    };
  }
  return null;
}

export async function readYesterdayAwsObservation(
  db: D1Database, current: UltraShortObservation,
): Promise<UltraShortObservation | undefined> {
  const at = Date.parse(current.observedAt) - DAY_MS;
  const stationId = current.sourceLocation?.stationId;
  if (!stationId || !Number.isFinite(at)) return undefined;
  const record = await getCollectedCache<StationObservation[]>(db, observationKey(at));
  if (record?.status !== 'AVAILABLE' || !Array.isArray(record.value)) return undefined;
  const row = record.value.find((item) => item.stationId === stationId);
  return row && toObservation(row, at);
}

export function isCurrentAwsHour(at: number, now: Date): boolean {
  const age = now.getTime() - at;
  return at % HOUR_MS === 0 && age >= 0 && age <= MAX_AGE_MS;
}

function toObservation(row: StationObservation, at: number): UltraShortObservation {
  return {
    observedAt: new Date(at).toISOString(),
    temperature: row.temperature, humidity: row.humidity, windSpeed: row.windSpeed,
    provider: 'KMA_AWS_OBSERVATION', rainDetected: false,
    qualityFlags: ['LOCATION_FALLBACK', 'PRECIPITATION_TYPE_UNAVAILABLE'],
  };
}

async function loadOrCollect<T extends unknown[]>(
  db: D1Database, serviceKey: string, now: Date, key: string, provider: string,
  path: string, query: Record<string, string>, maxBytes: number, parse: (body: string) => T,
): Promise<T | null> {
  const cached = await getCollectedCache<T>(db, key);
  if (cached?.status === 'AVAILABLE' && Array.isArray(cached.value) && cached.value.length) return cached.value;
  const attemptKey = `AWS_FALLBACK_ATTEMPT_${koreanClock(now.getTime()).slice(0, 8)}_${key}`;
  // 정규 수집과 빠른 재시도가 겹쳐도 회차별로 두 번까지만 요청한다.
  const attempt = await db.prepare(`INSERT INTO weather_cache
      (cache_key, region_id, nx, ny, cache_type, payload, status, updated_at)
      VALUES (?, ?, 0, 0, 'NATIONAL_SOURCE_LEASE', '1', 'AVAILABLE', ?)
      ON CONFLICT(cache_key) DO UPDATE SET payload = CAST(weather_cache.payload AS INTEGER) + 1,
        updated_at = excluded.updated_at
      WHERE CAST(weather_cache.payload AS INTEGER) < 2 AND weather_cache.updated_at <= ?`)
    .bind(attemptKey, attemptKey, now.toISOString(), new Date(now.getTime() - 15 * 60_000).toISOString()).run();
  if (!attempt.meta.changes) return null;
  try {
    const params = new URLSearchParams({ ...query, authKey: serviceKey.trim() });
    const fetcher = apiHubBudgetedFetch({ db, provider, now, maxBytes,
      sourceVersion: query.tm2 ?? query.tm, clock: () => new Date() });
    const response = await fetcher(`${ROOT_URL}/${path}?${params}`, { signal: AbortSignal.timeout(15_000) });
    if (!response.ok) throw new Error(await providerHttpFailureMessage(response, provider));
    const value = parse(await response.text());
    if (!value.length) throw new Error('KMA AWS has no usable data');
    await saveCollectedCache(db, { key, type: CACHE_TYPE, value, updatedAt: now });
    console.log(JSON.stringify({ event: 'aws_hourly_fallback_cached', key, rows: value.length }));
    return value;
  } catch (error) {
    console.warn(JSON.stringify({ event: 'aws_hourly_fallback_failed', key, ...providerErrorDiagnostic(error) }));
    return null;
  }
}

function koreanClock(at: number): string {
  return new Date(at + 9 * HOUR_MS).toISOString().slice(0, 16).replace(/\D/g, '');
}

function parseStations(body: string): Station[] {
  return body.split(/\r?\n/).flatMap((line) => {
    const [id, lon, lat] = line.trim().split(/\s+/, 3);
    const latitude = Number(lat);
    const longitude = Number(lon);
    return /^\d{1,4}$/.test(id) && latitude >= 30 && latitude <= 45 && longitude >= 120 && longitude <= 135
      ? [{ id, latitude, longitude }] : [];
  });
}

function parseObservations(body: string, expectedTime: string): StationObservation[] {
  const lines = body.split(/\r?\n/);
  const columns = lines.find((line) => /^#\s*YYMMDDHHMI\s+STN\s/.test(line))?.slice(1).trim().split(/\s+/);
  if (!columns) return [];
  const [temperatureIndex, humidityIndex, windIndex] = ['TA', 'HM', 'WS10'].map((name) => columns.indexOf(name));
  if (Math.min(temperatureIndex, humidityIndex, windIndex) < 0) return [];
  return lines.flatMap((line) => {
    const values = line.split(',').map((value) => value.trim());
    if (values[0] !== expectedTime || !/^\d{1,4}$/.test(values[1] ?? '')) return [];
    const temperature = Number(values[temperatureIndex] || Number.NaN);
    const humidity = Number(values[humidityIndex] || Number.NaN);
    const windSpeed = Number(values[windIndex] || Number.NaN);
    return temperature >= -80 && temperature <= 60 && humidity >= 0 && humidity <= 100 && windSpeed >= 0 && windSpeed <= 100
      ? [{ stationId: values[1], temperature, humidity, windSpeed }] : [];
  });
}
