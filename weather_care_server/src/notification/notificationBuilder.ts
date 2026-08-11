import { Recommendation } from '../types';

export interface BuiltNotification {
  notification_key: string;
  title: string;
  body: string;
}

export function buildNotification(recommendations: Recommendation[]): BuiltNotification[] {
  const important = recommendations.filter((r) => r.type === 'HEAVY_SNOW_CAUTION');
  const normal = recommendations.filter((r) => r.type !== 'HEAVY_SNOW_CAUTION');

  const payloads: BuiltNotification[] = [];
  if (normal.length > 0) {
    payloads.push({
      notification_key: 'MORNING_BRIEF',
      title: `${normal.map((r) => r.title).join(' · ')} 챙겨요`,
      body: composeBody(normal),
    });
  }
  for (const item of important) {
    payloads.push({
      notification_key: `IMPORTANT_${item.type}`,
      title: `${item.title} 알림`,
      body: `${item.description} 이동할 때 주의하세요.`,
    });
  }
  return payloads;
}

function composeBody(items: Recommendation[]): string {
  if (items.length === 0) {
    return '오늘은 특별히 챙길 준비물이 적습니다.';
  }
  const labels = items.map((item) => item.title);
  return `오후·저녁 예상 조건이 바뀔 수 있습니다. ${labels.join(' · ')}가 필요할 수 있어요.`;
}

