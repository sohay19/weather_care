import { Recommendation } from '../types';
import { periodLabel, otherDatePrefix } from '../rules/precipitationWindows';
import {
  morningBriefDestination,
  NotificationDestination,
  recommendationDestination,
} from './notificationDestination';

export interface BuiltNotification {
  notification_key: string;
  title: string;
  body: string;
  destination: NotificationDestination;
}

export function buildNotification(recommendations: Recommendation[], now?: Date): BuiltNotification[] {
  recommendations = recommendations.filter((item) => !now || !item.validUntil ||
    Date.parse(item.validUntil) >= now.getTime());
  const important = recommendations.filter((r) => r.type === 'HEAVY_SNOW_CAUTION');
  const normal = recommendations.filter((r) => r.type !== 'HEAVY_SNOW_CAUTION');

  const payloads: BuiltNotification[] = [];
  if (normal.length > 0) {
    payloads.push({
      notification_key: 'MORNING_BRIEF',
      title: '오늘 준비할 내용',
      body: composeBody(normal, now),
      destination: morningBriefDestination,
    });
  }
  for (const item of important) {
    payloads.push({
      notification_key: `IMPORTANT_${item.type}`,
      title: item.title,
      body: timedDescription(item, now),
      destination: recommendationDestination(item.type),
    });
  }
  return payloads;
}

function composeBody(items: Recommendation[], now?: Date): string {
  if (items.length === 0) {
    return '오늘은 특별히 챙길 준비물이 적습니다.';
  }
  return items
    .slice(0, 3)
    .map((item) => timedDescription(item, now))
    .join('\n');
}

function timedDescription(item: Recommendation, now?: Date): string {
  if (!['UMBRELLA', 'HEAVY_SNOW_CAUTION'].includes(item.type) || !item.validFrom || !item.validUntil) return item.description;
  const start = Date.parse(item.validFrom);
  const end = Date.parse(item.validUntil);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) return item.description;
  // Existing rules use inclusive second/millisecond ends. Round to the next hour.
  const exclusiveEnd = new Date(Math.ceil((end + 1) / 3_600_000) * 3_600_000).toISOString();
  return `${otherDatePrefix(item.validFrom, now?.toISOString())}${periodLabel(item.validFrom, exclusiveEnd)} · ${item.description}`;
}
