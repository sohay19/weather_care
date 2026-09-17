import { describe, expect, it } from 'vitest';
import {
  buildMidTermDailyForecast,
  KmaMidTermProvider,
  latestMidTermIssueTimes,
} from '../src/providers/weather/kmaMidTermProvider';
import {
  resolveKmaMidTermRegionIds,
} from '../src/regions/kmaMidTermRegionCatalog';

describe('KmaMidTermProvider', () => {
  it('uses the latest published 06:00 or 18:00 issue', () => {
    expect(latestMidTermIssueTimes(
      new Date('2026-09-14T20:00:00Z'),
      2,
    )).toEqual(['202609141800', '202609140600']);
    expect(latestMidTermIssueTimes(
      new Date('2026-09-15T01:00:00Z'),
      2,
    )).toEqual(['202609150600', '202609141800']);
  });

  it('builds days 4 through 10 without inventing hourly amounts', () => {
    const temperature: Record<string, string> = { regId: '11B20202' };
    const land: Record<string, string> = { regId: '11B00000' };
    for (let day = 4; day <= 10; day++) {
      temperature[`taMin${day}`] = String(10 + day);
      temperature[`taMax${day}`] = String(20 + day);
      if (day <= 7) {
        land[`wf${day}Am`] = '맑음';
        land[`wf${day}Pm`] = day === 6 ? '흐리고 비' : '구름많음';
        land[`rnSt${day}Am`] = '20';
        land[`rnSt${day}Pm`] = day === 6 ? '70' : '30';
      } else {
        land[`wf${day}`] = '구름많음';
        land[`rnSt${day}`] = '30';
      }
    }
    const days = buildMidTermDailyForecast('202609150600', temperature, land);
    expect(days).toHaveLength(7);
    expect(days[0]).toMatchObject({
      date: '20260919',
      forecastSource: 'KMA_MID_TERM',
      issuedAt: '2026-09-15T06:00:00+09:00',
      minTemperature: 14,
      maxTemperature: 24,
    });
    expect(days[2]).toMatchObject({
      date: '20260921',
      skyCondition: '비',
      precipitationProbability: 70,
      precipitationAmount: 0,
      precipitationDetail: { kind: 'EXTENDED', extendedMaxProbability: 70 },
    });
  });

  it('fetches temperature and land data for the resolved city', async () => {
    const calls: string[] = [];
    const fetcher: typeof fetch = async (input) => {
      const url = new URL(input.toString());
      calls.push(url.toString());
      const isTemperature = url.pathname.endsWith('/getMidTa');
      return new Response(JSON.stringify({
        response: {
          header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' },
          body: { items: { item: [{
            regId: url.searchParams.get('regId'),
            ...(isTemperature
              ? { taMin4: 15, taMax4: 25 }
              : { wf4Am: '맑음', wf4Pm: '구름많음', rnSt4Am: 10, rnSt4Pm: 30 }),
          }] } },
        },
      }));
    };
    const provider = new KmaMidTermProvider({
      apiHubKey: 'decoded key',
      fetcher,
      now: () => new Date('2026-09-15T01:00:00Z'),
    });
    const days = await provider.getForecast({
      temperatureRegionId: '11B20202',
      landRegionId: '11B00000',
    });
    expect(days[0]).toMatchObject({ date: '20260919', minTemperature: 15 });
    expect(calls).toHaveLength(2);
    expect(calls.every((url) => url.includes('tmFc=202609150600'))).toBe(true);
    expect(calls.every((url) => url.startsWith('https://apihub.kma.go.kr/'))).toBe(true);
    expect(calls.every((url) => url.includes('authKey=decoded+key'))).toBe(true);
  });
});

describe('KMA mid-term region catalog', () => {
  it('matches Siheung down to a dong and resolves official region codes', () => {
    expect(resolveKmaMidTermRegionIds(
      '시흥시 은행동',
      undefined,
      58,
      124,
    )).toEqual({
      temperatureRegionId: '11B20202',
      landRegionId: '11B00000',
    });
  });

  it('disambiguates Gwangju and Goseong by legal-region prefix', () => {
    expect(resolveKmaMidTermRegionIds('광주시', '4161000000', 65, 123))
      .toMatchObject({ temperatureRegionId: '11B20702' });
    expect(resolveKmaMidTermRegionIds('광주 북구', '2917000000', 58, 74))
      .toMatchObject({ temperatureRegionId: '11F20501' });
    expect(resolveKmaMidTermRegionIds('고성군', '5182000000', 85, 145))
      .toMatchObject({ temperatureRegionId: '11D20402' });
    expect(resolveKmaMidTermRegionIds('고성군', '4882000000', 85, 128))
      .toMatchObject({ temperatureRegionId: '11H20404' });
  });
});
