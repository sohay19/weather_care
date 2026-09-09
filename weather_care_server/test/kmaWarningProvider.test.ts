import { describe, expect, it, vi } from 'vitest';
import {
  KmaWarningProvider,
  parseActiveWarnings,
  parseWarningRegionStations,
} from '../src/providers/warnings/kmaWarningProvider';
import { providerErrorDiagnostic } from '../src/observability/providerErrorDiagnostics';

const NOW = new Date('2026-09-01T01:30:00Z');

describe('KMA warning provider', () => {
  it('keeps only effective advisory and warning rows for the selected region', () => {
    const payload = `
# REG_UP REG_UP_KO REG_ID REG_KO TM_FC TM_EF WRN LVL CMD
L1010000 경기도 L1011900 수원 202609010900 202609011000 R 2 1
L1010000 경기도 L1011900 수원 202609010900 202609011000 W 1 1
L1010000 경기도 L1011900 수원 202609010900 202609011100 H 3 1
L1010000 경기도 L1012500 용인 202609010900 202609011000 S 3 1
L1010000 경기도 L1011900 수원 202609010900 202609011000 C 2 3
`;

    expect(parseActiveWarnings(payload, ['L1011900'], NOW)).toEqual([
      expect.objectContaining({
        typeCode: 'R',
        type: '호우',
        levelCode: '2',
        level: '주의보',
        regionId: 'L1011900',
        validFrom: '2026-09-01T10:00:00+09:00',
      }),
    ]);
  });

  it('requests a status snapshot using the effective-time reference', async () => {
    const fetcher = vi.fn(async () =>
      new Response(
        'L1010000,경기도,L1011900,수원,202609010900,202609011000,R,2,1',
      ),
    );
    const provider = new KmaWarningProvider({
      serviceKey: 'test-key',
      fetcher,
      now: () => NOW,
    });

    const result = await provider.getActiveForRegions(['L1011900']);

    expect(result).toHaveLength(1);
    const requestUrl = new URL(fetcher.mock.calls[0][0].toString());
    expect(requestUrl.searchParams.get('fe')).toBe('e');
    expect(requestUrl.searchParams.get('tm')).toBe('202609011030');
  });

  it('rejects an unknown payload instead of treating it as a release', () => {
    expect(() =>
      parseActiveWarnings('<html>maintenance</html>', ['L1011900'], NOW),
    ).toThrow('unsupported rows');
  });

  it('recognizes an APIHub error envelope returned with a successful HTTP status', () => {
    const error = (() => {
      try {
        parseActiveWarnings(
          '{"result":{"status":403,"message":"secret-value"}}',
          ['L1011900'],
          NOW,
        );
      } catch (caught) {
        return caught;
      }
    })();

    expect(providerErrorDiagnostic(error)).toEqual({
      error: 'KmaWarningProviderError',
      failureReason: 'AUTHORIZATION_FAILED',
      httpStatus: 403,
      operation: 'WARNING',
    });
    expect(JSON.stringify(providerErrorDiagnostic(error))).not.toContain(
      'secret-value',
    );
  });

  it('keeps a changed warning active and ignores unrelated release rows', () => {
    const payload = [
      'L1010000 경기도 L1011900 수원 202609010900 202609011000 R 2 6',
      'L1020000 강원도 L1020200 춘천 202609010900 202609011000 W 2 7',
    ].join('\n');

    expect(parseActiveWarnings(payload, ['L1011900'], NOW)).toEqual([
      expect.objectContaining({
        typeCode: 'R',
        commandCode: '6',
        regionId: 'L1011900',
      }),
    ]);
  });

  it('ignores an unknown unrelated row without hiding selected-region data', () => {
    const payload = [
      'future unrelated response row',
      'L1010000 경기도 L1011900 수원 202609010900 202609011000 R 2 1',
    ].join('\n');

    expect(parseActiveWarnings(payload, ['L1011900'], NOW)).toHaveLength(1);
  });

  it('ignores timestamped rows for other regions when their columns expand', () => {
    const payload =
      'L1020000 강원도 L1020200 춘천 확장열 202609010900 202609011000 W 2 1';

    expect(parseActiveWarnings(payload, ['L1011900'], NOW)).toEqual([]);
  });

  it('parses the official observation-station to warning-region mapping', () => {
    const payload = [
      '# STN_ID STN_KO STN_SP LON LAT HT FCT_ID WRN_ID WRN_KO',
      '119,수원,1,127.0286,37.2636,39.0,11B20601,L1011900,수원',
      '159,부산,1,129.0320,35.1047,69.6,11H20201,L1080100,부산',
      '=',
    ].join('\n');

    expect(parseWarningRegionStations(payload)).toEqual([
      expect.objectContaining({
        stationId: '119',
        stationName: '수원',
        regionId: 'L1011900',
        regionName: '수원',
        latitude: 37.2636,
        longitude: 127.0286,
      }),
      expect.objectContaining({
        stationId: '159',
        regionId: 'L1080100',
        regionName: '부산',
      }),
    ]);
  });

  it('resolves the nearest official warning region for a nationwide GPS location', async () => {
    const fetcher = vi.fn(async () =>
      new Response([
        '119 수원 1 127.0286 37.2636 39.0 11B20601 L1011900 수원',
        '159 부산 1 129.0320 35.1047 69.6 11H20201 L1080100 부산',
      ].join('\n')),
    );
    const provider = new KmaWarningProvider({
      serviceKey: 'test-key',
      fetcher,
      now: () => NOW,
    });

    const match = await provider.resolveRegionByLocation(35.1796, 129.0756);

    expect(match).toMatchObject({
      stationId: '159',
      stationName: '부산',
      regionId: 'L1080100',
      regionName: '부산',
    });
    expect(match.distanceMeters).toBeLessThan(10_000);
    const requestUrl = new URL(fetcher.mock.calls[0][0].toString());
    expect(requestUrl.pathname).toContain('wrn_reg_aws2.php');
  });
});
