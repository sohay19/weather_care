import { describe, expect, it } from 'vitest';
import {
  morningBriefDestination,
  recommendationDestination,
  warningDestination,
} from '../src/notification/notificationDestination';
import { buildNotification } from '../src/notification/notificationBuilder';
import { Recommendation, RecommendationType } from '../src/types';

describe('notification destinations', () => {
  it('opens a morning brief on the main screen', () => {
    expect(morningBriefDestination).toEqual({
      target: 'MAIN',
      topic: 'OVERVIEW',
    });
  });

  it('maps recommendation types to weather detail topics', () => {
    const cases: Array<[RecommendationType, string]> = [
      ['UMBRELLA', 'PRECIPITATION'],
      ['PARASOL', 'UV'],
      ['HEAVY_SNOW_CAUTION', 'SNOW'],
      ['OUTERWEAR', 'TEMPERATURE'],
      ['MASK', 'AIR_QUALITY'],
      ['WATER', 'HEAT'],
      ['SUNSCREEN', 'UV'],
    ];

    for (const [type, topic] of cases) {
      expect(recommendationDestination(type)).toEqual({
        target: 'WEATHER_DETAILS',
        topic,
      });
    }
  });

  it('maps every official warning type to its related detail topic', () => {
    const cases = {
      W: 'STRONG_WIND',
      R: 'PRECIPITATION',
      C: 'TEMPERATURE',
      D: 'WEATHER_WARNING',
      O: 'WEATHER_WARNING',
      N: 'WEATHER_WARNING',
      V: 'WEATHER_WARNING',
      T: 'WEATHER_WARNING',
      S: 'SNOW',
      Y: 'AIR_QUALITY',
      H: 'HEAT',
      F: 'COMMUTE',
      K: 'SLEEP',
    };

    for (const [typeCode, topic] of Object.entries(cases)) {
      expect(warningDestination(typeCode)).toEqual({
        target: 'WEATHER_DETAILS',
        topic,
      });
    }
  });

  it('keeps a combined brief on main and sends standalone heavy snow to detail', () => {
    const umbrella = recommendation('UMBRELLA');
    const snow = recommendation('HEAVY_SNOW_CAUTION');

    expect(buildNotification([umbrella, snow])).toMatchObject([
      {
        notification_key: 'MORNING_BRIEF',
        destination: { target: 'MAIN', topic: 'OVERVIEW' },
      },
      {
        notification_key: 'IMPORTANT_HEAVY_SNOW_CAUTION',
        destination: { target: 'WEATHER_DETAILS', topic: 'SNOW' },
      },
    ]);
  });

  it('places each morning brief message on its own line', () => {
    expect(
      buildNotification([
        recommendation('UMBRELLA'),
        recommendation('PARASOL'),
      ])[0].body,
    ).toBe('UMBRELLA description\nPARASOL description');
  });
});

function recommendation(type: RecommendationType): Recommendation {
  return {
    type,
    recommended: true,
    priority: 100,
    title: type,
    description: `${type} description`,
    reasonCodes: [],
    notificationEligible: true,
  };
}
