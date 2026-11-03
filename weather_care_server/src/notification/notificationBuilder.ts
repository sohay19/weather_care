import { Recommendation, WeatherRuleFactType } from '../types';
import { koreanHour, periodLabel, otherDatePrefix } from '../rules/precipitationWindows';
import {
  morningBriefDestination,
  NotificationDestination,
  recommendationDestination,
} from './notificationDestination';
import type { WeatherForecast } from '../providers/weather/weatherProvider';
import { preparationsForSnapshots, preparationsForWindow, type PreparationCandidate } from '../recommendations/preparationPolicy';
import { precipitationNotice } from './precipitationNotice';
import { runWeatherRuleEngineForHourly } from '../rules/weatherRuleEngine';
import { snapshotTime } from '../rules/timeWindows';
import { formatWeatherNumber } from '../utils/weatherNumber';
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
  briefContext: Omit<WeatherBriefContext, 'now'> & {
    activeWarningCodes?: readonly string[];
    roadIce?: boolean;
  } = {},
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
  const reference = now ?? new Date();
  const end = new Date(reference.getTime() + 9 * 3_600_000);
  end.setUTCHours(24, 0, 0, 0);
  const midnight = end.getTime() - 9 * 3_600_000;
  const topics: { priority: number; body: string }[] = [];
  const warnings = briefContext.activeWarningCodes ?? [];
  if (forecast && briefContext.tieredPreparations) {
    if (warnings.includes('T')) {
      topics.push({ priority: 0,
        body: '태풍 특보가 발효 중이에요. 강한 바람에 대비해 바깥 물건을 고정하고 외출을 줄이세요.' });
    }
    for (const [topic, code] of [['rain', 'R'], ['snow', 'S']] as const) {
      const warned = warnings.includes(code);
      if (!warned && !preparations.some((item) => item.reason === topic)) continue;
      const notice = precipitationNotice(forecast.hourly, topic, reference, midnight, warned);
      if (notice) topics.push(notice);
    }
    const windForecast = todayEnabled && settings?.todayWindEnabled !== false &&
      runWeatherRuleEngineForHourly(forecast.hourly.filter((item) => {
        const at = Date.parse(snapshotTime(item));
        return at >= reference.getTime() && at < midnight;
      })).some((fact) => fact.type === WeatherRuleFactType.STRONG_WIND);
    if (!warnings.includes('T') && (warnings.includes('W') || windForecast)) {
      topics.push({ priority: 1, body: warnings.includes('W')
        ? '강풍 특보가 발효 중이에요. 베란다의 가벼운 물건을 실내로 옮겨 주세요.'
        : '오늘 강한 바람이 불어요. 베란다의 가벼운 물건을 실내로 옮겨 주세요.' });
    }
    if (briefContext.roadIce) {
      topics.push({ priority: 2, body: '도로가 얼 수 있어요. 이동할 때 미끄럼에 주의하세요.' });
    }
    if (!topics.length) {
      const daily = preparations.filter((item) => item.reason !== 'rain' && item.reason !== 'snow');
      const reasons = [...new Set(daily.map((item) => item.reason))].slice(0, 2);
      for (const reason of reasons) {
        const candidates = daily.filter((item) => item.reason === reason);
        const item = candidates.find((item) =>
          item.type === 'OUTERWEAR' || item.type === 'LIGHT_OUTERWEAR',
        ) ?? candidates[0];
        topics.push({ priority: 3, body: preparationMessage(item, forecast, reference, briefContext) });
      }
    }
  }
  const preparationBody = topics.sort((a, b) => a.priority - b.priority)
    .slice(0, 2).map((topic) => topic.body).join('\n');

  const payloads: BuiltNotification[] = [];
  if (preparationBody || fallbackItems.length > 0 || summaryBriefing) {
    payloads.push({
      notification_key: 'MORNING_BRIEF',
      title: '오늘자 준비물 😊',
      body: preparationBody || summaryBriefing?.copy.notificationBody || composeBody(fallbackItems, now),
      destination: morningBriefDestination,
    });
  }
  for (const item of important) {
    const notice = forecast && briefContext.tieredPreparations
      ? precipitationNotice(forecast.hourly, 'snow', reference, Infinity)
      : undefined;
    payloads.push({
      notification_key: `IMPORTANT_${item.type}`,
      title: item.title,
      body: notice?.priority === 0 ? notice.body : timedDescription(item, now),
      destination: recommendationDestination(item.type),
    });
  }
  return payloads;
}

function preparationMessage(
  item: PreparationCandidate,
  forecast: WeatherForecast,
  now: Date,
  context: Omit<WeatherBriefContext, 'now'>,
): string {
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
        ? '밤 12시' : koreanHour(item.validUntil)}${item.reason === 'uv' ? '까지 ' : '까지는 '}`;
  }
  const names = titleFor(item.type);
  const object = names + ((names.charCodeAt(names.length - 1) - 0xac00) % 28 === 0 ? '를' : '을');
  switch (item.reason) {
    case 'cold': {
      const value = weatherValue(item, forecast, (snapshot) =>
        snapshot.kmaApparentTemperature ?? snapshot.apparentTemperature ?? snapshot.temperature);
      const label = value?.snapshot.kmaApparentTemperature !== undefined ||
        value?.snapshot.apparentTemperature !== undefined ? '체감 ' : '기온 ';
      const metric = value ? ` (최저 ${label}${formatWeatherNumber(value.amount)}℃)` : '';
      return `${time}쌀쌀해요${metric}. ${object} ${
        item.type === 'OUTERWEAR' || item.type === 'LIGHT_OUTERWEAR' ? '챙겨 입으세요' : '챙기세요'}.`;
    }
    case 'heat': return item.type === 'WATER'
      ? `${time}더위에 대비해요. ${object} 챙기고 틈틈이 쉬어 가세요.`
      : `${time}더위에 대비해요. ${object} 챙기고 물을 마시며 쉬어 가세요.`;
    case 'air': return `${time}미세먼지가 심하니 ${object} 챙겨 쓰세요.`;
    case 'pollen': return `${time}꽃가루에 대비해요. ${object} 챙겨 쓰세요.`;
    case 'air+pollen': return `${time}미세먼지와 꽃가루에 대비해요. ${object} 챙겨 쓰세요.`;
    case 'humidity': {
      const value = weatherValue(item, forecast, (snapshot) => snapshot.humidity);
      const metric = value ? ` (실외 습도 최저 ${formatWeatherNumber(value.amount)}%)` : '';
      return item.type === 'PORTABLE_HUMIDIFIER'
        ? `${time}공기가 매우 건조해요${metric}. ${object} 준비하고 실내 습도가 낮을 때 사용하세요.`
        : `${time}공기가 건조해요${metric}. ${object} 챙기세요.`;
    }
    case 'uv': return `${time}자외선이 강하니 ${object} 잊지 마세요.`;
    default: return `${time}${object} 챙겨 주세요.`;
  }
}

function weatherValue(
  item: PreparationCandidate,
  forecast: WeatherForecast,
  read: (snapshot: WeatherForecast['current']) => number | undefined,
) {
  const start = Date.parse(item.validFrom ?? '');
  const end = Date.parse(item.validUntil ?? '');
  return [...forecast.hourly, forecast.current].flatMap((snapshot) => {
    const time = Date.parse(snapshotTime(snapshot));
    const amount = read(snapshot);
    return time >= start && time < end && amount !== undefined && Number.isFinite(amount)
      ? [{ amount, snapshot }] : [];
  }).sort((a, b) => a.amount - b.amount)[0];
}

function composeBody(
  items: Recommendation[],
  now: Date | undefined,
): string {
  return items.map((item) => timedDescription(item, now))
    .slice(0, 2)
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
