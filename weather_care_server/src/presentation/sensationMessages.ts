export type SensationTier =
  | 'HEAT_MILD'
  | 'HEAT_CLEAR'
  | 'HEAT_STRONG'
  | 'HOT_HUMID'
  | 'COLD_MILD_OUTDOOR'
  | 'COLD_COOL_AIR'
  | 'COLD_CHILLY'
  | 'COLD_STRONG'
  | 'COLD_EXPOSED_STING'
  | 'UV_DIRECT_PERCEPTION'
  | 'PARASOL_GLARE_REDUCTION'
  | 'PARASOL_HEAT_REDUCTION'
  | 'PM_DIRECT_PERCEPTION'
  | 'OZONE_DIRECT_PERCEPTION';

export const sensationMessageCatalog: Record<
  SensationTier,
  readonly [string, string, string]
> = {
  HEAT_MILD: [
    '조금 덥게 느껴질 수 있어요.',
    '살짝 더운 느낌이 들 수 있어요.',
    '약한 더위를 느낄 수도 있어요.',
  ],
  HEAT_CLEAR: [
    '덥게 느껴질 수 있어요.',
    '뚜렷한 더위를 느낄 수도 있어요.',
    '제법 덥다고 느낄 수도 있어요.',
  ],
  HEAT_STRONG: [
    '많이 덥게 느껴질 수 있어요.',
    '강한 더위를 느낄 수도 있어요.',
    '열기가 강하다는 느낌이 들 수 있어요.',
  ],
  HOT_HUMID: [
    '후텁지근하게 느껴질 수 있어요.',
    '더운 공기와 습함이 느껴질 수 있어요.',
    '덥고 습하다고 느낄 수도 있어요.',
  ],
  COLD_MILD_OUTDOOR: [
    '선선하게 느껴질 수 있어요.',
    '바깥 공기가 살짝 차갑다는 느낌이 들 수 있어요.',
    '약한 찬 기운을 느낄 수도 있어요.',
  ],
  COLD_COOL_AIR: [
    '공기가 서늘하게 느껴질 수 있어요.',
    '그늘에서는 공기의 찬 기운을 느낄 수도 있어요.',
    '해가 진 뒤에는 공기가 차갑다고 느낄 수도 있어요.',
  ],
  COLD_CHILLY: [
    '쌀쌀하게 느껴질 수 있어요.',
    '바깥 공기에서 뚜렷한 찬 기운을 느낄 수도 있어요.',
    '가만히 있으면 조금 춥다고 느낄 수도 있어요.',
  ],
  COLD_STRONG: [
    '꽤 춥다고 느낄 수도 있어요.',
    '실외에서는 강한 추위를 느낄 수도 있어요.',
    '몸 전체에 강한 찬 기운이 느껴질 수 있어요.',
  ],
  COLD_EXPOSED_STING: [
    '찬 바람에 손끝이나 귀가 시리다고 느낄 수도 있어요.',
    '손이나 귀가 바람에 노출되면 시린 느낌이 들 수 있어요.',
    '노출된 손끝이나 귀가 찬 바람에 얼얼하게 느껴질 수 있어요.',
  ],
  UV_DIRECT_PERCEPTION: [
    '자외선 강도는 몸으로 바로 느끼기 어려울 수 있어요.',
    '자외선은 햇볕의 뜨거움과 달라 몸으로 바로 느끼기 어려울 수 있어요.',
    '덥게 느껴지는 정도와 자외선 강도는 다를 수 있어요.',
  ],
  PARASOL_GLARE_REDUCTION: [
    '양산을 쓰면 햇빛이 덜 눈부시게 느껴질 수 있어요.',
    '양산의 그늘로 눈부심이 줄어 한결 편안할 수 있어요.',
    '양산을 이용해 눈의 부담을 줄일 수도 있어요.',
  ],
  PARASOL_HEAT_REDUCTION: [
    '양산을 쓰면 햇볕의 뜨거움이 덜하게 느껴질 수 있어요.',
    '양산으로 직사광선을 가리면 피부에 닿는 열감이 줄어든 느낌이 들 수 있어요.',
    '양산 아래가 좀 더 시원하다고 느낄 수도 있어요.',
  ],
  PM_DIRECT_PERCEPTION: [
    '미세먼지와 초미세먼지 농도는 몸으로 바로 느끼기 어려울 수 있어요.',
    '하늘이 맑아 보여도 미세먼지나 초미세먼지 농도는 높을 수 있어요.',
    '공기가 텁텁하지 않아도 미세먼지나 초미세먼지 농도는 높을 수 있어요.',
  ],
  OZONE_DIRECT_PERCEPTION: [
    '오존 농도는 몸으로 느끼기 어려울 수 있어요.',
    '숨 쉴 때 답답하거나 아프지 않아도 오존 농도는 높을 수 있어요.',
    '눈이나 목이 불편하지 않아도 오존 농도는 높을 수 있어요.',
  ],
};

export function sensationMessage(tier: SensationTier, seed: number): string {
  const messages = sensationMessageCatalog[tier];
  return messages[Math.abs(Math.trunc(seed)) % messages.length];
}

export function parasolBenefitMessage(seed: number): string {
  const messages = [
    ...sensationMessageCatalog.PARASOL_GLARE_REDUCTION,
    ...sensationMessageCatalog.PARASOL_HEAT_REDUCTION,
  ];
  return messages[Math.abs(Math.trunc(seed)) % messages.length];
}
