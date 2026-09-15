import { describe, expect, it } from 'vitest';
import {
  KmaDailyObservationProvider,
  parseKmaDailyObservationRows,
} from '../src/providers/weather/kmaDailyObservationProvider';

describe('KMA daily observation provider', () => {
  it('parses documented station daily rows and ignores help text', () => {
    expect(parseKmaDailyObservationRows([
      '# TM STN LON LAT HT VAL',
      '20260914,108,126.9658,37.5714,85.67,18.4',
      '20260914,109,126.9000,37.5000,85.67,',
      'malformed row',
    ].join('\n'))).toEqual([{
      date: '2026-09-14',
      stationId: '108',
      longitude: 126.9658,
      latitude: 37.5714,
      value: 18.4,
    }]);
  });

  it('uses the nearest station with daily minimum and maximum values', async () => {
    const values: Record<string, Record<string, number>> = {
      ta_min: { '108': 18, '999': 16 },
      ta_max: { '108': 27, '999': 25 },
      rn_day: { '108': 4.5, '999': 0 },
      sd_day_max: { '108': 0, '999': 0 },
    };
    const provider = new KmaDailyObservationProvider({
      serviceKey: 'test-key',
      fetcher: async (input) => {
        const metric = new URL(String(input)).searchParams.get('obs')!;
        const rows = [
          `20260914,108,126.9658,37.5714,85.67,${values[metric]['108']}`,
          `20260914,999,129.0000,35.0000,10.00,${values[metric]['999']}`,
        ];
        return new Response(rows.join('\n'));
      },
    });

    await expect(provider.getDailyByLocation(
      37.56,
      126.97,
      '2026-09-14',
      '2026-09-14',
    )).resolves.toEqual([expect.objectContaining({
      date: '20260914',
      forecastSource: 'KMA_OBSERVATION',
      historical: true,
      observationStationId: '108',
      minTemperature: 18,
      maxTemperature: 27,
      skyCondition: '비',
      precipitationAmount: 4.5,
      precipitationDetail: {
        kind: 'OBSERVATION',
        hours: [],
        observedAmount: 4.5,
      },
    })]);
  });
});
