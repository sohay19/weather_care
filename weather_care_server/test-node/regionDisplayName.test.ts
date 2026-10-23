import { describe, expect, it } from 'vitest';
import { displayAdministrativeName, administrativeAreaForLocation } from '../src/regions/nationwideLocation';
import { resolveSavedLocation } from '../src/regions/resolvedLocation';
import { SqliteD1Database, asD1Database, runSqliteMigrations } from '../src/node/sqliteD1';

describe('지역명 서수 표시', () => {
  it.each([
    ['서울 구로구 구로제3동', '서울 구로구 구로3동'],
    ['(구로제3동)', '(구로3동)'],
    ['상계제3·4동', '상계3·4동'],
    ['거제1동', '거제1동'], ['홍제3동', '홍제3동'],
    ['거제제1동', '거제1동'], ['제주 제주시', '제주 제주시'],
  ])('%s → %s', (original, expected) => {
    expect(displayAdministrativeName(original)).toBe(expected);
  });

  it('코드·격자·공식 원본은 보존하고 확정 이름만 표시용으로 반환한다', async () => {
    const database = new SqliteD1Database(':memory:');
    try {
      runSqliteMigrations(database);
      const location = { nx: 58, ny: 125, regionName: '서울특별시 구로구 구로제3동' };
      const original = administrativeAreaForLocation(location)!;
      expect(original[1]).toBe(location.regionName);
      const result = await resolveSavedLocation(asD1Database(database), location, new Date());
      expect(result.regionName).toBe('서울특별시 구로구 구로3동');
      expect(result.adminCode).toBe(original[0]);
      expect(administrativeAreaForLocation(result)?.[0]).toBe(original[0]);
      expect(administrativeAreaForLocation(location)?.[1]).toBe(location.regionName);
      expect((await resolveSavedLocation(undefined, location, new Date())).regionName).toBe(result.regionName);
    } finally { database.close(); }
  });
});
