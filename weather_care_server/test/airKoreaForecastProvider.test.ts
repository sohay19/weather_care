import { describe, expect, it, vi } from 'vitest';
import {
  AirKoreaForecastProvider,
  AIRKOREA_FORECAST_AREAS,
  airKoreaForecastArea,
  airKoreaForecastAreaForGrid,
  airKoreaForecastAreaForAdminCode,
} from '../src/providers/air/airKoreaForecastProvider';

describe('AirKoreaForecastProvider', () => {
  it('merges short-range air grades and weekly PM2.5 confidence by date', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = new URL(String(input));
      if (url.pathname.endsWith('getMinuDustWeekFrcstDspth')) {
        return jsonResponse([{
          frcstOneDt: '2026-09-18',
          frcstOneCn: '서울 : 높음, 경기남부 : 낮음, 신뢰도 : 높음',
          frcstTwoDt: '2026-09-19',
          frcstTwoCn: '서울 : 낮음, 경기남부 : 높음, 신뢰도 : 보통',
        }]);
      }
      return jsonResponse([
        {
          dataTime: '2026-09-15 11시 발표',
          informCode: 'PM10',
          informData: '2026-09-15',
          informGrade: '서울 : 좋음,경기남부 : 보통',
          informCause: '일부 지역은 황사의 영향을 받을 수 있습니다.',
        },
        {
          dataTime: '2026-09-15 11시 발표',
          informCode: 'PM25',
          informData: '2026-09-15',
          informGrade: '서울 : 보통,경기남부 : 좋음',
        },
        {
          dataTime: '2026-09-15 11시 발표',
          informCode: 'O3',
          informData: '2026-09-16',
          informGrade: '서울 : 나쁨,경기남부 : 보통',
        },
      ]);
    });
    const provider = new AirKoreaForecastProvider({
      serviceKey: 'test',
      fetcher,
      now: () => new Date('2026-09-15T03:00:00Z'),
    });

    await expect(provider.getForecast('시흥시 은행동', 58, 124)).resolves.toEqual([
      {
        date: '20260915',
        pm10Grade: '보통',
        pm25Grade: '좋음',
        yellowDustMentioned: true,
      },
      { date: '20260916', ozoneGrade: '보통' },
      { date: '20260918', pm25Grade: '낮음', confidence: '높음' },
      { date: '20260919', pm25Grade: '높음', confidence: '낮음' },
    ]);
    expect(fetcher).toHaveBeenCalledTimes(4);
  });

  it('maps supported forecast areas without confusing Gyeonggi Gwangju', () => {
    expect(airKoreaForecastArea('경기도 광주시', 61, 123)).toBe('경기남부');
    expect(airKoreaForecastArea('강원특별자치도 강릉시', 92, 131)).toBe('영동');
    expect(airKoreaForecastArea('전라남도 순천시', 70, 70)).toBe('전남');
    expect(airKoreaForecastArea(undefined, 60, 127)).toBe('서울');
    expect(airKoreaForecastAreaForGrid(60, 127)).toBeUndefined();
    expect(airKoreaForecastAreaForGrid(100, 76)).toBeUndefined();
  });

  it('전국 예보 지역을 네 번의 공통 원본 호출로 채운다', async () => {
    const grades = AIRKOREA_FORECAST_AREAS.map((area) => `${area}: 보통`).join(',');
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = new URL(String(input));
      return url.pathname.endsWith('getMinuDustWeekFrcstDspth')
        ? jsonResponse([{ frcstOneDt: '2026-09-18', frcstOneCn: grades }])
        : jsonResponse([{
            dataTime: '2026-09-15 11시 발표',
            informCode: url.searchParams.get('InformCode'),
            informData: '2026-09-15', informGrade: grades,
          }]);
    });
    const provider = new AirKoreaForecastProvider({ serviceKey: 'test', fetcher,
      now: () => new Date('2026-09-15T03:00:00Z') });

    const forecasts = await provider.getForecastsByAreas();

    expect(fetcher).toHaveBeenCalledTimes(4);
    expect(Object.keys(forecasts)).toHaveLength(AIRKOREA_FORECAST_AREAS.length);
    expect(forecasts['서울']?.[0]).toMatchObject({ date: '20260915', pm25Grade: '보통' });
    expect(forecasts['부산']?.[0]).toMatchObject({ date: '20260915', pm10Grade: '보통' });
    const delayed = new AirKoreaForecastProvider({ serviceKey: 'test', fetcher,
      now: () => new Date('2026-09-15T09:00:00Z') });
    await expect(delayed.getForecastsByAreas()).rejects.toThrow('publication is incomplete');
  });

  it.each([
    ['김포시', 55, 128, '4157000000', '경기북부'], ['구리시', 62, 127, '4131000000', '경기북부'],
    ['남양주시', 64, 128, '4136000000', '경기북부'], ['고양시 일산동구', 56, 129, '4128500000', '경기북부'],
    ['양평군', 69, 125, '4183000000', '경기남부'], ['태백시', 95, 119, '5119000000', '영동'],
    ['평창군', 84, 123, '5176000000', '영서'], ['정선군', 89, 123, '5177000000', '영서'],
    ['광주광역시', 58, 74, '1230000000', '광주'], ['전라남도 목포시', 50, 67, '1211000000', '전남'],
  ])('공식 행정코드로 %s의 예보 권역을 구분한다', (name, nx, ny, code, area) => {
    expect(airKoreaForecastAreaForAdminCode(code as string)).toBe(area);
    expect(airKoreaForecastArea(name as string, nx as number, ny as number)).toBe(area);
  });
});

function jsonResponse(items: unknown[]): Response {
  return new Response(JSON.stringify({
    response: {
      header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' },
      body: { items },
    },
  }), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });
}
