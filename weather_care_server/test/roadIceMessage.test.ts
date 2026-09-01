import { describe, expect, it } from 'vitest';
import { buildRoadIceMessage } from '../src/presentation/roadIceMessage';
import { RoadIceRisk } from '../src/types';

describe('road ice message', () => {
  it('uses the product name and shows action before official possibility information', () => {
    const message = buildRoadIceMessage(risk(), '수원');

    expect(message?.type).toBe('BLACK_ICE_CAUTION');
    expect(message?.parts).toEqual([
      expect.objectContaining({
        role: 'APP_SUGGESTION',
        text: '블랙아이스가 생길 수 있으니, 해당 구간에서는 속도를 줄이고 충분한 안전거리를 두세요',
      }),
      expect.objectContaining({
        role: 'OFFICIAL_FACT',
        text: '기상청은 오전 10시 영동선 수원 인근 구간의 블랙아이스(도로살얼음) 발생 가능성을 주의 2단계로 안내했어요',
      }),
    ]);
  });
});

function risk(): RoadIceRisk {
  return {
    producedAt: '2026-01-15T01:00:00Z',
    roadNumber: '050',
    roadName: '영동선',
    linkId: 'risk-link',
    level: 2,
    levelLabel: '주의',
    sourceType: 'OBSERVATION',
    fromLatitude: 37.263,
    fromLongitude: 127.03,
    toLatitude: 37.264,
    toLongitude: 127.031,
    distanceMeters: 120,
    provider: '기상청 도로살얼음 발생 가능 정보',
  };
}
