import { LifestyleInsightType, RecommendationType } from '../types';

export const CATALOG_VERSION = 'ko-KR-2026.09.3';

export const recommendationMessageCatalog: Record<RecommendationType, string[]> = {
  UMBRELLA: [
    '비가 올 수 있으니, 외출한다면 우산을 챙기세요.',
    '비가 예상되니, 나가기 전에 우산을 준비하세요.',
    '비가 내릴 수 있으니, 외출할 계획이라면 우산을 챙기세요.',
  ],
  RAINCOAT: [
    '비와 바람에 대비해 외출 전에 우비를 준비하세요.',
    '비가 예상되니 두 손을 자유롭게 쓸 수 있는 우비를 챙기세요.',
    '비가 내릴 수 있으니 이동할 계획이라면 우비를 준비하세요.',
  ],
  RAIN_BOOTS: [
    '젖은 길을 걸을 수 있으니 장화를 준비하세요.',
    '비로 길에 물이 고일 수 있으니 장화를 챙기세요.',
    '비가 예상되니 발이 젖지 않도록 장화를 준비하세요.',
  ],
  PARASOL: [
    '자외선이 강할 수 있으니, 그늘이 적은 야외에 나간다면 양산을 준비하세요.',
    '자외선이 강할 수 있으니, 외출한다면 양산을 준비하세요.',
    '자외선이 강할 수 있으니, 야외에 나간다면 양산을 챙기세요.',
  ],
  SUNGLASSES: [
    '강한 햇빛에 대비해 자외선 차단 기능이 있는 선글라스를 챙기세요.',
    '눈부심이 클 수 있으니 외출한다면 선글라스를 준비하세요.',
    '자외선 노출이 예상되니 야외 활동 전에 선글라스를 챙기세요.',
  ],
  HEAVY_SNOW_CAUTION: [
    '눈이 많이 쌓일 수 있으니, 외출 전에 도로 통제와 대중교통 운행정보를 확인하세요.',
    '눈이 많이 내릴 수 있으니, 보행하거나 운전한다면 속도를 줄이세요.',
    '눈이 쌓일 수 있으니, 이동한다면 미끄러운 구간을 조심하세요.',
  ],
  OUTERWEAR: [
    '기온이 낮거나 바람이 강할 수 있으니, 외출한다면 두꺼운 겉옷을 준비하세요.',
    '예상 체감온도가 낮게 계산됐으니, 외출 전에 두꺼운 겉옷을 챙기세요.',
    '시간대별 기온 차가 클 수 있으니, 두꺼운 겉옷을 준비하세요.',
  ],
  SCARF: [
    '찬 공기에 대비해 목을 감쌀 수 있는 목도리를 준비하세요.',
    '예상 체감온도가 낮게 계산됐으니 목도리를 챙기세요.',
    '바람이 차갑게 느껴질 수 있으니 외출 전에 목도리를 준비하세요.',
  ],
  HAND_WARMER: [
    '추운 시간에 사용할 수 있도록 핫팩을 준비하세요.',
    '예상 체감온도가 낮게 계산됐으니 외출 전에 핫팩을 챙기세요.',
    '오래 밖에 머문다면 손을 따뜻하게 할 핫팩을 준비하세요.',
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
  PORTABLE_FAN: [
    '더운 시간에 대비해 휴대용 선풍기를 준비하세요.',
    '예상 체감온도가 높게 계산됐으니 휴대용 선풍기를 챙기세요.',
    '야외에서 더위를 식힐 수 있도록 휴대용 선풍기를 준비하세요.',
  ],
  COOLING_ITEM: [
    '덥고 습할 수 있으니 쿨링타월 같은 쿨링제품을 준비하세요.',
    '예상 체감온도가 높게 계산됐으니 쿨링제품을 챙기세요.',
    '더운 시간이 이어질 수 있으니 몸을 식힐 쿨링제품을 준비하세요.',
  ],
  SUNSCREEN: [
    '자외선이 강할 수 있으니, 외출한다면 자외선 차단제를 준비하세요.',
    '자외선지수가 높을 수 있으니, 야외에 나간다면 자외선 차단제를 챙기세요.',
    '자외선 노출이 커질 수 있으니, 외출 전에 자외선 차단제를 준비하세요.',
  ],
  SNOW_CHAINS: [
    '눈길 운전에 대비해 차량용 스노우체인을 준비하세요.',
    '도로에 눈이 쌓일 수 있으니 출발 전에 스노우체인을 확인하세요.',
    '눈길을 운전해야 한다면 차량에 맞는 스노우체인을 챙기세요.',
  ],
  POWER_BANK: [
    '눈으로 이동이 지연될 수 있으니 보조배터리를 준비하세요.',
    '추운 날 장시간 이동에 대비해 충전된 보조배터리를 챙기세요.',
    '비상 연락을 유지할 수 있도록 보조배터리를 준비하세요.',
  ],
  WINTER_BOOTS: [
    '눈길 보행에 대비해 미끄럼 방지 밑창이 있는 방한부츠를 준비하세요.',
    '눈이 쌓일 수 있으니 발을 따뜻하게 보호할 방한부츠를 챙기세요.',
    '미끄럽고 젖은 눈길에 대비해 방한부츠를 준비하세요.',
  ],
};

export function titleFor(type: RecommendationType): string {
  return {
    UMBRELLA: '우산',
    RAINCOAT: '우비',
    RAIN_BOOTS: '장화',
    PARASOL: '양산',
    SUNGLASSES: '선글라스',
    HEAVY_SNOW_CAUTION: '많은 눈 대비',
    OUTERWEAR: '두꺼운 겉옷',
    SCARF: '목도리',
    HAND_WARMER: '핫팩',
    MASK: '마스크',
    WATER: '물',
    PORTABLE_FAN: '휴대용 선풍기',
    COOLING_ITEM: '쿨링제품',
    SUNSCREEN: '선크림',
    SNOW_CHAINS: '스노우체인',
    POWER_BANK: '보조배터리',
    WINTER_BOOTS: '방한부츠',
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
    return '자외선과 강한 바람이 예상되니, 양산을 쓰기 어렵다면 선글라스와 선크림을 준비하세요.';
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
