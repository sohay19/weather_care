import { kmaGridFromCoordinates } from '../regions/kmaGridFromCoordinates';
import { kmaGridCoordinates } from '../regions/kmaGridCoordinates';

// 기상청의 마지막 번개·천둥 후 30분 대피 지침을 참고한 표시 기준.
// 관측 만료는 안전 판정이 아니다. 수집 시각으로 발생 시각을 연장하지 않는다.
export const LIGHTNING_MAX_AGE_MS = 30 * 60_000;
export const LIGHTNING_FEED_MAX_LAG_MS = 20 * 60_000;
// NWS의 뇌우 주변 6~10 mile 위험 안내를 참고해 여유를 둔 앱 감지 범위.
// https://www.weather.gov/safety/lightning-sports — 범위 밖의 안전을 보장하지 않는다.
export const LIGHTNING_RADIUS_KM = 20;
export interface LightningPosition { latitude: number; longitude: number }

export interface LightningEvent {
  observedAt: string;
  latitude: number;
  longitude: number;
  testSample?: boolean;
}

export interface LightningFeed {
  status: 'AVAILABLE' | 'FAILED' | 'STALE' | 'UNAVAILABLE';
  checkedAt?: string;
  windowEnd?: string;
  events: LightningEvent[];
}

export interface LightningSummary {
  status: LightningFeed['status'];
  checkedAt?: string;
  windowEnd?: string;
  feedExpiresAt?: string;
  count: number;
  observations: string[];
  latestObservedAt?: string;
  expiresAt?: string;
  nx: number;
  ny: number;
  testSample?: boolean;
  radiusKm: number;
  distanceBasis: 'COORDINATES' | 'GRID_CENTER';
  latestDistanceKm?: number;
}

export function lightningDistanceKm(a: LightningPosition, b: LightningPosition): number {
  const r = Math.PI / 180;
  const h = Math.sin((a.latitude - b.latitude) * r / 2) ** 2 +
    Math.cos(a.latitude * r) * Math.cos(b.latitude * r) *
    Math.sin((a.longitude - b.longitude) * r / 2) ** 2;
  return 6371.00877 * 2 * Math.asin(Math.sqrt(Math.min(1, Math.max(0, h))));
}

export function lightningPositionMatchesGrid(point: LightningPosition, nx: number, ny: number): boolean {
  if (!Number.isFinite(point.latitude) || !Number.isFinite(point.longitude) ||
      point.latitude < 30 || point.latitude > 44 || point.longitude < 120 || point.longitude > 134) return false;
  const grid = kmaGridFromCoordinates(point.latitude, point.longitude);
  return grid.nx === nx && grid.ny === ny;
}

export function lightningTime(raw: unknown): string | undefined {
  if (typeof raw !== 'string') return;
  const text = /^\d{12}(\d{2})?$/.test(raw)
    ? `${raw.slice(0, 4)}-${raw.slice(4, 6)}-${raw.slice(6, 8)}T${raw.slice(8, 10)}:${raw.slice(10, 12)}:${raw.slice(12, 14) || '00'}+09:00`
    : raw;
  if (!/(Z|[+-]\d{2}:\d{2})$/.test(text)) return;
  const time = Date.parse(text);
  if (Number.isFinite(time) && /^\d{12}(\d{2})?$/.test(raw)) {
    const normalized = new Date(time + 9 * 3_600_000).toISOString().slice(0, 19).replace(/\D/g, '');
    if (normalized !== raw.padEnd(14, '0')) return;
  }
  return Number.isFinite(time) ? new Date(time).toISOString() : undefined;
}

export async function readLightningFeed(db: D1Database, now = new Date(),
  options: { includeTestSamples?: boolean } = {}): Promise<LightningFeed> {
  const state = await db.prepare('SELECT attempted_at,window_end,status FROM lightning_collection_state WHERE id=1')
    .first<{ attempted_at: string; window_end: string; status: string }>();
  if (!state) return { status: 'UNAVAILABLE', events: [] };
  const base = { checkedAt: state.attempted_at, windowEnd: state.window_end };
  if (state.status !== 'AVAILABLE') return { ...base, status: 'FAILED', events: [] };
  const lag = now.getTime() - Date.parse(state.window_end);
  const checkedAge = now.getTime() - Date.parse(state.attempted_at);
  if (!Number.isFinite(lag) || lag < 0 || lag >= LIGHTNING_FEED_MAX_LAG_MS ||
      !Number.isFinite(checkedAge) || checkedAge < 0 || checkedAge >= LIGHTNING_FEED_MAX_LAG_MS)
    return { ...base, status: 'STALE', events: [] };
  const snapshots = await db.prepare(`SELECT source,payload FROM grid_extra_snapshots
    WHERE source IN ('KMA_LIGHTNING',?) AND target_id='ALL' AND slot>=? AND slot<=? ORDER BY slot`)
    .bind(options.includeTestSamples ? 'KMA_LIGHTNING_TEST' : 'KMA_LIGHTNING',
      new Date(now.getTime() - LIGHTNING_MAX_AGE_MS - 600_000).toISOString(), now.toISOString())
    .all<{ source: string; payload: string }>();
  const events: LightningEvent[] = [];
  const seen = new Set<string>();
  for (const snapshot of snapshots.results) {
    const payload = JSON.parse(snapshot.payload) as { events?: unknown };
    if (!Array.isArray(payload.events)) throw new Error('INVALID_LIGHTNING_SNAPSHOT');
    for (const raw of payload.events) {
      if (!raw || typeof raw !== 'object') continue;
      const event = raw as Record<string, unknown>;
      const observedAt = lightningTime(event.observedAt);
      const latitude = event.latitude;
      const longitude = event.longitude;
      if (!observedAt || typeof latitude !== 'number' || typeof longitude !== 'number' ||
          !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
          latitude < 20 || latitude > 50 || longitude < 100 || longitude > 150) continue;
      const age = now.getTime() - Date.parse(observedAt);
      if (age < 0 || age >= LIGHTNING_MAX_AGE_MS) continue;
      const key = `${observedAt}:${latitude}:${longitude}`;
      if (seen.has(key)) continue;
      seen.add(key);
      events.push({ observedAt, latitude, longitude,
        ...(snapshot.source === 'KMA_LIGHTNING_TEST' ? { testSample: true } : {}) });
    }
  }
  return { ...base, status: 'AVAILABLE', events };
}

export function lightningForGrid(feed: LightningFeed, nx: number, ny: number,
  now = new Date(), position?: LightningPosition): LightningSummary {
  const precise = position && lightningPositionMatchesGrid(position, nx, ny);
  const center = precise ? position : kmaGridCoordinates(nx, ny);
  const events = feed.status === 'AVAILABLE' && center ? feed.events.filter((event) => {
    const age = now.getTime() - Date.parse(event.observedAt);
    const distance = lightningDistanceKm(center, event);
    return age >= 0 && age < LIGHTNING_MAX_AGE_MS && distance <= LIGHTNING_RADIUS_KM;
  }).sort((a, b) => b.observedAt.localeCompare(a.observedAt)) : [];
  const latestObservedAt = events[0]?.observedAt;
  return {
    status: feed.status, checkedAt: feed.checkedAt, windowEnd: feed.windowEnd,
    feedExpiresAt: feed.windowEnd && feed.checkedAt
      ? new Date(Math.min(Date.parse(feed.windowEnd), Date.parse(feed.checkedAt)) + LIGHTNING_FEED_MAX_LAG_MS).toISOString()
      : undefined,
    nx, ny, radiusKm: LIGHTNING_RADIUS_KM, distanceBasis: precise ? 'COORDINATES' : 'GRID_CENTER',
    count: events.length, observations: events.map((event) => event.observedAt), latestObservedAt,
    latestDistanceKm: events[0] && center ? lightningDistanceKm(center, events[0]) : undefined,
    ...(events.some((event) => event.testSample) ? { testSample: true } : {}),
    expiresAt: latestObservedAt
      ? new Date(Date.parse(latestObservedAt) + LIGHTNING_MAX_AGE_MS).toISOString() : undefined,
  };
}
