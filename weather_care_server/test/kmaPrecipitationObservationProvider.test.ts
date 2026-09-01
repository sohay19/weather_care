import { describe, expect, it } from 'vitest';
import {
  KmaPrecipitationObservationProvider,
  parseAnalysisRain,
  radarGridPoint,
  radarRainAtPoint,
} from '../src/providers/precipitation/precipitationObservationProvider';
import { buildCurrentPrecipitationMessage } from '../src/presentation/currentPrecipitationMessage';

describe('KMA precipitation observation provider', () => {
  it('maps known Korean observation locations to the official 500m radar cells', () => {
    expect(radarGridPoint(37.44526, 126.96402)).toEqual({ x: 1286, y: 1561 });
    expect(radarGridPoint(35.11882, 128.99995)).toEqual({ x: 1657, y: 1065 });
    expect(radarGridPoint(33.35237, 126.53303)).toEqual({ x: 1218, y: 670 });
  });

  it('parses the latest valid rain flag at or before the requested time', () => {
    const parsed = parseAnalysisRain(
      [
        '# tm rn_ox',
        '202609011405 0',
        '202609011410 1',
        '202609011415 0',
      ].join('\n'),
      '202609011410',
    );

    expect(parsed).toEqual({
      observedAt: '2026-09-01T14:10:00+09:00',
      rainDetected: true,
    });
  });

  it('creates current-rain state only when analysis and radar both detect rain', async () => {
    const point = radarGridPoint(37.2636, 127.0286);
    const fetcher = async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes('nph-sfc_obs_nc_pt_api')) {
        return new Response('# tm rn_ox\n202609011410 1\n');
      }
      return new Response(radarPayload(point, 1234));
    };
    const provider = new KmaPrecipitationObservationProvider({
      serviceKey: 'test-key',
      fetcher,
      now: () => new Date('2026-09-01T05:20:00Z'),
      attempts: 1,
    });

    const observation = await provider.getCurrentByLocation(37.2636, 127.0286);

    expect(observation).toMatchObject({
      observedAt: '2026-09-01T14:10:00+09:00',
      analysisRainDetected: true,
      radarRainDetected: true,
      state: 'RAIN',
      radarDbz: 12.34,
    });
    expect(buildCurrentPrecipitationMessage(observation, true)?.parts).toEqual([
      expect.objectContaining({
        role: 'APP_SUGGESTION',
        text: '비가 내리고 있을 수 있어요. 지금 외출한다면 우산을 챙기세요',
      }),
      expect.objectContaining({
        role: 'INTERNAL_POSSIBILITY',
        text: '오후 2시 10분에는 비가 내리고 있을 수 있어요',
        source: '기상청 관측분석자료·기상청 레이더',
      }),
    ]);
  });

  it('treats the official no-echo code as dry', () => {
    const point = { x: 10, y: 20 };
    expect(radarRainAtPoint(radarPayload(point, -25_000), point)).toEqual({
      rainDetected: false,
    });
  });

  it('withholds the message when the two sources differ or umbrella alerts are off', () => {
    const observation = {
      observedAt: '2026-09-01T14:10:00+09:00',
      latitude: 37.2636,
      longitude: 127.0286,
      analysisRainDetected: true,
      radarRainDetected: false,
      state: 'MISMATCH' as const,
      provider: 'KMA_ANALYSIS_RADAR' as const,
    };

    expect(buildCurrentPrecipitationMessage(observation, true)).toBeUndefined();
    expect(
      buildCurrentPrecipitationMessage(
        { ...observation, radarRainDetected: true, state: 'RAIN' },
        false,
      ),
    ).toBeUndefined();
  });
});

function radarPayload(
  point: { x: number; y: number },
  value: number,
): ArrayBuffer {
  const nx = 2305;
  const ny = 2881;
  const payload = new ArrayBuffer(4 + nx * ny * 2);
  const view = new DataView(payload);
  view.setUint16(0, nx, true);
  view.setUint16(2, ny, true);
  view.setInt16(4 + (point.y * nx + point.x) * 2, value, true);
  return payload;
}
