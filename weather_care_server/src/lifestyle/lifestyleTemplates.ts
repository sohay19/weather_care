import { LifestyleInsightType } from '../types';

interface LifestyleMessageTemplate {
  title: string;
  description: string;
  contextKey?: string;
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
  COMMUTE_WEATHER_CHANGE: [
    {
      title: '출근할 때는 괜찮지만 퇴근 무렵 비가 와요',
      description: '우산을 미리 챙기세요.',
      contextKey: 'RAIN',
    },
    {
      title: '아침보다 저녁이 훨씬 쌀쌀해져요',
      description: '벗기 쉬운 겉옷이 좋아요.',
      contextKey: 'COLD',
    },
  ],
  RAIN_BREAK_WINDOW: [
    {
      title: '비가 잠시 쉬어가요',
      description: '{{validFrom}}부터 {{validTo}}까지 이동하기 좋아요.',
    },
    {
      title: '짧은 비 공백이 있어요',
      description: '급한 외출은 이 시간을 이용하세요.',
    },
  ],
  BEST_OUTING_WINDOW: [
    {
      title: '오늘 외출은 {{timeLabel}}가 가장 편안해요',
      description: '비·체감·대기질을 함께 고려했어요.',
    },
    {
      title: '야외 일정 시간을 옮겨보세요',
      description: '{{timeLabel}}가 상대적으로 무난해요.',
    },
  ],
  PET_WALK_WINDOW: [
    {
      title: '산책은 {{timeLabel}}가 좋아요',
      description: '더위와 자외선이 약해지는 시간이에요.',
    },
    {
      title: '비와 대기질을 피한 산책 시간',
      description: '{{timeLabel}}를 이용해보세요.',
    },
  ],
  COMMUTE_RISK: [
    {
      title: '이동에 평소보다 여유가 필요해요',
      description: '강수와 바람이 겹치는 시간대예요.',
      contextKey: 'RAIN_WIND',
    },
    {
      title: '미끄러운 구간이 있을 수 있어요',
      description: '속도를 낮추고 천천히 이동하세요.',
      contextKey: 'ICY',
    },
  ],
  WET_ROAD_CAUTION: [
    {
      title: '비는 그쳤지만 길이 젖어 있어요',
      description: '미끄러운 바닥을 조심하세요.',
    },
    {
      title: '눈·비가 남긴 젖은 구간이 있을 수 있어요',
      description: '서두르지 마세요.',
    },
  ],
  CAR_WASH_SCORE: [
    {
      title: '곧 비가 예상돼요',
      description: '오늘 세차는 미뤄도 좋아요.',
      contextKey: 'POSTPONE',
    },
    {
      title: '당분간 강수 가능성이 낮아요',
      description: '세차하기 무난해요.',
      contextKey: 'GOOD',
    },
  ],
  LAUNDRY_PICKUP_DUE: [
    {
      title: '{{actionDeadline}} 전에 빨래를 걷으세요',
      description: '이후 비가 예상돼요.',
    },
    {
      title: '바람이 강해지기 전에 빨래를 옮기세요',
      description: '단단히 고정하거나 안으로 들여요.',
    },
  ],
  INDOOR_DRYING_PREFERRED: [
    {
      title: '비와 높은 습도가 이어져요',
      description: '오늘은 실내 건조가 안전해요.',
    },
    {
      title: '야외 건조가 어려운 날이에요',
      description: '제습이나 환기 가능 시간을 함께 이용하세요.',
    },
  ],
  VENTILATION_WINDOW: [
    {
      title: '환기하기 무난해요',
      description: '지금부터 {{durationMinutes}}분 정도 환기하세요.',
    },
    {
      title: '실내 공기를 짧게 바꿔주세요',
      description: '{{validTo}} 전까지 환기하기 무난해요.',
    },
  ],
  WINDOW_CLOSE_SOON: [
    {
      title: '{{minutesUntil}}분 뒤 비와 바람이 예상돼요',
      description: '창문을 확인하세요.',
    },
    {
      title: '외출 전 창문을 확인해요',
      description: '열린 창문이 없는지 살펴보세요.',
    },
  ],
  DEHUMIDIFIER_USEFUL: [
    {
      title: '높은 습도가 밤까지 이어져요',
      description: '제습이 도움돼요.',
    },
    {
      title: '실내가 눅눅해지기 쉬워요',
      description: '짧은 환기나 제습을 이용하세요.',
    },
  ],
  HUMIDIFIER_USEFUL: [
    {
      title: '공기가 건조해요',
      description: '가습과 피부 보습을 챙겨요.',
    },
    {
      title: '건조한 바람이 이어져요',
      description: '물을 자주 마시고 실내 습도를 살펴요.',
    },
  ],
  UMBRELLA_DRYING_REMINDER: [
    {
      title: '비가 모두 그쳤어요',
      description: '젖은 우산을 펼쳐 말리세요.',
    },
    {
      title: '다음 비까지 시간이 있어요',
      description: '우산을 말려두면 좋아요.',
    },
  ],
  ALLERGY_CAUTION: [
    {
      title: '꽃가루가 많이 날릴 수 있어요',
      description: '민감하다면 마스크를 챙기세요.',
    },
    {
      title: '외출 후 꽃가루를 털어주세요',
      description: '옷과 머리를 가볍게 정리해요.',
    },
  ],
  RESPIRATORY_CAUTION: [
    {
      title: '미세먼지와 오존을 함께 확인하세요',
      description: '긴 야외활동은 줄이는 편이 좋아요.',
    },
    {
      title: '대기가 정체되는 시간이에요',
      description: '민감하다면 실외운동을 미루세요.',
    },
  ],
  SLEEP_DISCOMFORT_EXPECTED: [
    {
      title: '밤에도 덥고 습해요',
      description: '잠들기 전 실내 온습도를 조절하세요.',
    },
    {
      title: '새벽에 체감온도가 내려가요',
      description: '얇은 이불을 가까이 두세요.',
    },
  ],
  VEHICLE_FROST_RISK: [
    {
      title: '내일 아침 차량 유리에 성에가 생길 수 있어요',
      description: '출발 시간을 조금 여유 있게 잡으세요.',
    },
    {
      title: '밤사이 기온이 내려가요',
      description: '성에 제거 도구를 확인하세요.',
    },
  ],
  FREEZE_CAUTION: [
    {
      title: '새벽 동파 위험이 있어요',
      description: '노출된 수도관을 확인하세요.',
    },
    {
      title: '한파 시간대가 이어져요',
      description: '외부 수도와 계량기를 살펴주세요.',
    },
  ],
  RAPID_TEMPERATURE_DROP: [
    {
      title: '저녁부터 기온이 빠르게 내려가요',
      description: '가벼운 겉옷을 미리 챙기세요.',
    },
    {
      title: '낮과 밤의 체감 차이가 커요',
      description: '여러 겹으로 입는 편이 좋아요.',
    },
  ],
  DAILY_WEATHER_CHECK: [
    {
      title: '시간대별 흐름 확인하기',
      description: '외출 전 오늘의 변화를 한 번 살펴보세요.',
    },
  ],
  DAILY_HYDRATION: [
    {
      title: '물 한 모금 챙기기',
      description: '하루 틈틈이 가볍게 수분을 채워요.',
    },
  ],
  FLEXIBLE_DAY_PLAN: [
    {
      title: '여유 있게 움직이기',
      description: '오늘의 흐름에 맞춰 천천히 시작해요.',
    },
  ],
};

export function lifestyleMessageFor(
  type: LifestyleInsightType,
  seed = 0,
  context: Record<string, unknown> = {},
): LifestyleMessageTemplate {
  const candidates = lifestyleMessageCatalog[type];
  const contextKey = context.messageContext?.toString();
  const contextCandidates = contextKey
    ? candidates.filter((candidate) => candidate.contextKey === contextKey)
    : [];
  const preferred =
    contextCandidates.length > 0
      ? contextCandidates
      : candidates.filter((candidate) => candidate.contextKey === undefined);
  const renderable = preferred.filter((candidate) =>
    placeholders(`${candidate.title} ${candidate.description}`).every(
      (placeholder) => context[placeholder] !== undefined,
    ),
  );
  const safeFallback = candidates.filter(
    (candidate) =>
      candidate.contextKey === undefined &&
      placeholders(`${candidate.title} ${candidate.description}`).length === 0,
  );
  const eligible = renderable.length > 0 ? renderable : safeFallback;
  if (eligible.length === 0) {
    return {
      title: '날씨 정보를 확인해요',
      description: '추천 시간은 상세 날씨에서 다시 확인하세요.',
    };
  }
  const selected = eligible[Math.abs(seed) % eligible.length];
  return {
    title: renderTemplate(selected.title, context),
    description: renderTemplate(selected.description, context),
  };
}

function placeholders(template: string): string[] {
  return [...template.matchAll(/{{([a-zA-Z0-9]+)}}/g)].map(
    (match) => match[1],
  );
}

function renderTemplate(
  template: string,
  context: Record<string, unknown>,
): string {
  return template.replace(/{{([a-zA-Z0-9]+)}}/g, (_, key: string) =>
    context[key]?.toString() ?? '',
  );
}
