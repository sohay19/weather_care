import { LifestyleInsightType, RecommendationType } from '../types';

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
  switch (type) {
    case 'UMBRELLA':
      return '오후 비가 예상돼요. 우산을 챙겨요.';
    case 'PARASOL':
      return '낮에는 햇볕이 강할 가능성이 있어요. 양산이 있으면 좋아요.';
    case 'HEAVY_SNOW_CAUTION':
      return '많은 눈이 예상돼요. 이동할 때 주의하세요.';
    case 'OUTERWEAR':
      return insightTypes.includes(LifestyleInsightType.COOLER_THAN_TEMPERATURE) || insightTypes.includes(LifestyleInsightType.OUTERWEAR_USEFUL)
          ? '아침저녁이 쌀쌀하고 바람이 있어요.'
          : '겉옷이 유용해 보여요.';
    case 'MASK':
      return '미세먼지가 높아 외출 시 마스크를 챙겨요.';
    case 'WATER':
      return '체감온도가 높아 수분 보충이 중요해요.';
    case 'SUNSCREEN':
      return '자외선이 강해요. 선크림을 챙겨요.';
    default:
      return '현재 조건에 맞는 행동입니다.';
  }
}

