import { describe, expect, it } from 'vitest';
import {
  buildRoadControlMessage,
  roadControlNotification,
} from '../src/presentation/roadControlMessage';
import { OfficialRoadControl } from '../src/types';

describe('road control message', () => {
  it('shows an actionable route check before the active official fact', () => {
    const message = buildRoadControlMessage(control());

    expect(message?.type).toBe('COMMUTE_ROUTE_CAUTION');
    expect(message?.parts).toEqual([
      expect.objectContaining({
        role: 'APP_SUGGESTION',
        text: '수원지하차도 서울방향 전면 통제가 시행 중이니, 출발 전에 다른 경로와 대중교통 운행정보를 확인하세요',
      }),
      expect.objectContaining({
        role: 'OFFICIAL_FACT',
        text: '국가교통정보센터는 9월 1일 오후 2시부터 수원지하차도 서울방향 전면 통제가 시행 중이라고 안내했어요',
      }),
    ]);
  });

  it('does not invent a named detour when the provider has no detour field', () => {
    const content = roadControlNotification({
      ...control(),
      roadName: undefined,
      direction: undefined,
      controlKind: 'PARTIAL',
    });

    expect(content.body).toBe(
      '도로 일부 차로가 통제 중이니, 출발 전에 교통정보를 확인하세요 국가교통정보센터는 9월 1일 오후 2시부터 도로 일부 차로 통제가 시행 중이라고 안내했어요',
    );
    expect(content.body).not.toContain('우회할 수 있다면');
  });

  it('writes midnight as 0시 with the start date', () => {
    const message = buildRoadControlMessage({
      ...control(),
      startedAt: '2026-06-21T15:00:00Z',
    });

    expect(message?.description).toContain('6월 22일 0시부터');
    expect(message?.description).not.toContain('오전 12시');
  });
});

function control(): OfficialRoadControl {
  return {
    eventKey: 'link-1|20260901140000|재난|침수',
    startedAt: '2026-09-01T14:00:00+09:00',
    roadName: '수원지하차도',
    direction: '서울방향',
    controlKind: 'FULL',
    lanesBlocked: '전면 통제',
    eventType: '재난',
    eventDetailType: '침수',
    message: '침수로 전면 통제합니다',
    linkId: 'link-1',
    latitude: 37.264,
    longitude: 127.029,
    distanceMeters: 80,
    provider: '국가교통정보센터 돌발상황정보',
  };
}
