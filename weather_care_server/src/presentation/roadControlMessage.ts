import {
  LifestyleInsightType,
  OfficialRoadControl,
  TodayWeatherResponse,
} from '../types';

export function buildRoadControlMessage(
  control: OfficialRoadControl | undefined,
): TodayWeatherResponse['lifestyleMessages'][number] | undefined {
  if (!control) return undefined;
  const action = roadControlAction(control);
  const fact = roadControlOfficialFact(control);
  return {
    type: LifestyleInsightType.COMMUTE_ROUTE_CAUTION,
    title: action,
    description: fact,
    priority: control.controlKind === 'FULL' ? 130 : 120,
    parts: [
      {
        role: 'APP_SUGGESTION',
        text: action,
        source: '날씨챙겨',
        validFrom: control.startedAt,
        validUntil: control.endsAt,
      },
      {
        role: 'OFFICIAL_FACT',
        text: fact,
        source: control.provider,
        validFrom: control.startedAt,
        validUntil: control.endsAt,
      },
    ],
  };
}

export function roadControlNotification(
  control: OfficialRoadControl,
): { title: string; body: string } {
  return {
    title: '출퇴근 경로',
    body: `${roadControlAction(control)}\n${roadControlOfficialFact(control)}`,
  };
}

function roadControlAction(control: OfficialRoadControl): string {
  const road = roadLabel(control);
  if (control.controlKind === 'FULL') {
    return `${road} 전면 통제가 시행 중이니, 출발 전에 다른 경로와 대중교통 운행정보를 확인하세요`;
  }
  return `${road} 일부 차로가 통제 중이니, 출발 전에 교통정보를 확인하세요`;
}

function roadControlOfficialFact(control: OfficialRoadControl): string {
  const road = roadLabel(control);
  const kind = control.controlKind === 'FULL' ? '전면 통제' : '일부 차로 통제';
  return `국가교통정보센터는 ${formatDateHour(control.startedAt)}부터 ${road} ${kind}가 시행 중이라고 안내했어요`;
}

function roadLabel(control: OfficialRoadControl): string {
  const road = control.roadName || '도로';
  return control.direction ? `${road} ${control.direction}` : road;
}

function formatDateHour(iso: string): string {
  const date = new Date(iso);
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Seoul',
    month: 'numeric',
    day: 'numeric',
    hour: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    Number(parts.find((part) => part.type === type)?.value);
  const month = value('month');
  const day = value('day');
  const hour = value('hour');
  const hourLabel =
    hour === 0
      ? '0시'
      : hour < 12
        ? `오전 ${hour}시`
        : `오후 ${hour % 12 || 12}시`;
  return `${month}월 ${day}일 ${hourLabel}`;
}
