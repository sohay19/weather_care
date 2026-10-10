import { apiHubBudgetedFetch } from './apiHubFetch';
import { collectedCacheKey, getCollectedCache, saveCollectedCache } from '../database/collectedWeatherRepository';
import { getGridObservationSnapshot, saveGridObservationSnapshot } from '../database/gridObservationRepository';
import {
  auditGridObservationSnapshot, gridObservationKoreanIso, GRID_OBSERVATION_VARIABLES, KmaGridObservationProvider,
  REQUIRED_GRID_OBSERVATION_VARIABLES, type GridObservationSnapshot,
} from '../providers/weather/kmaGridObservationProvider';
import { providerErrorDiagnostic } from '../observability/providerErrorDiagnostics';

// T1H 30초 + 나머지 병렬 30초 + 저장 시간보다 길게 잡고, 중단된 작업은 2분 후 재시도한다.
const LEASE_MS = 2 * 60 * 1000;
interface ObservationRetry { observedAt: string; attempts: number; nextRetryAt: string }
const partialKey = (at: string) => `GRID_OBSERVATION_PARTIAL_${new Date(at).toISOString()}`;
const retryKey = (at: string) => `GRID_OBSERVATION_RETRY_${new Date(at).toISOString()}`;

export async function collectGridObservationSnapshot(input: {
  db: D1Database; serviceKey: string; clock: Date; now: Date;
  requiredOnly?: boolean; historical?: boolean; fastRetry?: boolean; backfill?: boolean;
}): Promise<GridObservationSnapshot | null> {
  const at = input.clock.getTime()-9*3_600_000;
  if (!Number.isFinite(at) || at < input.now.getTime()-72*3_600_000 || at > input.now.getTime()-10*60_000) {
    throw new RangeError('GRID_OBSERVATION_OUTSIDE_COLLECTION_WINDOW');
  }
  if (await getCollectedCache(input.db,'GRID_OBSERVATION_AUTHORIZATION_BLOCK')) return null;
  const observedAt = gridObservationKoreanIso(input.clock);
  let cached = await getGridObservationSnapshot(input.db, observedAt);
  const requiredOnly = input.requiredOnly && !(input.fastRetry && cached && !snapshotCoversRequest(cached.value, false));
  if (cached && snapshotCoversRequest(cached.value, requiredOnly)) {
    return cached.value;
  }
  const retry = await getCollectedCache<ObservationRetry>(input.db, retryKey(observedAt));
  if (retry && Date.parse(retry.value.nextRetryAt) > input.now.getTime()) return cached?.value ?? null;
  const key = collectedCacheKey.fetchLease(`GRID_OBSERVATION_${observedAt}`);
  const owner = crypto.randomUUID();
  const acquired = await input.db.prepare(`INSERT INTO weather_cache
    (cache_key, region_id, nx, ny, cache_type, payload, status, updated_at)
    VALUES (?, ?, 0, 0, 'GRID_OBSERVATION_FETCH_LEASE', ?, 'AVAILABLE', ?)
    ON CONFLICT(cache_key) DO UPDATE SET payload=excluded.payload, updated_at=excluded.updated_at
    WHERE weather_cache.cache_type='GRID_OBSERVATION_FETCH_LEASE' AND weather_cache.updated_at <= ?`)
    .bind(key, key, owner, input.now.toISOString(), new Date(input.now.getTime() - LEASE_MS).toISOString()).run();
  if (!acquired.meta.changes) return cached?.value ?? null;
  try {
    // 캐시 조회와 임대 획득 사이에 다른 프로세스가 게시했을 수 있다.
    cached = await getGridObservationSnapshot(input.db, observedAt);
    if (cached && snapshotCoversRequest(cached.value, requiredOnly)) {
      await input.db.prepare('DELETE FROM weather_cache WHERE cache_key = ? AND payload = ?').bind(key, owner).run();
      return cached.value;
    }
    const provider = input.historical ? 'GRID_OBSERVATION_HISTORY' : input.fastRetry
      ? 'GRID_OBSERVATION_FAST_RETRY' : 'GRID_OBSERVATION_10_MINUTES';
    const partial = await getCollectedCache<GridObservationSnapshot>(input.db, partialKey(observedAt));
    const seed: GridObservationSnapshot = { observedAt, fields: {
      ...(partial && validPartial(partial.value, observedAt) ? partial.value.fields : {}), ...cached?.value.fields,
    } };
    let writes = Promise.resolve();
    const snapshot = await new KmaGridObservationProvider({ serviceKey: input.serviceKey,
      fetcher: apiHubBudgetedFetch({ clock: () => new Date(), db: input.db, provider, now: input.now, maxBytes: 1_000_000,
        sourceVersion: observedAt, retry: input.backfill }) })
      .getSnapshot(input.clock, { requiredOnly, seed, onField: (variable, grid) => {
        // 같은 회차의 저장을 직렬화해 병렬 응답이 정상 항목을 덮어쓰지 않게 한다.
        writes = writes.then(async () => {
          seed.fields[variable] = grid;
          await saveCollectedCache(input.db, { key: partialKey(observedAt), type:'GRID_OBSERVATION_PARTIAL',
            value:seed, updatedAt:input.now });
          console.log(JSON.stringify({ event:'grid_observation_field_preserved', observedAt, variable,
            storedFields:Object.keys(seed.fields) }));
        });
        return writes;
      } });
    if (Date.parse(snapshot.observedAt) !== Date.parse(observedAt)) throw new Error('GRID_OBSERVATION_TIME_MISMATCH');
    // 빠른 핵심값 재시도로 같은 회차의 기존 선택 항목을 지우지 않는다.
    snapshot.fields = { ...seed.fields, ...snapshot.fields };
    const audit = auditGridObservationSnapshot(snapshot);
    if (audit.coreValidCells === 0) throw new Error('KMA grid observation has no usable same-grid core values');
    await saveGridObservationSnapshot(input.db, snapshot, input.now);
    if (snapshotCoversRequest(snapshot, requiredOnly)) {
      await input.db.batch([
        input.db.prepare('DELETE FROM weather_cache WHERE cache_key=?').bind(partialKey(observedAt)),
        input.db.prepare('DELETE FROM weather_cache WHERE cache_key=?').bind(retryKey(observedAt)),
      ]);
    } else await scheduleRetry(input.db, observedAt, input.now, retry?.value.attempts ?? 0);
    console.log(JSON.stringify({ event: 'grid_observation_snapshot_saved', observedAt,
      historical: !!input.historical, gridCount: 149 * 253,
      audit }));
    await input.db.prepare('DELETE FROM weather_cache WHERE cache_key = ? AND payload = ?').bind(key, owner).run();
    return snapshot;
  } catch (error) {
    // 실패 파일은 2/4/8분부터 최대 6시간 간격, 예산 차단은 한도 회복 시각까지 대기한다.
    console.error(JSON.stringify({ event: 'grid_observation_snapshot_failed', observedAt,
      historical: !!input.historical, ...providerErrorDiagnostic(error) }));
    const nextRetryAt = (error as {nextRetryAt?:number})?.nextRetryAt;
    if (['AUTHORIZATION_FAILED','NOT_CONFIGURED'].includes(providerErrorDiagnostic(error).failureReason)) {
      await saveCollectedCache(input.db,{key:'GRID_OBSERVATION_AUTHORIZATION_BLOCK',type:'PROVIDER_AUTHORIZATION_BLOCK',
        value:{blocked:true},updatedAt:input.now});
    }
    await scheduleRetry(input.db, observedAt, input.now, retry?.value.attempts ?? 0, nextRetryAt);
    return cached?.value ?? null;
  }
}

function validPartial(value: GridObservationSnapshot, observedAt: string): boolean {
  return value && Date.parse(value.observedAt) === Date.parse(observedAt) && value.fields &&
    Object.entries(value.fields).every(([field, grid]) => GRID_OBSERVATION_VARIABLES.includes(field as any) &&
      grid?.width === 149 && grid.height === 253 && Array.isArray(grid.values) &&
      grid.values.length === 149 * 253 && grid.values.every(Number.isFinite));
}

async function scheduleRetry(db: D1Database, observedAt: string, now: Date, previousAttempts: number, blockedUntil?: number) {
  const attempts = previousAttempts + 1;
  const delay = Math.min(6 * 3_600_000, 120_000 * 2 ** Math.min(attempts - 1, 8));
  const nextRetryAt = new Date(Math.max(now.getTime() + delay, blockedUntil ?? 0)).toISOString();
  await saveCollectedCache(db, { key:retryKey(observedAt), type:'GRID_OBSERVATION_RETRY', updatedAt:now,
    value:{observedAt:new Date(observedAt).toISOString(), attempts, nextRetryAt} satisfies ObservationRetry });
}

// 정규 최신 수집 뒤에 실행한다. 저장 시작 이후 72시간 이내의 누락을 2회차씩 보충한다.
export async function backfillGridObservationHistory(db: D1Database, serviceKey: string, now: Date): Promise<void> {
  if (!serviceKey?.trim()) return;
  const cutoff = new Date(now.getTime() - 72 * 3_600_000).toISOString();
  const rows = await db.prepare('SELECT observed_at FROM grid_observation_snapshots WHERE observed_at >= ? ORDER BY observed_at')
    .bind(cutoff).all<{observed_at:string}>();
  if (!rows.results.length) return;
  const present = new Set(rows.results.map(row => Date.parse(row.observed_at)));
  const end = Math.floor((now.getTime() - 20 * 60_000) / 600_000) * 600_000;
  for (let at = Date.parse(rows.results[0].observed_at); at <= end; at += 600_000) {
    if (present.has(at)) continue;
    const observedAt = new Date(at).toISOString();
    await db.prepare(`INSERT OR IGNORE INTO weather_cache(cache_key,region_id,nx,ny,cache_type,payload,status,updated_at)
      VALUES(?,?,0,0,'GRID_OBSERVATION_RETRY',?,'AVAILABLE',?)`)
      .bind(retryKey(observedAt), retryKey(observedAt), JSON.stringify({observedAt,attempts:0,nextRetryAt:now.toISOString()}), now.toISOString()).run();
  }
  const queued = await db.prepare(`SELECT payload FROM weather_cache WHERE cache_type='GRID_OBSERVATION_RETRY'
    AND json_extract(payload,'$.observedAt') >= ? AND json_extract(payload,'$.observedAt') <= ?
    AND json_extract(payload,'$.nextRetryAt') <= ?
    AND NOT EXISTS (SELECT 1 FROM grid_observation_snapshots WHERE observed_at=json_extract(weather_cache.payload,'$.observedAt'))
    ORDER BY ABS(julianday(json_extract(payload,'$.observedAt')) - julianday(?)), json_extract(payload,'$.observedAt') DESC LIMIT 2`)
    .bind(cutoff, new Date(end).toISOString(), now.toISOString(), new Date(now.getTime()-24*3_600_000).toISOString())
    .all<{payload:string}>();
  for (const row of queued.results) {
    const item = JSON.parse(row.payload) as ObservationRetry;
    const at = Date.parse(item.observedAt);
    if (!Number.isFinite(at) || at % 600_000 !== 0) continue;
    await collectGridObservationSnapshot({db,serviceKey,now,clock:new Date(at+9*3_600_000),requiredOnly:true,historical:true,backfill:true});
  }
  await db.batch(['GRID_OBSERVATION_PARTIAL','GRID_OBSERVATION_RETRY'].map(type =>
    db.prepare(`DELETE FROM weather_cache WHERE cache_type=? AND json_extract(payload,'$.observedAt') < ?`).bind(type,cutoff)));
}

function snapshotCoversRequest(snapshot: GridObservationSnapshot, requiredOnly?: boolean): boolean {
  return !!requiredOnly || GRID_OBSERVATION_VARIABLES.every((field) =>
    field in snapshot.fields);
}
