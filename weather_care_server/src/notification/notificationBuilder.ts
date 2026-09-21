import { Recommendation } from '../types';
import { periodLabel, otherDatePrefix } from '../rules/precipitationWindows';
import {
  morningBriefDestination,
  NotificationDestination,
  recommendationDestination,
} from './notificationDestination';
import type { WeatherForecast } from '../providers/weather/weatherProvider';

export interface BuiltNotification {
  notification_key: string;
  title: string;
  body: string;
  destination: NotificationDestination;
}

export function buildNotification(
  recommendations: Recommendation[],
  now?: Date,
  forecast?: WeatherForecast,
): BuiltNotification[] {
  recommendations = recommendations.filter((item) => !now || !item.validUntil ||
    Date.parse(item.validUntil) >= now.getTime());
  const important = recommendations.filter((r) => r.type === 'HEAVY_SNOW_CAUTION');
  const normal = recommendations.filter((r) => r.type !== 'HEAVY_SNOW_CAUTION');
  const weatherContext = qualitativeWeatherContext(forecast, now);

  const payloads: BuiltNotification[] = [];
  if (normal.length > 0 || weatherContext.length > 0) {
    payloads.push({
      notification_key: 'MORNING_BRIEF',
      title: normal.length > 0 ? '오늘 준비할 내용' : '오늘 날씨 안내',
      body: composeBody(normal, now, weatherContext),
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

function composeBody(
  items: Recommendation[],
  now: Date | undefined,
  weatherContext: string[],
): string {
  const recommendationLines = items.map((item) => timedDescription(item, now));
  const [visibility, ...otherContext] = weatherContext;
  return [
    visibility,
    ...recommendationLines,
    ...otherContext,
  ]
    .filter((line): line is string => line !== undefined)
    .slice(0, 3)
    .join('\n');
}

function qualitativeWeatherContext(
  forecast: WeatherForecast | undefined,
  now: Date | undefined,
): string[] {
  if (!forecast) return [];
  const messages: string[] = [];
  const visibility = forecast.current.visibilityMeters;
  if (visibility !== undefined && visibility < 200) {
    messages.push(
      '앞이 매우 잘 보이지 않을 수 있어요. 운전한다면 속도를 줄이고 차간 거리를 넉넉히 두세요.',
    );
  } else if (visibility !== undefined && visibility < 1_000) {
    messages.push(
      '시야가 짧아 앞이 흐리게 보일 수 있어요. 운전할 때는 감속하고 주변을 살펴주세요.',
    );
  }

  const reference = now?.getTime();
  const relevantHourly = forecast.hourly.filter((item) => {
    if (reference === undefined) return true;
    const point = Date.parse(item.forecastAt ?? item.observedAt);
    return Number.isFinite(point) && point >= reference &&
      point < reference + 24 * 60 * 60 * 1_000;
  });
  const snapshots = [forecast.current, ...relevantHourly.slice(0, 24)];
  const humid = snapshots.find((item) => (item.humidity ?? -1) >= 80);
  if (humid) {
    messages.push(
      (humid.temperature ?? 0) >= 25
        ? '공기가 후텁지근하고 땀이 잘 마르지 않을 수 있어요.'
        : '실외 공기가 눅눅하게 느껴지고 빨래가 더디게 마를 수 있어요.',
    );
  } else if (snapshots.some((item) => (item.humidity ?? 101) <= 35)) {
    messages.push('실외 공기가 건조해 코나 목이 마르게 느껴질 수 있어요.');
  }
  return messages;
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
