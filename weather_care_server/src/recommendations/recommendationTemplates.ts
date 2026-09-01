import { LifestyleInsightType, RecommendationType } from '../types';

export const CATALOG_VERSION = 'ko-KR-2026.09.1';

export const recommendationMessageCatalog: Record<RecommendationType, string[]> = {
  UMBRELLA: [
    '비가 올 수 있으니, 외출한다면 우산을 챙기세요.',
    '비가 예상되니, 나가기 전에 우산을 준비하세요.',
    '비가 내릴 수 있으니, 외출할 계획이라면 우산을 챙기세요.',
  ],
  PARASOL: [
    '자외선이 강할 수 있으니, 그늘이 적은 야외에 나간다면 양산이나 모자를 준비하세요.',
    '자외선이 강할 수 있으니, 외출한다면 양산을 준비하세요.',
    '자외선이 강할 수 있으니, 야외에 나간다면 양산이나 모자를 챙기세요.',
  ],
  HEAVY_SNOW_CAUTION: [
    '눈이 많이 쌓일 수 있으니, 외출 전에 도로 통제와 대중교통 운행정보를 확인하세요.',
    '눈이 많이 내릴 수 있으니, 보행하거나 운전한다면 속도를 줄이세요.',
    '눈이 쌓일 수 있으니, 이동한다면 미끄러운 구간을 조심하세요.',
  ],
  OUTERWEAR: [
    '기온이 낮거나 바람이 강할 수 있으니, 외출한다면 겉옷을 준비하세요.',
    '예상 체감온도가 낮게 계산됐으니, 외출 전에 겉옷을 챙기세요.',
    '시간대별 기온 차가 클 수 있으니, 벗어 들기 쉬운 겉옷을 준비하세요.',
  ],
  MASK: [
    '미세먼지나 초미세먼지가 나쁨 단계이니, 외출한다면 보건용 마스크를 준비하세요.',
    '대기질이 나쁨 단계이니, 외출할 계획이라면 보건용 마스크를 챙기세요.',
    '미세먼지 농도가 높게 관측됐으니, 나가기 전에 보건용 마스크를 준비하세요.',
  ],
  WATER: [
    '예상 체감온도가 높게 계산됐으니, 더운 시간에 외출한다면 물을 미리 준비하세요.',
    '예상 체감온도가 높게 계산됐으니, 실외활동을 한다면 물을 챙기세요.',
    '더운 시간이 이어질 수 있으니, 외출 전에 물을 준비하세요.',
  ],
  SUNSCREEN: [
    '자외선이 강할 수 있으니, 외출한다면 자외선 차단제를 준비하세요.',
    '자외선지수가 높을 수 있으니, 야외에 나간다면 자외선 차단제를 챙기세요.',
    '자외선 노출이 커질 수 있으니, 외출 전에 자외선 차단제를 준비하세요.',
  ],
};

export function titleFor(type: RecommendationType): string {
  return {
    UMBRELLA: '우산',
    PARASOL: '양산',
    HEAVY_SNOW_CAUTION: '많은 눈 대비',
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
    type === 'UMBRELLA' &&
    insightTypes.includes(LifestyleInsightType.OUTDOOR_ACTIVITY_CAUTION)
  ) {
    return '강한 바람과 비가 예상되니, 외출해야 한다면 우산 대신 후드가 있는 방수 겉옷을 준비하세요.';
  }
  if (
    type === 'PARASOL' &&
    insightTypes.includes(LifestyleInsightType.OUTDOOR_ACTIVITY_CAUTION)
  ) {
    return '자외선과 강한 바람이 예상되니, 야외에 나간다면 양산 대신 모자를 준비하세요.';
  }
  if (
    type === 'OUTERWEAR' &&
    (insightTypes.includes(LifestyleInsightType.COOLER_THAN_TEMPERATURE) ||
      insightTypes.includes(LifestyleInsightType.OUTERWEAR_USEFUL))
  ) {
    return candidates[0];
  }
  return candidates[seed % candidates.length];
}
