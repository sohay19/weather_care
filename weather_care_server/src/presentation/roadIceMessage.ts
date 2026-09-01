import {
  LifestyleInsightType,
  RoadIceRisk,
  TodayWeatherResponse,
} from '../types';

export function buildRoadIceMessage(
  risk: RoadIceRisk | undefined,
  regionName: string,
): TodayWeatherResponse['lifestyleMessages'][number] | undefined {
  if (!risk) return undefined;
  const action = roadIceAction(risk.level);
  const fact = roadIceOfficialFact(risk, regionName);
  return {
    type: LifestyleInsightType.BLACK_ICE_CAUTION,
    title: action,
    description: fact,
    priority: 110 + risk.level,
    parts: [
      {
        role: 'APP_SUGGESTION',
        text: action,
        source: '날씨챙겨',
        validFrom: risk.producedAt,
      },
      {
        role: 'OFFICIAL_FACT',
        text: fact,
        source: risk.provider,
        validFrom: risk.producedAt,
      },
    ],
  };
}

export function roadIceNotification(
  risk: RoadIceRisk,
  regionName: string,
): { title: string; body: string } {
  const action = roadIceAction(risk.level);
  return {
    title: '블랙아이스(도로살얼음)',
    body: `${action} ${roadIceOfficialFact(risk, regionName)}`,
  };
}

function roadIceAction(level: RoadIceRisk['level']): string {
  if (level === 1) {
    return '블랙아이스가 생길 수 있으니, 운전한다면 출발 전에 최신 도로정보를 확인하세요';
  }
  if (level === 2) {
    return '블랙아이스가 생길 수 있으니, 해당 구간에서는 속도를 줄이고 충분한 안전거리를 두세요';
  }
  return '블랙아이스가 생길 위험이 있으니, 해당 구간에서는 제한속도보다 20~50% 감속하고 안전거리를 평소의 2배 이상 두세요';
}

function roadIceOfficialFact(
  risk: RoadIceRisk,
  regionName: string,
): string {
  return `기상청은 ${formatHour(risk.producedAt)} ${risk.roadName} ${regionName} 인근 구간의 블랙아이스(도로살얼음) 발생 가능성을 ${risk.levelLabel} ${risk.level}단계로 안내했어요`;
}

function formatHour(iso: string): string {
  const date = new Date(iso);
  const hour = Number(
    new Intl.DateTimeFormat('en-US', {
      timeZone: 'Asia/Seoul',
      hour: '2-digit',
      hourCycle: 'h23',
    }).format(date),
  );
  const period = hour < 12 ? '오전' : '오후';
  return `${period} ${hour % 12 || 12}시`;
}
