import { LifestyleInsightType, RecommendationType } from '../types';

export const recommendationMessageCatalog: Record<RecommendationType, string[]> = {
  UMBRELLA: [
    '오후 비가 예상돼요. 우산을 챙겨요.',
    '외출 중 비를 만날 수 있어요. 접이식 우산이 있으면 좋아요.',
    '퇴근 무렵 비 가능성이 높아요. 나가기 전에 우산을 확인하세요.',
  ],
  PARASOL: [
    '낮에는 햇볕이 강할 가능성이 있어요. 양산이 있으면 좋아요.',
    '한낮 햇볕을 오래 받기 쉬워요. 가벼운 양산을 챙겨요.',
    '그늘이 적은 길을 걷는다면 양산이 도움이 돼요.',
  ],
  HEAVY_SNOW_CAUTION: [
    '많은 눈이 예상돼요. 이동할 때 주의하세요.',
    '눈이 쌓일 수 있어요. 미끄럼에 유의하고 여유 있게 출발하세요.',
    '강설 시간대에는 보행과 운전 속도를 낮춰주세요.',
  ],
  OUTERWEAR: [
    '아침저녁이 쌀쌀하고 바람이 있어요. 가벼운 겉옷을 챙겨요.',
    '시간대별 체감 차이가 커요. 벗기 쉬운 겉옷이 편해요.',
    '바람 때문에 숫자보다 서늘할 수 있어요. 얇은 겉옷을 준비하세요.',
  ],
  MASK: [
    '미세먼지가 높아 외출 시 마스크를 챙겨요.',
    '대기질이 좋지 않은 시간이 있어요. 민감하다면 마스크를 준비하세요.',
    '긴 야외활동을 한다면 마스크가 도움이 될 수 있어요.',
  ],
  WATER: [
    '체감온도가 높아 수분 보충이 중요해요.',
    '더운 시간이 이어져요. 작은 물병을 가까이 두세요.',
    '갈증을 느끼기 전부터 조금씩 자주 마셔요.',
  ],
  SUNSCREEN: [
    '자외선이 강해요. 선크림을 챙겨요.',
    '한낮 자외선 노출이 커요. 외출 전에 선크림을 발라요.',
    '야외 일정이 있다면 선크림을 덧바를 준비를 하세요.',
  ],
};

export function titleFor(type: RecommendationType): string {
  return {
    UMBRELLA: '우산',
    PARASOL: '양산',
    HEAVY_SNOW_CAUTION: '폭설 주의',
    OUTERWEAR: '겉옷',
    MASK: '마스크',
    WATER: '물',
    SUNSCREEN: '선크림',
  }[type];
}

export function descriptionFor(
  type: RecommendationType,
  insightTypes: LifestyleInsightType[],
): string {
  const candidates = recommendationMessageCatalog[type];
  const seed = insightTypes.join('|').split('').reduce((sum, char) => sum + char.charCodeAt(0), 0);
  if (
    type === 'OUTERWEAR' &&
    (insightTypes.includes(LifestyleInsightType.COOLER_THAN_TEMPERATURE) ||
      insightTypes.includes(LifestyleInsightType.OUTERWEAR_USEFUL))
  ) {
    return candidates[0];
  }
  return candidates[seed % candidates.length];
}
