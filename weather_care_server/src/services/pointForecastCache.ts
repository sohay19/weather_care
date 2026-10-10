import { KmaWeatherProvider, latestBaseDateTimes } from '../providers/weather/kmaWeatherProvider';
import type { WeatherForecast } from '../providers/weather/weatherProvider';
import { getCollectedCache, saveCollectedCache, cacheRecordIsFresh } from '../database/collectedWeatherRepository';
import { missingLandForecastGrids } from '../database/nationwideForecastRepository';
import { getGridObservationSnapshot } from '../database/gridObservationRepository';
import { gridObservationKoreanIso, latestGridObservationTime, observationsFromGridSnapshot } from '../providers/weather/kmaGridObservationProvider';
import { reservePointForecastRequest } from '../database/apiUsageRepository';
import { providerErrorDiagnostic } from '../observability/providerErrorDiagnostics';
import { mapWithConcurrency } from '../utils/concurrencyLimiter';

interface Grid { nx: number; ny: number }
interface PointForecast { nx: number; ny: number; forecast: WeatherForecast }
export const POINT_FORECAST_DAILY_CALL_LIMIT = 9000;
const cacheKey = (nx: number, ny: number) => `COLLECTED_POINT_FORECAST_${nx}_${ny}`;

export async function readPointForecast(db: D1Database | undefined, nx: number, ny: number, now: Date): Promise<WeatherForecast | undefined> {
  const record = await getCollectedCache<PointForecast>(db, cacheKey(nx, ny));
  if (record?.status !== 'AVAILABLE' || !cacheRecordIsFresh(record, 6 * 3_600_000, now) ||
      record.value.nx !== nx || record.value.ny !== ny) return undefined;
  const forecast = record.value.forecast;
  const latest = latestBaseDateTimes(now, 1)[0];
  const issue = `${forecast?.baseDate}${forecast?.baseTime}`;
  if (!/^\d{12}$/.test(issue) || issue > latest.baseDate + latest.baseTime ||
      !Array.isArray(forecast.hourly) || !forecast.hourly.some((slot) => usableCore(slot) && Date.parse(slot.observedAt) >= now.getTime() - 30 * 60_000)) return undefined;
  return forecast;
}

export async function collectPointForecasts(db: D1Database, serviceKey: string, now: Date): Promise<void> {
  if (!serviceKey.trim()) throw new Error('KMA service key is not configured');
  const base = latestBaseDateTimes(now, 1)[0];
  const issue = base.baseDate + base.baseTime;
  const version = await db.prepare('SELECT version FROM administrative_boundary_dataset WHERE singleton=1').first<{ version: string }>();
  const targetKey = `POINT_FORECAST_TARGETS_${issue}`;
  const cachedTargets = await getCollectedCache<{ grids: Grid[]; boundaryVersion?: string; forecastChecked?: boolean }>(db, targetKey);
  let grids = cachedTargets?.value.boundaryVersion === version?.version ? cachedTargets?.value.grids : undefined;
  if (!grids || !cachedTargets?.value.forecastChecked) {
    const land = await getCollectedCache<{ boundaryVersion: string; grids: Grid[] }>(db, 'COLLECTED_NATIONWIDE_LAND_GRIDS');
    if (version && (land?.status !== 'AVAILABLE' || land.value.boundaryVersion !== version.version)) throw new Error('NATIONWIDE_LAND_GRIDS_NOT_READY');
    const active = await db.prepare('SELECT DISTINCT nx,ny FROM installations').all<Grid>();
    const targets = [...new Map([...(land?.value.grids ?? []), ...active.results].map((grid) => [`${grid.nx}:${grid.ny}`,grid])).values()];
    const missing = await missingLandForecastGrids(db, targets, now);
    // 지속적인 실황 공간 결측 격자도 정확한 지점 예보를 미리 확보한다.
    let snapshot: Awaited<ReturnType<typeof getGridObservationSnapshot>> = null;
    const targetAt = Date.parse(gridObservationKoreanIso(latestGridObservationTime(now)));
    for (let at = targetAt; !snapshot && at >= now.getTime()-30*60_000; at -= 10*60_000) {
      snapshot = await getGridObservationSnapshot(db, new Date(at).toISOString());
    }
    const observations = snapshot && observationsFromGridSnapshot(snapshot.value, targets);
    grids = [...new Map([...(grids ?? []), ...targets.filter((grid) => missing.has(`${grid.nx}:${grid.ny}`) || observations && !observations.has(`${grid.nx}:${grid.ny}`))]
      .map((grid) => [`${grid.nx}:${grid.ny}`,grid])).values()];
    // 원본 파일이 아직 없으면 대상 목록을 고정하지 않고 다음 수집에서 재판정한다.
    if (snapshot || missing.sourceAvailable) await saveCollectedCache(db, { key: targetKey, type: 'POINT_FORECAST_TARGETS',
      value: { grids, boundaryVersion: version?.version, forecastChecked: missing.sourceAvailable }, updatedAt: now });
  }
  let stopped = false;
  let collected = 0;
  await mapWithConcurrency(grids, 4, async ({ nx, ny }) => {
    if (stopped) return;
    const cached = await readPointForecast(db, nx, ny, now);
    if (cached?.baseDate + cached?.baseTime === issue) return;
    const lease = `POINT_FORECAST_ATTEMPT_${issue}_${nx}_${ny}`;
    const owner = crypto.randomUUID();
    const acquired = await db.prepare(`INSERT INTO weather_cache(cache_key,region_id,nx,ny,cache_type,payload,status,updated_at)
      VALUES(?,?,?,?, 'POINT_FORECAST_ATTEMPT',?,'AVAILABLE',?) ON CONFLICT(cache_key) DO UPDATE SET
      payload=json_object('owner',?,'attempts',json_extract(weather_cache.payload,'$.attempts')+1),updated_at=excluded.updated_at
      WHERE weather_cache.updated_at <= ? AND json_extract(weather_cache.payload,'$.attempts') < 3`)
      .bind(lease, lease, nx, ny, JSON.stringify({ owner, attempts: 1 }), now.toISOString(), owner,
        new Date(now.getTime() - 10 * 60_000).toISOString()).run();
    if (!acquired.meta.changes) return;
    const started = performance.now();
    try {
      const forecast = await new KmaWeatherProvider({ serviceKey, now: () => now, timeoutMs: 30_000,
        fetcher: pointForecastFetch(db),
      }).getForecastByRegion(nx, ny);
      if (forecast.baseDate + forecast.baseTime !== issue || !forecast.hourly.some(usableCore)) throw new Error('Point forecast has no usable current issue');
      for (const slot of [forecast.current, ...forecast.hourly, ...forecast.timelineHourly ?? []]) {
        slot.provider = 'KMA_DATA_GO_KR';
        slot.sourceLocation = { type: 'GRID', nx, ny, locationMatch: 'EXACT_GRID' };
        slot.qualityFlags = [...(slot.qualityFlags ?? []), 'POINT_FORECAST_SUPPLEMENT'];
      }
      forecast.dataSource = '기상청 공공데이터포털 단기예보';
      await saveCollectedCache(db, { key: cacheKey(nx, ny), type: 'COLLECTED_POINT_FORECAST', value: { nx, ny, forecast }, nx, ny, updatedAt: now });
      collected++;
    } catch (error) {
      const diagnostic = providerErrorDiagnostic(error);
      if (['AUTHORIZATION_FAILED', 'QUOTA_EXCEEDED', 'RATE_LIMITED'].includes(diagnostic.failureReason) ||
          error instanceof Error && error.message === 'POINT_FORECAST_BUDGET_EXHAUSTED') stopped = true;
      console.error(JSON.stringify({ event: 'point_forecast_collection_failed', nx, ny, issue,
        elapsedMs: Math.round(performance.now() - started), timeoutMs: 30_000, ...diagnostic }));
    }
  });
  console.log(JSON.stringify({ event: 'point_forecast_collection_completed', issue, targets: grids.length, collected, stopped }));
}

export function pointForecastFetch(db: D1Database): typeof fetch {
  return async (input, init) => {
    const accountedAt = new Date();
    if (!await reservePointForecastRequest(db, POINT_FORECAST_DAILY_CALL_LIMIT, accountedAt)) throw new Error('POINT_FORECAST_BUDGET_EXHAUSTED');
    const started = performance.now();
    let phase = 'RESPONSE_HEADERS', bytes = 0, status: number | undefined;
    try {
      const response = await globalThis.fetch(input, init);
      status = response.status; phase = 'RESPONSE_BODY';
      const chunks: Uint8Array[] = [];
      const reader = response.body?.getReader();
      if (reader) {
        try {
          while (true) {
            const part = await reader.read();
            if (part.done) break;
            bytes += part.value.byteLength;
            if (bytes > 2_000_000) { await reader.cancel(); throw new Error('Point forecast response size is invalid'); }
            chunks.push(part.value);
          }
        } finally { reader.releaseLock(); }
      }
      const body = new Uint8Array(bytes);
      let offset = 0;
      for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.byteLength; }
      console.log(JSON.stringify({ event: 'point_forecast_response_accounted', httpStatus: status,
        responseBytes: bytes, elapsedMs: Math.round(performance.now()-started) }));
      return new Response(status === 204 || status === 304 ? null : body,
        { status, statusText: response.statusText, headers: response.headers });
    } catch (error) {
      console.error(JSON.stringify({ event: 'point_forecast_request_failed', phase, httpStatus: status,
        receivedBytes: bytes, elapsedMs: Math.round(performance.now()-started),
        signalAborted: init?.signal?.aborted ?? false, ...providerErrorDiagnostic(error) }));
      throw error;
    } finally {
      await db.prepare(`UPDATE api_usage_daily SET response_bytes=response_bytes+?
        WHERE usage_date=? AND provider='DATA_GO_POINT_FORECAST'`)
        .bind(bytes, new Date(accountedAt.getTime()+9*3_600_000).toISOString().slice(0,10)).run();
    }
  };
}

function usableCore(slot: WeatherForecast['current']): boolean {
  return !!slot && Number.isFinite(slot.temperature) && slot.temperature! >= -80 && slot.temperature! <= 60 &&
    Number.isFinite(slot.humidity) && slot.humidity! >= 0 && slot.humidity! <= 100 &&
    Number.isFinite(slot.windSpeed) && slot.windSpeed! >= 0 && slot.windSpeed! <= 100;
}
