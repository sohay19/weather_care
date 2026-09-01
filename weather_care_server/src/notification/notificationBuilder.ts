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
      title: '오늘 준비할 내용',
      body: composeBody(normal),
    });
  }
  for (const item of important) {
    payloads.push({
      notification_key: `IMPORTANT_${item.type}`,
      title: item.title,
      body: item.description,
    });
  }
  return payloads;
}

function composeBody(items: Recommendation[]): string {
  if (items.length === 0) {
    return '오늘은 특별히 챙길 준비물이 적습니다.';
  }
  return items
    .slice(0, 3)
    .map((item) => item.description)
    .join(' ');
}
