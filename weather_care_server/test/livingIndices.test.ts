import { describe, expect, it, vi } from 'vitest';
import { collectNationwideLivingIndices, readTodayLivingIndices } from '../src/services/livingIndices';

function cacheDb(): D1Database {
  const rows = new Map<string, { payload: string; status: 'AVAILABLE'; updatedAt: string }>();
  return {
    prepare(sql: string) {
      return {
        bind(...args: unknown[]) {
          return {
            async first() { return rows.get(String(args[0])) ?? null; },
            async run() {
              if (sql.startsWith('INSERT')) rows.set(String(args[0]), {
                payload: String(args[5]), status: 'AVAILABLE', updatedAt: String(args[6]),
              });
              return { success: true };
            },
          };
        },
      };
    },
  } as unknown as D1Database;
}

describe('Today 꽃가루·대기정체 공식 지수', () => {
  it('가을 잡초류와 대기정체 단계를 수집해 행정구역별로 읽는다', async () => {
    const db = cacheDb();
    const now = new Date('2026-10-13T03:10:00Z');
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = new URL(String(input));
      expect(url.searchParams.get('areaNo')).toBe('');
      expect(url.searchParams.get('numOfRows')).toBe('1000');
      const pollen = url.pathname.includes('Pollen');
      expect(url.searchParams.get(pollen ? 'serviceKey' : 'ServiceKey')).toBe('key+value');
      return Response.json({ response: { header: { resultCode: '00' }, body: {
        totalCount: 1, items: { item: { areaNo: '1100000000',
          date: url.searchParams.get('time'), ...(pollen ? { today: '2' } : { h3: '75' }) } },
      } } });
    });
    await collectNationwideLivingIndices(db, 'key%2Bvalue', now, fetcher);
    const result = await readTodayLivingIndices(db, { nx: 60, ny: 127, adminCode: '1100000000' }, now);
    expect(result.pollenStatus).toBe('AVAILABLE');
    expect(result.pollen).toEqual([{ species: '잡초류', level: '높음', issuedAt: '2026-10-13T06:00:00+09:00' }]);
    expect(result.airStagnation?.level).toBe('높음');
    expect(fetcher).toHaveBeenCalledTimes(2);
    await collectNationwideLivingIndices(db, 'key%2Bvalue', now, fetcher);
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it('제공 기간 밖과 결측을 낮음으로 치환하지 않는다', async () => {
    const db = cacheDb();
    const july = await readTodayLivingIndices(db, { nx: 60, ny: 127, adminCode: '1100000000' },
      new Date('2026-07-13T03:00:00Z'));
    expect(july).toEqual({ pollenStatus: 'OUT_OF_SEASON', pollen: [] });
    const october = await readTodayLivingIndices(db, { nx: 60, ny: 127, adminCode: '1100000000' },
      new Date('2026-10-13T03:00:00Z'));
    expect(october).toEqual({ pollenStatus: 'UNAVAILABLE', pollen: [] });
  });

  it('봄에는 참나무와 소나무의 단계를 섞지 않고 보존한다', async () => {
    const db = cacheDb();
    const now = new Date('2026-05-13T03:10:00Z');
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = new URL(String(input));
      const level = url.pathname.includes('Oak') ? '3' : '1';
      return Response.json({ response: { header: { resultCode: '00' }, body: {
        totalCount: 1, items: { item: { areaNo: '1100000000',
          date: url.searchParams.get('time'), today: level, h3: '50' } },
      } } });
    });
    await collectNationwideLivingIndices(db, 'key', now, fetcher);
    const result = await readTodayLivingIndices(db, { nx: 60, ny: 127, adminCode: '1100000000' }, now);
    expect(result.pollen).toEqual([
      { species: '참나무', level: '매우 높음', issuedAt: '2026-05-13T06:00:00+09:00' },
      { species: '소나무', level: '보통', issuedAt: '2026-05-13T06:00:00+09:00' },
    ]);
    expect(fetcher).toHaveBeenCalledTimes(3);
  });

  it('빈 꽃가루 원본을 낮음으로 읽지 않는다', async () => {
    const db = cacheDb();
    const now = new Date('2026-10-13T03:10:00Z');
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = new URL(String(input));
      return Response.json({ response: { header: { resultCode: '00' }, body: {
        totalCount: 1, items: { item: { areaNo: '1100000000',
          date: url.searchParams.get('time'), today: ' ', h3: '-' } },
      } } });
    });
    await collectNationwideLivingIndices(db, 'key', now, fetcher);
    const result = await readTodayLivingIndices(db, { nx: 60, ny: 127, adminCode: '1100000000' }, now);
    expect(result).toEqual({ pollenStatus: 'UNAVAILABLE', pollen: [] });
  });
});
