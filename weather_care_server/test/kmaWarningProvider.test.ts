import { describe, expect, it, vi } from 'vitest';
import {
  KmaWarningProvider,
  nearestWarningRegion,
  parseActiveWarnings,
  parseWarningRegionStations,
} from '../src/providers/warnings/kmaWarningProvider';
import { providerErrorDiagnostic } from '../src/observability/providerErrorDiagnostics';
import eucKrFixture from './fixtures/kmaWarningEucKr.json';

const NOW = new Date('2026-09-01T01:30:00Z');

describe('KMA warning provider', () => {
  it.each([eucKrFixture.contentType, undefined])(
    '실제 EUC-KR 특보의 한글 값과 빈 해제예고 열을 읽는다 (%s)',
    async (contentType) => {
      const fetcher = vi.fn(async () => new Response(
        Uint8Array.from(atob(eucKrFixture.statusBase64), (character) => character.charCodeAt(0)),
        { headers: contentType ? { 'content-type': contentType } : undefined },
      ));
      const provider = new KmaWarningProvider({
        serviceKey: 'test-key', fetcher,
        now: () => new Date('2026-10-03T14:00:00Z'),
      });
      expect(await provider.getActiveForRegions([
        'L1100200', 'L1100300', 'L1100400', 'L1011900',
      ])).toEqual([
        expect.objectContaining({ regionName: '서울동북권', typeCode: 'D', levelCode: '2', commandCode: '1' }),
        expect.objectContaining({ regionName: '서울서남권', type: '건조', level: '주의보' }),
        expect.objectContaining({ regionName: '서울서북권', type: '건조', level: '주의보' }),
      ]);
    },
  );

  it('실제 EUC-KR 관측소 매핑에서 대표지점번호와 종결자를 이름에서 제외한다', async () => {
    const provider = new KmaWarningProvider({
      serviceKey: 'test-key',
      fetcher: vi.fn(async () => new Response(
        Uint8Array.from(atob(eucKrFixture.mappingBase64), (character) => character.charCodeAt(0)),
        { headers: { 'content-type': eucKrFixture.contentType } },
      )),
    });
    expect(await provider.getRegionStations()).toEqual([
      expect.objectContaining({ stationId: '42', stationName: '군산오식도', regionName: '군산(옥도면 제외)' }),
      expect.objectContaining({ stationId: '43', stationName: '솔라시도', regionName: '해남북부' }),
      expect.objectContaining({ stationId: '44', stationName: '삼호', regionName: '영암군' }),
    ]);
  });

  it('한글 대치·연장·변경은 유지하고 해제·예비·미래 발효는 활성 특보에서 제외한다', () => {
    const row = (level: string, command: string, effective = '202609011000') =>
      `L1010000,경기도,L1011900,수원,202609010900,${effective},폭풍해일,${level},${command},202609011200,=`;
    const payload = [
      row('주의보', '대치'), row('경보', '연장'), row('주의', '변경'),
      row('주의', '해제'), row('주의', '대치해제'), row('주의', '변경해제'),
      row('예비', '발표'), row('예비특보', '발표'), row('주의', '발표', '202609011100'),
    ].join('\n');
    expect(parseActiveWarnings(payload, ['L1011900'], NOW)).toEqual([
      expect.objectContaining({ typeCode: 'O', levelCode: '2', commandCode: '2' }),
      expect.objectContaining({ typeCode: 'O', levelCode: '3', commandCode: '5' }),
      expect.objectContaining({ typeCode: 'O', levelCode: '2', commandCode: '6' }),
    ]);
  });

  it('선택 지역의 알 수 없는 한글 코드나 열은 특보 없음으로 처리하지 않는다', () => {
    for (const fields of ['건조,주의,알수없음', '알수없음,주의,발표', '건조,알수없음,발표', '건조,주의,발표,알수없음']) {
      expect(() => parseActiveWarnings(
        `L1010000,경기도,L1011900,수원,202609010900,202609011000,${fields},=`,
        ['L1011900'], NOW,
      )).toThrow('selected region row has an unknown format');
    }
  });

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

  it('전국 측정소 목록에서 같은 예보 격자의 서로 다른 GPS 특보 지역을 구분한다', () => {
    const stations = [
      { stationId: '1', stationName: '서쪽', regionId: 'L1000001',
        regionName: '서쪽', latitude: 37.487, longitude: 126.890 },
      { stationId: '2', stationName: '동쪽', regionId: 'L1000002',
        regionName: '동쪽', latitude: 37.487, longitude: 126.900 },
    ];
    expect(nearestWarningRegion(stations, 37.487652, 126.893405).regionId)
      .toBe('L1000001');
    expect(nearestWarningRegion(stations, 37.4868, 126.8982).regionId)
      .toBe('L1000002');
  });
});
