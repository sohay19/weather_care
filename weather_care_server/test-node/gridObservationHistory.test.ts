import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { asD1Database, runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { getGridObservationSnapshot, readCurrentGridObservation, saveGridObservationSnapshot } from '../src/database/gridObservationRepository';
import { auditGridObservationSnapshot, gridObservationKoreanIso, KmaGridObservationProvider, latestGridObservationTime, observationsFromGridSnapshot } from '../src/providers/weather/kmaGridObservationProvider';
import { collectGridObservationSnapshot } from '../src/services/gridObservationCache';
import { getApiHubUsage, reserveApiHubBudget } from '../src/database/apiUsageRepository';
import { saveCollectedCache, collectedCacheKey } from '../src/database/collectedWeatherRepository';
import { currentFromUltraShortObservation } from '../src/api/weather';
import { inspectOperationalPrewarm } from '../src/node/prewarmNationwide';
import { nodeServerEnv } from '../src/node/runtime';
import { observationSnapshot } from './gridObservationFixture';

let database: SqliteD1Database;
const now = new Date('2026-10-04T11:54:00+09:00');
const at = '2026-10-04T11:40:00+09:00';
beforeEach(() => { database = new SqliteD1Database(':memory:'); runSqliteMigrations(database); });
afterEach(() => { vi.useRealTimers(); vi.restoreAllMocks(); database.close(); });

describe('전국 실황 원본·이력', () => {
  it('37,697개 셀을 모두 저장하고 대표 목록 밖·끝 셀도 같은 값으로 읽는다', async () => {
    const db = asD1Database(database);
    const snapshot = observationSnapshot(at);
    snapshot.fields.T1H!.values[0] = -99;
    snapshot.fields.REH!.values[148] = -99;
    snapshot.fields.T1H!.values[149 * 253 - 1] = 23.8;
    await saveGridObservationSnapshot(db, snapshot, now);
    const stored = (await getGridObservationSnapshot(db, at))!.value;
    expect(stored).toEqual(snapshot);
    const audit = auditGridObservationSnapshot(stored);
    expect(audit.coreValidCells).toBe(37695);
    expect(audit.fields.T1H).toMatchObject({ storedCells: 37697, validCells: 37696, sourceMissingCells: 1 });
    expect(observationsFromGridSnapshot(stored, [{ nx: 1, ny: 1 }, { nx: 149, ny: 253 }]).has('1:1')).toBe(false);
    const current = await readCurrentGridObservation(db, 149, 253, now);
    expect(current?.value.temperature).toBe(23.8);
    expect(currentFromUltraShortObservation({ observedAt: at }, current, now).temperature).toBe(23.8);
  });

  it('11:51에 이미 저장된 11:50이나 AWS가 있어도 11:40 격자만 채택한다', async () => {
    const db = asD1Database(database);
    await saveGridObservationSnapshot(db, observationSnapshot(at, 20), now);
    await saveGridObservationSnapshot(db, observationSnapshot('2026-10-04T11:50:00+09:00', 30), now);
    await saveCollectedCache(db, { key: collectedCacheKey.ultraShortObservation(60, 121), type: 'COLLECTED_ULTRA_SHORT',
      value: { observedAt: '2026-10-04T11:49:00+09:00', provider: 'KMA_AWS_OBSERVATION', temperature: 40, rainDetected: false }, updatedAt: now });
    expect((await readCurrentGridObservation(db, 60, 121, now))?.value).toMatchObject({ temperature: 20, observedAt: at });
    expect(gridObservationKoreanIso(latestGridObservationTime(new Date('2026-10-04T12:04:00+09:00')))).toBe('2026-10-04T11:50:00+09:00');
  });

  it('72시간 보존 경계를 지키고 다음 정상 저장에서 만료 원본을 정리한다', async () => {
    const db = asD1Database(database);
    const clock = new Date('2026-10-04T11:40:00+09:00');
    await saveGridObservationSnapshot(db, observationSnapshot('2026-10-01T11:40:00+09:00'), clock);
    await expect(saveGridObservationSnapshot(db, observationSnapshot('2026-10-01T11:30:00+09:00'), clock)).rejects.toThrow('OUTSIDE_RETENTION');
    await saveGridObservationSnapshot(db, observationSnapshot(at), new Date(clock.getTime() + 1));
    expect(await getGridObservationSnapshot(db, '2026-10-01T11:40:00+09:00')).toBeNull();
  });

  it('원본 셀이 잘린 스냅샷을 저장하지 않는다', async () => {
    const snapshot = observationSnapshot(at);
    snapshot.fields.REH!.values.pop();
    await expect(saveGridObservationSnapshot(asD1Database(database), snapshot, now)).rejects.toThrow('INVALID_GRID');
  });

  it('어제 원본 동시 보충은 한 번만 호출하고 캐시 조회는 예산을 추가 소비하지 않는다', async () => {
    const db = asD1Database(database);
    const clock = new Date('2026-10-03T11:40:00Z');
    const provider = vi.spyOn(KmaGridObservationProvider.prototype, 'getSnapshot').mockResolvedValue(observationSnapshot('2026-10-03T11:40:00+09:00'));
    const input = { db, serviceKey: 'synthetic', clock, now, requiredOnly: true, historical: true };
    await Promise.all([collectGridObservationSnapshot(input), collectGridObservationSnapshot(input)]);
    expect(provider).toHaveBeenCalledTimes(1);
    expect(await collectGridObservationSnapshot(input)).not.toBeNull();
    expect(provider).toHaveBeenCalledTimes(1);
    expect(await getApiHubUsage(db, now)).toEqual({ requestCount: 0, responseBytes: 0 });
  });

  it('예산 소진은 공급자 호출 없이 진단하고 504는 자료 없음으로 바꾸지 않는다', async () => {
    // 실제 호출 시각과 예약 시각을 같은 날짜에 고정한다.
    vi.useFakeTimers({ toFake: ['Date'] }); vi.setSystemTime(now);
    const db = asD1Database(database);
    const fetcher = vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('Gateway timeout', { status: 504 }));
    const log = vi.spyOn(console, 'error').mockImplementation(() => {});
    const input = { db, serviceKey: 'synthetic', clock: new Date('2026-10-03T11:40:00Z'), now, requiredOnly: true, historical: true };
    expect(await collectGridObservationSnapshot(input)).toBeNull();
    expect(log.mock.calls.join('')).toContain('UPSTREAM_SERVER_ERROR');
    expect(log.mock.calls.join('')).toContain('"httpStatus":504');
    await reserveApiHubBudget(db, 'OTHER', 1, 4499999985, now);
    expect(await collectGridObservationSnapshot({ ...input, clock: new Date('2026-10-03T11:30:00Z') })).toBeNull();
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('전국 핵심 입력이 완전히 비어 있으면 성공 캐시로 고정하지 않는다', async () => {
    const db = asD1Database(database);
    const snapshot = observationSnapshot(at);
    snapshot.fields.REH!.values.fill(-99);
    vi.spyOn(KmaGridObservationProvider.prototype, 'getSnapshot').mockResolvedValue(snapshot);
    expect(await collectGridObservationSnapshot({ db, serviceKey: 'test', now,
      clock: new Date('2026-10-04T11:40:00Z'), requiredOnly: true })).toBeNull();
    expect(await getGridObservationSnapshot(db, at)).toBeNull();
  });

  it('공식 결측 셀은 원본 준비 상태와 구분해 프리워밍을 막지 않고 보고한다', async () => {
    const db = asD1Database(database);
    const runtime = { database, env: nodeServerEnv(database, {}), close: () => database.close() };
    const grids = [{ nx: 1, ny: 1 }, { nx: 149, ny: 253 }];
    const before = inspectOperationalPrewarm(runtime, now, grids);
    const snapshot = observationSnapshot(at);
    snapshot.fields.T1H!.values[0] = -99;
    await saveGridObservationSnapshot(db, snapshot, now);
    const after = inspectOperationalPrewarm(runtime, now, grids);
    expect(after.observationSourceMissingGrids).toBe(1);
    expect(after.requiredCaches).toBe(before.requiredCaches);
    expect(after.collectedCaches).toBe(before.collectedCaches + 1);
  });

  it('별도 수집 프로세스의 동시 예약도 일 용량을 넘지 않는다', async () => {
    const db = asD1Database(database);
    await reserveApiHubBudget(db, 'BASE', 1, 4498000000, now);
    const results = await Promise.all([reserveApiHubBudget(db, 'A', 1, 2000000, now), reserveApiHubBudget(db, 'B', 1, 2000000, now)]);
    expect(results.filter(Boolean)).toHaveLength(1);
    expect((await getApiHubUsage(db, now)).responseBytes).toBe(4500000000);
  });
});
