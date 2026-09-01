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
    {
      title: '비가 올 수 있으니, 외출한다면 우산을 챙기세요',
      description: '우산이 없으면 옷이나 신발이 젖을 수 있어요.',
    },
    {
      title: '비가 예상되니, 나가기 전에 우산을 준비하세요',
      description: '비가 오는 시간에는 이동이 불편할 수 있어요.',
    },
    {
      title: '비가 내릴 수 있으니, 외출할 계획이라면 우산을 챙기세요',
      description: '강수 시간에 우산이 없으면 옷이나 신발이 젖을 수 있어요.',
    },
  ],
  STRONG_SUN_EXPOSURE: [
    {
      title: '자외선과 더위가 강할 수 있으니, 그늘이 적은 야외에 나간다면 양산이나 모자를 준비하세요',
      description: '양산이나 모자는 직사광선을 가리는 데 도움이 될 수 있어요.',
    },
  ],
  OUTERWEAR_USEFUL: [
    {
      title: '기온이 낮거나 바람이 강할 수 있으니, 외출한다면 겉옷을 준비하세요',
      description: '실외에서는 예보기온보다 예상 체감온도가 낮을 수 있어요.',
    },
    {
      title: '예상 체감온도가 낮을 수 있으니, 외출 전에 겉옷을 챙기세요',
      description: '바람이 불면 몸에서 열이 더 빠르게 빠져나갈 수 있어요.',
    },
    {
      title: '시간대별 기온 차가 클 수 있으니, 벗어 들기 쉬운 겉옷을 준비하세요',
      description: '앞뒤 시간의 예상 체감온도에 차이가 날 수 있어요.',
    },
  ],
  MASK_USEFUL: [
    {
      title: '미세먼지나 초미세먼지가 나쁠 수 있으니, 외출한다면 보건용 마스크를 준비하세요',
      description: '대기질 등급은 몸의 느낌만으로 판단하기 어려울 수 있어요.',
    },
  ],
  OZONE_CAUTION: [
    {
      title: '오존 농도가 높으니, 야외활동을 계획한다면 시간이나 강도를 줄이세요',
      description: '오존 농도는 몸으로 느끼기 어려울 수 있어요.',
    },
    {
      title: '오존 농도가 높으니, 야외활동을 한다면 오래 머무르지 마세요',
      description: '숨 쉴 때 답답하거나 아프지 않아도 오존 농도는 높을 수 있어요.',
    },
    {
      title: '오존 농도가 높으니, 외출한다면 최신 오존 측정값을 확인하세요',
      description: '눈이나 목이 불편하지 않아도 오존 농도는 높을 수 있어요.',
    },
  ],
  HYDRATION_IMPORTANT: [
    {
      title: '더운 시간에 외출한다면 물을 미리 준비하세요',
      description: '실외활동 중 온열질환이 발생할 수 있어요.',
    },
  ],
  SUNSCREEN_USEFUL: [
    {
      title: '자외선이 강할 수 있으니, 외출한다면 자외선 차단제를 준비하세요',
      description: '자외선 강도는 몸으로 바로 느끼기 어려울 수 있어요.',
    },
  ],
  SNOW_TRAVEL_CAUTION: [
    {
      title: '눈이 내릴 수 있으니, 외출 전에 도로 통제와 대중교통 운행정보를 확인하세요',
      description: '눈이 쌓이면 도로 이동이 어려워질 수 있어요.',
    },
  ],
  VERY_HOT_AND_HUMID: [
    {
      title: '더운 시간에 외출한다면 물을 준비하고 중간에 쉬세요',
      description: '후텁지근하게 느껴질 수 있어요.',
    },
    {
      title: '실외활동을 계획한다면 시간이나 강도를 줄이세요',
      description: '더운 공기와 습함이 느껴질 수 있어요.',
    },
    {
      title: '가능하다면 더위가 덜한 시간대로 활동을 옮기세요',
      description: '덥고 습하다고 느낄 수도 있어요.',
    },
  ],
  COOLER_THAN_TEMPERATURE: [
    {
      title: '바람이 강할 수 있으니, 외출한다면 겉옷을 준비하세요',
      description: '예보기온보다 예상 체감온도가 낮을 수 있어요.',
    },
    {
      title: '예상 체감온도가 낮을 수 있으니, 외출한다면 모자나 목도리를 준비하세요',
      description: '바람이 불면 몸에서 열이 더 빠르게 빠져나갈 수 있어요.',
    },
    {
      title: '기온과 바람을 확인하고 외출할 옷을 준비하세요',
      description: '예보기온과 예상 체감온도에 차이가 날 수 있어요.',
    },
  ],
  LARGE_TEMPERATURE_SWING: [
    {
      title: '시간대별 기온 차가 클 수 있으니, 벗어 들기 쉬운 겉옷을 준비하세요',
      description: '아침과 낮의 옷차림이 달라질 수 있어요.',
    },
  ],
  OUTDOOR_ACTIVITY_CAUTION: [
    {
      title: '바람이 강할 수 있으니, 야외활동을 계획한다면 소지품을 단단히 고정하세요',
      description: '강한 바람에 우산이나 양산을 다루기 어려울 수 있어요.',
    },
  ],
  RAIN_BREAK_WINDOW: [
    {
      title: '외출을 계획한다면 앞뒤 시간의 강수예보를 확인하세요',
      description: '{{validFrom}}부터 {{validTo}}까지 비가 잠시 그칠 수 있어요.',
    },
  ],
  BEST_OUTING_WINDOW: [
    {
      title: '외출을 계획한다면 {{timeLabel}}가 상대적으로 부담이 적을 수 있어요',
      description: '비·체감온도·자외선·대기질을 함께 비교했어요.',
    },
  ],
  PET_WALK_WINDOW: [
    {
      title: '반려견과 산책할 계획이라면 {{timeLabel}}로 옮길 수 있어요',
      description: '다른 시간대보다 외부 날씨 부담이 적을 수 있어요.',
    },
  ],
  WET_ROAD_CAUTION: [
    {
      title: '비가 그친 뒤 보행하거나 운전한다면 미끄러운 구간을 조심하세요',
      description: '도로가 젖어 있을 수 있어요.',
    },
  ],
  LAUNDRY_PICKUP_DUE: [
    {
      title: '비가 올 수 있으니, 실외 빨래가 있다면 {{actionDeadline}} 전에 실내로 들여놓으세요',
      description: '빗물에 빨래가 젖을 수 있어요.',
      contextKey: 'RAIN',
    },
    {
      title: '눈이 내릴 수 있으니, 실외 빨래가 있다면 {{actionDeadline}} 전에 실내로 들여놓으세요',
      description: '눈이 내려 빨래가 젖을 수 있어요.',
      contextKey: 'SNOW',
    },
    {
      title: '바람이 강할 수 있으니, 실외 빨래가 있다면 {{actionDeadline}} 전에 실내로 들여놓으세요',
      description: '빨래가 날리거나 떨어질 수 있어요.',
      contextKey: 'WIND',
    },
  ],
  WINDOW_CLOSE_SOON: [
    {
      title: '비가 올 수 있으니, 열린 창문이 있다면 {{actionDeadline}} 전에 닫으세요',
      description: '창문으로 빗물이 들어올 수 있어요.',
      contextKey: 'RAIN',
    },
    {
      title: '눈이 내릴 수 있으니, 열린 창문이 있다면 {{actionDeadline}} 전에 닫으세요',
      description: '창문 안쪽으로 눈이 들어올 수 있어요.',
      contextKey: 'SNOW',
    },
    {
      title: '바람이 강할 수 있으니, 열린 창문이 있다면 {{actionDeadline}} 전에 닫으세요',
      description: '바람에 창문이나 주변 물건이 흔들릴 수 있어요.',
      contextKey: 'WIND',
    },
  ],
  RAPID_TEMPERATURE_DROP: [
    {
      title: '기온이 빠르게 내려갈 수 있으니, 외출한다면 겉옷을 준비하세요',
      description: '뒤 시간에는 예보기온이 지금보다 낮아질 수 있어요.',
    },
  ],
  NIGHT_WEATHER_CHECK: [
    {
      title: '오늘 밤 기온과 습도가 높게 예보됐으니, 잠들기 전에 침실 상태를 확인하고 필요하면 냉방이나 제습으로 조절하세요',
      description: '',
    },
  ],
  BLACK_ICE_CAUTION: [
    {
      title: '블랙아이스가 생길 수 있으니, 운전한다면 출발 전에 최신 도로정보를 확인하세요',
      description: '기상청 도로살얼음 발생 가능 정보를 확인했어요.',
    },
  ],
  COMMUTE_ROUTE_CAUTION: [
    {
      title: '도로 통제가 시행 중이니, 출발 전에 다른 경로와 대중교통 운행정보를 확인하세요',
      description: '국가교통정보센터의 현재 돌발상황정보를 확인했어요.',
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
      title: '날씨 자료를 확인하기 어려워요',
      description: '최신 시간별 예보를 다시 확인하세요.',
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
