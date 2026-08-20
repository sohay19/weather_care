import { LifestyleInsightType } from '../types';

interface LifestyleMessageTemplate {
  title: string;
  description: string;
}

export const lifestyleMessageCatalog: Record<
  LifestyleInsightType,
  LifestyleMessageTemplate[]
> = {
  RAIN_GEAR_USEFUL: [
    { title: '비가 오기 전 준비해요', description: '외출 전 우산을 가방에 넣어두면 안심이에요.' },
    { title: '젖기 쉬운 시간대가 있어요', description: '비가 시작되기 전에 이동 일정을 한 번 확인하세요.' },
  ],
  STRONG_SUN_EXPOSURE: [
    { title: '낮 햇볕을 가볍게 피하세요', description: '그늘을 이용하고 오래 걷는 일정은 짧게 나눠요.' },
    { title: '한낮 외출은 준비가 필요해요', description: '양산과 선크림을 함께 챙기면 편안해요.' },
  ],
  OUTERWEAR_USEFUL: [
    { title: '가벼운 겉옷이 유용해요', description: '아침저녁 기온과 바람을 함께 고려했어요.' },
    { title: '벗어 들기 쉬운 옷이 좋아요', description: '시간대별 체감 차이에 유연하게 대응하세요.' },
  ],
  MASK_USEFUL: [
    { title: '외출 전 대기질을 확인해요', description: '민감하다면 마스크를 챙기는 편이 좋아요.' },
    { title: '오늘 공기는 조금 답답해요', description: '긴 야외활동은 줄이고 실내 공기도 살펴요.' },
  ],
  HYDRATION_IMPORTANT: [
    { title: '물을 가까이 두세요', description: '체감온도가 높은 시간에는 조금씩 자주 마셔요.' },
    { title: '갈증 전부터 수분을 보충해요', description: '이동이 긴 날은 작은 물병을 준비하세요.' },
  ],
  SUNSCREEN_USEFUL: [
    { title: '외출 전 선크림을 발라요', description: '자외선이 강한 시간대 전에 미리 준비하세요.' },
    { title: '햇볕 노출을 줄여요', description: '그늘과 선크림을 함께 활용하면 좋아요.' },
  ],
  SNOW_TRAVEL_CAUTION: [
    { title: '눈길 이동은 천천히', description: '미끄러운 구간을 고려해 평소보다 일찍 출발하세요.' },
    { title: '보행과 운전에 여유가 필요해요', description: '강설 시간대에는 속도를 낮추고 안전거리를 둬요.' },
  ],
  LAUNDRY_GOOD: [
    { title: '빨래는 오전에 끝내요', description: '습도와 강수 가능성이 낮은 시간대를 이용하세요.' },
    { title: '건조하기 무난한 날이에요', description: '바람이 강해지기 전 빨래를 단단히 고정하세요.' },
  ],
  VERY_HOT_AND_HUMID: [
    { title: '땀이 쉽게 나는 날이에요', description: '한낮 활동을 줄이고 시원한 곳에서 쉬어가세요.' },
    { title: '몸이 더 덥게 느낄 수 있어요', description: '얇고 통풍이 잘되는 옷이 편안해요.' },
  ],
  COOLER_THAN_TEMPERATURE: [
    { title: '숫자보다 서늘하게 느껴져요', description: '바람 때문에 체감온도가 더 낮을 수 있어요.' },
    { title: '바람을 막을 옷이 좋아요', description: '얇은 겉옷을 쉽게 꺼낼 수 있게 준비하세요.' },
  ],
  LARGE_TEMPERATURE_SWING: [
    { title: '하루 기온 차가 커요', description: '여러 겹으로 입어 시간대별로 조절하세요.' },
    { title: '아침과 낮의 옷차림이 달라요', description: '벗기 쉬운 겉옷이 실용적이에요.' },
  ],
  OUTDOOR_ACTIVITY_CAUTION: [
    { title: '야외활동은 짧게 나눠요', description: '불편한 시간대를 피하고 중간중간 쉬어가세요.' },
    { title: '산책 시간을 옮겨보세요', description: '덜 덥고 바람이 잔잔한 시간대가 편안해요.' },
  ],
  VENTILATION_GOOD: [
    { title: '환기하기 무난한 시간이에요', description: '대기질이 좋은 시간에 10분 정도 창문을 열어요.' },
    { title: '실내 공기를 바꿔주세요', description: '비와 강한 바람이 없는 시간에 짧게 환기해요.' },
  ],
};

export function lifestyleMessageFor(
  type: LifestyleInsightType,
  seed = 0,
): LifestyleMessageTemplate {
  const candidates = lifestyleMessageCatalog[type];
  return candidates[Math.abs(seed) % candidates.length];
}
