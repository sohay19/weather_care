import { Recommendation } from '../types';
import { koreanHour, periodLabel, otherDatePrefix } from '../rules/precipitationWindows';
import {
  morningBriefDestination,
  NotificationDestination,
  recommendationDestination,
} from './notificationDestination';
import type { WeatherForecast } from '../providers/weather/weatherProvider';
import { preparationsForSnapshots, preparationsForWindow, type PreparationCandidate } from '../recommendations/preparationPolicy';
import { isDrynessPreparation } from '../rules/dryness';
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
  const settings = briefContext.todayNotificationSettings;
  const carryEnabled = settings?.dailyWeatherEnabled !== false && settings?.carryNotificationEnabled !== false;
  const todayEnabled = settings?.dailyWeatherEnabled !== false && settings?.todayNotificationEnabled !== false;
  const context = {
    ...briefContext,
    todayNotificationSettings: todayEnabled ? settings : {
      ...settings,
      todayVisibilityEnabled: false, todayOzoneEnabled: false, todayWindEnabled: false,
      todayHumidityEnabled: false, todayApparentTemperatureEnabled: false,
    },
  };
  recommendations = recommendations.filter((item) => !now || !item.validUntil ||
    Date.parse(item.validUntil) >= now.getTime());
  const important = recommendations.filter((r) => r.type === 'HEAVY_SNOW_CAUTION');
  const normal = recommendations.filter((r) => r.type !== 'HEAVY_SNOW_CAUTION');
  const briefing = forecast
    ? buildWeatherBriefResult(forecast, {
        ...context,
        now,
        allowedRecommendedItems: carryEnabled ? [
          ...normal.map((item) => item.type),
          ...(briefContext.drynessPreparations
            ? briefContext.allowedRecommendedItems?.filter(isDrynessPreparation) ?? [] : []),
        ] : [],
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
  const summaryBriefing = briefingMatchesPreferences &&
    (briefing!.recommendedItems.length > 0 ? carryEnabled : todayEnabled) ? briefing : undefined;
  const fallbackItems = carryEnabled && !briefContext.tieredPreparations ? normal : [];
  const preparations = carryEnabled && forecast && briefContext.tieredPreparations
    ? preparationsForWindow(forecast, now ?? new Date(), briefContext)
    : [];
  const preparationBody = forecast
    ? preparationMessage(preparations.slice(0, 3), forecast, now ?? new Date(), briefContext)
    : '';

  const payloads: BuiltNotification[] = [];
  if (preparations.length > 0 || fallbackItems.length > 0 || summaryBriefing) {
    payloads.push({
      notification_key: 'MORNING_BRIEF',
      title: '오늘자 준비물 😊',
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

function preparationMessage(
  items: PreparationCandidate[],
  forecast: WeatherForecast,
  now: Date,
  context: Omit<WeatherBriefContext, 'now'>,
): string {
  const groups: PreparationCandidate[][] = [];
  for (const item of items) {
    const group = groups.find(([first]) => first.reason === item.reason &&
      first.validFrom === item.validFrom && first.validUntil === item.validUntil);
    if (group) group.push(item);
    else groups.push([item]);
  }
  return groups.map((group, index) => {
    const item = group[0];
    let time = '오늘은 ';
    if (item.validFrom && item.validUntil) {
      const end = new Date(now.getTime() + 9 * 3_600_000);
      end.setUTCHours(24, 0, 0, 0);
      const midnight = end.getTime() - 9 * 3_600_000;
      // 시작·종료 사이에 자료가 없거나 조건이 풀린 구간이 있으면 종일로 표현하지 않는다.
      const periods = [forecast.current, ...forecast.hourly].flatMap((snapshot) =>
        preparationsForSnapshots([snapshot], { now, end: midnight, ...context, includeSnowUmbrella: true })
          .filter((candidate) => candidate.type === item.type)
          .map((candidate) => [Date.parse(candidate.validFrom!), Date.parse(candidate.validUntil!)]))
        .sort((left, right) => left[0] - right[0]);
      let coveredUntil = now.getTime();
      for (const [start, finish] of periods) {
        if (start > coveredUntil) break;
        coveredUntil = Math.max(coveredUntil, finish);
      }
      const hour = new Date(now.getTime() + 9 * 3_600_000).getUTCHours();
      time = coveredUntil >= midnight && hour <= 9 ? '오늘은 하루 종일 '
        : coveredUntil >= midnight ? '지금부터 밤까지 '
        : `${koreanHour(item.validFrom)}~${Date.parse(item.validUntil) === midnight
          ? '밤 12시' : koreanHour(item.validUntil)}${item.reason === 'rain'
          ? '에는 ' : item.reason === 'uv' ? '까지 ' : '까지는 '}`;
    }
    const names = group.map((candidate) => titleFor(candidate.type)).join(', ');
    const object = names + ((names.charCodeAt(names.length - 1) - 0xac00) % 28 === 0 ? '를' : '을');
    switch (item.reason) {
      case 'cold':
        return `${time}쌀쌀해요. ${object} ${group.every((candidate) =>
          candidate.type === 'OUTERWEAR' || candidate.type === 'LIGHT_OUTERWEAR')
          ? groups[index + 1]?.[0].reason === 'uv' ? '챙겨 입고,' : '챙겨 입으세요.'
          : '챙겨 따뜻하게 다니세요.'}`;
      case 'rain': return `${time}비 소식이 있어요. ${object} 챙겨 나가세요.`;
      case 'snow': return `${time}눈 소식이 있어요. ${names} 준비하여 미끄러지지 않도록 조심하세요.`;
      case 'heat': return `${time}더위에 대비해요. ${object} 챙기고 틈틈이 쉬어 가세요.`;
      case 'air': return `${time}미세먼지가 심하니 ${object} 챙겨 쓰세요.`;
      case 'pollen': return `${time}꽃가루에 대비해요. ${object} 챙겨 쓰세요.`;
      case 'air+pollen': return `${time}미세먼지와 꽃가루에 대비해요. ${object} 챙겨 쓰세요.`;
      case 'humidity': return item.type === 'PORTABLE_HUMIDIFIER'
        ? `${time}공기가 매우 건조해요. ${object} 준비하고 실내 습도가 낮을 때 사용하세요.`
        : `${time}공기가 건조해요. ${object} 준비하세요.`;
      case 'uv': return `${time}자외선이 강하니 ${object} 잊지 마세요.`;
      default: return `${time}${object} 챙겨 주세요.`;
    }
  }).join('\n');
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
