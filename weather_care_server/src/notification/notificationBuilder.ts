import { Recommendation } from '../types';
import { periodLabel, otherDatePrefix } from '../rules/precipitationWindows';
import {
  morningBriefDestination,
  NotificationDestination,
  recommendationDestination,
} from './notificationDestination';
import type { WeatherForecast } from '../providers/weather/weatherProvider';
import { preparationsForWindow } from '../recommendations/preparationPolicy';
import { titleFor } from '../recommendations/recommendationTemplates';
import {
  buildWeatherBriefResult,
  type WeatherBriefContext,
} from '../presentation/weatherBrief';

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
  briefContext: Omit<WeatherBriefContext, 'now'> = {},
): BuiltNotification[] {
  recommendations = recommendations.filter((item) => !now || !item.validUntil ||
    Date.parse(item.validUntil) >= now.getTime());
  const important = recommendations.filter((r) => r.type === 'HEAVY_SNOW_CAUTION');
  const normal = recommendations.filter((r) => r.type !== 'HEAVY_SNOW_CAUTION');
  const briefing = forecast
    ? buildWeatherBriefResult(forecast, {
        ...briefContext,
        now,
        allowedRecommendedItems: normal.map((item) => item.type),
        severityRecommendedItems: normal
          .filter((item) => item.recommended)
          .map((item) => item.type),
      }).intent
    : undefined;
  const briefingMatchesPreferences = briefing !== undefined && (
    briefing.recommendedItems.length === 0
      ? briefing.sceneId !== 'DEFAULT'
      : normal.some((item) => briefing.recommendedItems.includes(item.type))
  );
  const summaryBriefing = briefingMatchesPreferences ? briefing : undefined;
  const fallbackItems = briefContext.tieredPreparations ? [] : normal;
  const preparations = forecast && briefContext.tieredPreparations
    ? preparationsForWindow(forecast, now ?? new Date(), briefContext)
    : [];
  const preparationBody = preparations.slice(0, 3).map((item) => {
    const time = item.validFrom && item.validUntil
      ? `${periodLabel(item.validFrom, item.validUntil)} ` : '';
    const reason = { rain: '비 대비', snow: '눈 대비', cold: '추위 대비',
      heat: '더위 대비', air: '미세먼지 대비', pollen: '꽃가루 대비',
      'air+pollen': '미세먼지·꽃가루 대비', uv: '자외선 대비' }[item.reason] ?? '';
    return `${time}${reason} · ${titleFor(item.type)}`;
  }).join('\n');

  const payloads: BuiltNotification[] = [];
  if (preparations.length > 0 || fallbackItems.length > 0 || summaryBriefing) {
    payloads.push({
      notification_key: 'MORNING_BRIEF',
      title: preparationBody ? '오늘 준비할 내용' : summaryBriefing?.copy.notificationTitle ?? '오늘 준비할 내용',
      body: preparationBody || summaryBriefing?.copy.notificationBody || composeBody(fallbackItems, now),
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
): string {
  return items.map((item) => timedDescription(item, now))
    .slice(0, 3)
    .join('\n');
}

function timedDescription(item: Recommendation, now?: Date): string {
  const timedTypes: Recommendation['type'][] = [
    'UMBRELLA',
    'RAINCOAT',
    'RAIN_BOOTS',
    'HEAVY_SNOW_CAUTION',
    'SNOW_CHAINS',
    'POWER_BANK',
    'WINTER_BOOTS',
  ];
  if (!timedTypes.includes(item.type) || !item.validFrom || !item.validUntil) return item.description;
  const start = Date.parse(item.validFrom);
  const end = Date.parse(item.validUntil);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) return item.description;
  // Existing rules use inclusive second/millisecond ends. Round to the next hour.
  const exclusiveEnd = new Date(Math.ceil((end + 1) / 3_600_000) * 3_600_000).toISOString();
  return `${otherDatePrefix(item.validFrom, now?.toISOString())}${periodLabel(item.validFrom, exclusiveEnd)} · ${item.description}`;
}
