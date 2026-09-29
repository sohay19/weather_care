import { describe, expect, it } from 'vitest';
import type { TodayWeatherResponse } from '../src/types';
import { buildHomeWidgetSnapshot } from '../src/presentation/homeWidgetSnapshot';
import { midTermRegionNameForGrid } from '../src/regions/kmaMidTermRegionCatalog';

describe('home widget snapshot', () => {
  it('GPS 표시명이 없으면 예보 격자의 대표 지역명을 사용한다', () => {
    expect(midTermRegionNameForGrid(57, 124)).toBe('시흥');
  });

  it('새로고침 응답을 앱과 동일한 위젯 형식으로 만든다', () => {
    const now = new Date('2026-09-27T23:20:00.000Z');
    const today = {
      region: { nx: 58, ny: 124, name: '현재 위치' },
      generatedAt: now.toISOString(),
      current: {
        observedAt: now.toISOString(),
        temperature: 18,
        apparentTemperature: 17.5,
        skyCondition: '구름많음',
      },
      nextForecast: {
        observedAt: '2026-09-28T00:00:00.000Z',
        forecastAt: '2026-09-28T00:00:00.000Z',
        temperature: 19,
        skyCondition: '맑음',
      },
      brief: '오전에는  선선해요.',
      briefing: {
        briefingId: 'brief-1',
        locationKey: '58_124',
        sceneId: 'THERMAL_COMFORTABLE',
        validFrom: '2026-09-27T22:00:00.000Z',
        validUntil: '2026-09-28T01:00:00.000Z',
        recommendedItems: ['OUTERWEAR'],
        copyVariantKey: 'comfortable',
        copy: {
          short: '겉옷을 챙기세요',
          medium: '얇은 겉옷이 좋아요',
          long: '오전에는 선선해요.',
          notificationTitle: '',
          notificationBody: '',
        },
      },
      briefingTimeline: [{
        briefingId: 'brief-1',
        sceneId: 'THERMAL_COMFORTABLE',
        validFrom: '2026-09-27T22:00:00.000Z',
        validUntil: '2026-09-28T01:00:00.000Z',
        recommendedItems: ['OUTERWEAR'],
        copyVariantKey: 'comfortable',
        copy: {
          short: '겉옷을 챙기세요',
          medium: '얇은 겉옷이 좋아요',
          long: '오전에는 선선해요.',
          notificationTitle: '',
          notificationBody: '',
        },
      }],
      recommendations: [],
    } as unknown as TodayWeatherResponse;

    const snapshot = buildHomeWidgetSnapshot(today, {
      days: [{
        forecastDate: '2026-09-28',
        min: '12',
        max: '20',
        historical: false,
      }],
    }, now, '경기도 시흥시 은행동');

    expect(snapshot).toMatchObject({
      schemaVersion: 3,
      region: '시흥시 은행동',
      refreshTime: '오전 8:20 기준',
      condition: 'partlyCloudy',
      currentTemperature: '18°',
      apparentTemperature: '17.5°',
      minimumTemperature: '12°',
      maximumTemperature: '20°',
      nextTime: '오전 9시',
      nextCondition: 'clear',
      shortMessage: '겉옷을 챙기세요',
      preparations: [{ type: 'OUTERWEAR', label: '두꺼운 겉옷' }],
    });
  });
});
