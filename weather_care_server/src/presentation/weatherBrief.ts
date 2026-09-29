import { defaultRuleConfig } from '../config/ruleConfig';
import type { WeatherForecast } from '../providers/weather/weatherProvider';
import {
  koreaDate,
  precipitationPeriod,
  periodLabel,
  koreanHour,
} from '../rules/precipitationWindows';
import { snapshotTime } from '../rules/timeWindows';
import type {
  BriefingCopy,
  BriefingSceneId,
  BriefingTimelineEntry,
  CanonicalBriefingIntent,
  RecommendationType,
  WeatherSnapshot,
} from '../types';

export const WEATHER_BRIEF_CATALOG_VERSION = 'weather-brief-2026.09.v2';
const HOUR = 3_600_000;
const CURRENT_OBSERVATION_FRESH_MS = 30 * 60 * 1_000;
const TIMELINE_LIMIT_MS = 24 * HOUR;

export type WeatherBriefScene = BriefingSceneId;

export interface WeatherBriefContext {
  regionKey?: string;
  dateKey?: string;
  now?: Date;
  sunriseAt?: string;
  sunsetAt?: string;
  /** 알림 설정에서 허용된 준비물로 action scene을 제한한다. */
  allowedRecommendedItems?: RecommendationType[];
  /** 추천 엔진이 현재 강도에서 노출하도록 결정한 준비물이다. */
  severityRecommendedItems?: RecommendationType[];
  /** 새 앱의 확장 준비물 카탈로그를 브리핑과 함께 사용한다. */
  expandedPreparations?: boolean;
}

export interface WeatherBriefResult {
  /** 구버전 앱 호환용 medium 문장. */
  text: string;
  scene: WeatherBriefScene;
  templateId: string;
  slots: Readonly<{ eventTime?: string }>;
  catalogVersion: string;
  /** 구버전 앱 호환용 다음 재평가 경계. */
  expiresAt?: string;
  intent: CanonicalBriefingIntent;
  timeline: BriefingTimelineEntry[];
}

interface SceneSelection {
  scene: WeatherBriefScene;
  snapshot: WeatherSnapshot;
  start: number;
  end: number;
  active: boolean;
  precipitation: boolean;
  score: number;
}

interface IntentDraft {
  intent: CanonicalBriefingIntent;
  eventTime?: string;
}

export function buildWeatherBrief(
  forecast: WeatherForecast,
  context: WeatherBriefContext = {},
): string {
  return buildWeatherBriefResult(forecast, context).text;
}

export function buildWeatherBriefResult(
  forecast: WeatherForecast,
  context: WeatherBriefContext = {},
): WeatherBriefResult {
  const now = context.now ?? new Date();
  const timeline = buildBriefingTimeline(forecast, { ...context, now });
  const first = timeline[0];
  const draft = buildIntentAt(forecast, { ...context, now });
  const intent: CanonicalBriefingIntent = first
    ? {
        ...draft.intent,
        validFrom: first.validFrom,
        validUntil: first.validUntil,
        nextBriefingBoundary: first.validUntil,
      }
    : draft.intent;
  return {
    text: intent.copy.medium,
    scene: intent.sceneId,
    templateId: `policy-${intent.sceneId.toLowerCase()}`,
    slots: draft.eventTime ? { eventTime: draft.eventTime } : {},
    catalogVersion: WEATHER_BRIEF_CATALOG_VERSION,
    expiresAt: intent.nextBriefingBoundary ?? intent.validUntil,
    intent,
    timeline,
  };
}

export function buildBriefingTimeline(
  forecast: WeatherForecast,
  context: WeatherBriefContext = {},
): BriefingTimelineEntry[] {
  const now = context.now ?? new Date();
  const start = now.getTime();
  const horizon = Math.min(
    start + TIMELINE_LIMIT_MS,
    nextKoreanMidnight(start),
  );
  const boundaries = briefingBoundaries(forecast, context, start, horizon);
  const segments: BriefingTimelineEntry[] = [];

  for (let index = 0; index < boundaries.length - 1; index += 1) {
    const from = boundaries[index];
    const until = boundaries[index + 1];
    if (until <= from) continue;
    const { intent } = buildIntentAt(forecast, {
      ...context,
      now: new Date(from),
    });
    const entry: BriefingTimelineEntry = {
      briefingId: intent.briefingId,
      sceneId: intent.sceneId,
      validFrom: new Date(from).toISOString(),
      validUntil: new Date(until).toISOString(),
      targetFrom: intent.targetFrom,
      targetUntil: intent.targetUntil,
      action: intent.action,
      recommendedItems: intent.recommendedItems,
      copyVariantKey: intent.copyVariantKey,
      copy: intent.copy,
    };
    const previous = segments.at(-1);
    if (previous && sameTimelineMeaning(previous, entry)) {
      previous.validUntil = entry.validUntil;
    } else {
      segments.push(entry);
    }
  }
  return segments;
}

function buildIntentAt(
  forecast: WeatherForecast,
  context: WeatherBriefContext,
): IntentDraft {
  const now = context.now ?? new Date();
  const selection = selectScene(forecast, now, context);
  const eventTime = eventTimeFor(selection);
  const locationKey = context.regionKey ?? 'unknown';
  const seed = [
    locationKey,
    koreaDate(now.toISOString()),
    timeContext(selection, context),
    selection.scene,
    selection.snapshot.kmaApparentTemperature ??
      selection.snapshot.apparentTemperature ?? '',
  ].join(':');
  const rendered = renderCopy(selection, seed);
  const sourceTime = selection.snapshot.forecastAt ??
    selection.snapshot.validFrom ?? selection.snapshot.observedAt;
  const validFrom = now.toISOString();
  const validUntil = new Date(Math.max(selection.end, now.getTime() + 1)).toISOString();
  const targetFrom = targetTime(selection, true);
  const targetUntil = targetTime(selection, false);
  const briefingId = [
    locationKey,
    koreaDate(now.toISOString()).replaceAll('-', ''),
    selection.scene,
    compactTime(targetFrom ?? validFrom),
    compactTime(targetUntil ?? validUntil),
  ].join(':');
  const meaning = sceneMeaning(
    selection.scene,
    context.expandedPreparations ?? false,
  );
  const severityItems = context.severityRecommendedItems === undefined
    ? meaning.recommendedItems
    : meaning.recommendedItems.filter((item) =>
        context.severityRecommendedItems?.includes(item));
  const recommendedItems = context.allowedRecommendedItems === undefined
    ? severityItems
    : severityItems.filter((item) =>
        context.allowedRecommendedItems?.includes(item));
  return {
    eventTime,
    intent: {
      briefingId,
      locationKey,
      sceneId: selection.scene,
      topic: meaning.topic,
      scope: selection.active
        ? selection.snapshot.dataRole === 'OBSERVATION' ? 'CURRENT' : 'TODAY'
        : 'NEAR_FUTURE',
      severity: meaning.severity,
      confidence: confidenceFor(selection.snapshot),
      targetFrom,
      targetUntil,
      validFrom,
      validUntil,
      dataRole: selection.snapshot.dataRole ??
        (selection.snapshot.forecastAt ? 'FORECAST' : undefined),
      observedAt: selection.snapshot.dataRole === 'OBSERVATION'
        ? selection.snapshot.observedAt
        : undefined,
      forecastAt: selection.snapshot.dataRole === 'OBSERVATION'
        ? undefined
        : sourceTime,
      issuedAt: selection.snapshot.issuedAt,
      sourceLocation: selection.snapshot.sourceLocation,
      qualityFlags: [...new Set(selection.snapshot.qualityFlags ?? [])],
      evidenceFields: meaning.evidenceFields,
      headlineFact: meaning.headlineFact,
      supportingFact: eventTime,
      action: meaning.action,
      recommendedItems,
      copyVariantKey: rendered.variantKey,
      copy: rendered.copy,
    },
  };
}

function selectScene(
  forecast: WeatherForecast,
  now: Date,
  context: WeatherBriefContext,
): SceneSelection {
  const current = forecast.current;
  const hourly = forecast.hourly.slice(0, 24)
    .filter((item) => Number.isFinite(Date.parse(snapshotTime(item))))
    .sort((left, right) => Date.parse(snapshotTime(left)) - Date.parse(snapshotTime(right)));
  const candidates = [current, ...hourly]
    .filter((item) => Number.isFinite(Date.parse(snapshotTime(item))));
  const selections: SceneSelection[] = [];
  const add = (
    scene: WeatherBriefScene,
    score: number,
    predicate: (item: WeatherSnapshot) => boolean,
    precipitation = false,
    daylightOnly = false,
  ) => {
    if (!sceneAllowedByContext(scene, context)) return;
    const match = findSelection(
      candidates,
      scene,
      score,
      predicate,
      precipitation,
      daylightOnly,
      now,
      context,
    );
    if (match) selections.push(match);
  };

  add('SNOW', 95, isSnowy, true);
  add('RAIN', 90, isRainy, true);
  add('VISIBILITY', 82, (item) => (item.visibilityMeters ?? Infinity) < 1_000);
  add('AIR_QUALITY', 78, hasPoorAirQuality);
  add('OZONE', 74, (item) => (item.ozone ?? 0) >= 0.09);
  add('UV', 70, (item) =>
    (item.uvIndex ?? 0) >= defaultRuleConfig.uv.highThreshold, false, true);
  add('THERMAL_HOT', 67, isHot);
  add('THERMAL_COLD', 67, isCold);
  add('WIND', 60, (item) =>
    (item.windSpeed ?? 0) >= defaultRuleConfig.wind.caution);
  add('HUMIDITY_HIGH', 44, (item) =>
    (item.humidity ?? -Infinity) >= defaultRuleConfig.humidity.high);
  add('HUMIDITY_LOW', 44, (item) =>
    (item.humidity ?? Infinity) <= defaultRuleConfig.humidity.low);
  add('THERMAL_COMFORTABLE', 30, isComfortable);

  if (selections.length > 0) {
    return selections.sort((left, right) => {
      const leftScore = left.score + (left.active ? 8 : 0) -
        Math.min(12, Math.max(0, left.start - now.getTime()) / HOUR);
      const rightScore = right.score + (right.active ? 8 : 0) -
        Math.min(12, Math.max(0, right.start - now.getTime()) / HOUR);
      return rightScore - leftScore || left.start - right.start;
    })[0];
  }

  const interval = snapshotInterval(current, false);
  const fallbackStart = now.getTime();
  const currentIsUsable = interval !== undefined &&
    interval.start <= fallbackStart && interval.end > fallbackStart;
  const fallbackSnapshot: WeatherSnapshot = currentIsUsable
    ? current
    : { observedAt: now.toISOString() };
  const fallbackEnd = Math.min(
    currentIsUsable && interval
      ? interval.end
      : fallbackStart + HOUR,
    nextKoreanMidnight(fallbackStart),
  );
  return {
    scene: currentIsUsable && (current.visibilityMeters ?? 0) >= 20_000
      ? 'CLEAR_COMFORTABLE'
      : 'DEFAULT',
    snapshot: fallbackSnapshot,
    start: fallbackStart,
    end: fallbackEnd,
    active: true,
    precipitation: false,
    score: 0,
  };
}

function sceneAllowedByContext(
  scene: WeatherBriefScene,
  context: WeatherBriefContext,
): boolean {
  if (context.allowedRecommendedItems === undefined) return true;
  const required = sceneMeaning(
    scene,
    context.expandedPreparations ?? false,
  ).recommendedItems;
  return required.length === 0 || required.some((item) =>
    context.allowedRecommendedItems?.includes(item));
}

function findSelection(
  snapshots: WeatherSnapshot[],
  scene: WeatherBriefScene,
  score: number,
  predicate: (item: WeatherSnapshot) => boolean,
  precipitation: boolean,
  daylightOnly: boolean,
  now: Date,
  context: WeatherBriefContext,
): SceneSelection | undefined {
  const reference = now.getTime();
  const today = koreaDate(now.toISOString());
  const sunset = timestamp(context.sunsetAt);
  const sunrise = timestamp(context.sunriseAt);
  for (let index = 0; index < snapshots.length; index += 1) {
    const snapshot = snapshots[index];
    if (!predicate(snapshot)) continue;
    const ownInterval = snapshotInterval(snapshot, precipitation);
    if (!ownInterval || ownInterval.end <= reference) continue;
    const interval = precipitation
      ? mergedPrecipitationInterval(snapshots, index, predicate)
      : ownInterval;
    if (!interval) continue;
    let { start, end } = interval;
    if (daylightOnly) {
      if (sunset !== undefined) end = Math.min(end, sunset);
      if (sunrise !== undefined) start = Math.max(start, sunrise);
    }
    if (end <= start || end <= reference || start >= reference + TIMELINE_LIMIT_MS) {
      continue;
    }
    const active = start <= reference;
    if (!active && koreaDate(new Date(start).toISOString()) !== today) continue;
    return { scene, snapshot, start, end, active, precipitation, score };
  }
  return undefined;
}

function mergedPrecipitationInterval(
  snapshots: WeatherSnapshot[],
  selectedIndex: number,
  predicate: (item: WeatherSnapshot) => boolean,
): { start: number; end: number } | undefined {
  const selected = snapshotInterval(snapshots[selectedIndex], true);
  if (!selected) return undefined;
  let { start, end } = selected;
  let changed = true;
  while (changed) {
    changed = false;
    for (const snapshot of snapshots) {
      if (!predicate(snapshot)) continue;
      const interval = snapshotInterval(snapshot, true);
      if (!interval || interval.end < start || interval.start > end) continue;
      const nextStart = Math.min(start, interval.start);
      const nextEnd = Math.max(end, interval.end);
      if (nextStart !== start || nextEnd !== end) {
        start = nextStart;
        end = nextEnd;
        changed = true;
      }
    }
  }
  return { start, end };
}

function snapshotInterval(
  snapshot: WeatherSnapshot,
  usePrecipitationPeriod: boolean,
): { start: number; end: number } | undefined {
  const period = usePrecipitationPeriod ? precipitationPeriod(snapshot) : undefined;
  if (period) {
    return { start: Date.parse(period.start), end: Date.parse(period.end) };
  }
  const point = Date.parse(
    snapshot.dataRole === 'OBSERVATION'
      ? snapshot.observedAt
      : snapshotTime(snapshot),
  );
  if (!Number.isFinite(point)) return undefined;
  if (snapshot.dataRole === 'OBSERVATION') {
    return { start: point, end: point + CURRENT_OBSERVATION_FRESH_MS };
  }
  if (snapshot.validTo !== undefined) {
    const validTo = Date.parse(snapshot.validTo);
    if (!Number.isFinite(validTo)) return undefined;
    if (validTo < point) return undefined;
    if (validTo > point) {
      return { start: point, end: Math.min(validTo, point + HOUR) };
    }
  }
  return { start: point, end: point + HOUR };
}

function renderCopy(
  selection: SceneSelection,
  seed: string,
): { variantKey: string; copy: BriefingCopy } {
  const eventStart = koreanHour(new Date(selection.start).toISOString());
  const eventRange = periodLabel(
    new Date(selection.start).toISOString(),
    new Date(selection.end).toISOString(),
  );
  const period = koreanDayPeriod(selection.start);
  const observed = selection.active && selection.snapshot.dataRole === 'OBSERVATION';
  const variants = copyVariants(selection, {
    eventStart,
    eventRange,
    period,
    observed,
  });
  const index = deterministicIndex(seed, variants.length);
  return {
    variantKey: `${selection.scene.toLowerCase()}-${index + 1}`,
    copy: normalizeCopy(variants[index]),
  };
}

function copyVariants(
  selection: SceneSelection,
  time: {
    eventStart: string;
    eventRange: string;
    period: string;
    observed: boolean;
  },
): BriefingCopy[] {
  switch (selection.scene) {
    case 'SNOW':
      return [copy(
        selection.active ? '눈 소식, 이동에 주의하세요.' : `${time.period} 눈, 이동에 주의하세요.`,
        time.observed
          ? '지금 눈이 내리고 있어요. 이동할 때 도로 상태를 살펴주세요.'
          : `${time.eventStart}부터 눈이 올 수 있어요. 이동할 때 도로 상태를 살펴주세요.`,
        `${time.eventRange} 눈이 올 가능성이 높아요. 외출한다면 도로 상태와 대중교통 운행정보를 확인해 주세요.`,
        '눈 소식',
        `${time.eventRange} 눈이 올 수 있어요. 이동 전에 도로 상태를 확인해 주세요.`,
      )];
    case 'RAIN':
      const precipitationName = selection.snapshot.precipitationType === 'SHOWER'
        ? '소나기'
        : '비';
      return [copy(
        selection.active
          ? `${precipitationName} 소식, 우산 챙기세요.`
          : `${time.period} ${precipitationName}, 우산 챙기세요.`,
        time.observed
          ? `지금 ${precipitationName}가 내리고 있어요. 외출한다면 우산을 챙기세요.`
          : selection.active
            ? `현재 시각대에는 ${precipitationName} 가능성이 높아요. 외출한다면 우산을 챙기세요.`
            : `${time.eventStart}부터 ${precipitationName}가 올 수 있어요. 우산을 챙기세요.`,
        `${time.eventRange} ${precipitationName} 가능성이 높아요. 외출한다면 우산을 챙기는 게 좋아요.`,
        selection.active ? `현재 ${precipitationName} 소식` : `${time.period} ${precipitationName} 소식`,
        `${time.eventRange} ${precipitationName} 가능성이 높아요. 외출한다면 우산을 챙기세요.`,
      )];
    case 'UV':
      return [copy(
        '자외선이 강해요. 햇볕을 피하세요.',
        '낮 동안 자외선이 강해요. 선크림이나 양산을 챙기세요.',
        '낮 동안 자외선이 강할 것으로 보여요. 오래 외출한다면 선크림이나 양산으로 햇볕을 막는 게 좋아요.',
        '낮 자외선이 강해요',
        '낮 동안 자외선이 높을 것으로 보여요. 외출한다면 선크림이나 양산을 챙기세요.',
      )];
    case 'AIR_QUALITY':
      return [copy(
        '대기질이 좋지 않아요. 마스크를 챙기세요.',
        '미세먼지나 초미세먼지가 나쁨 단계예요. 외출한다면 마스크를 챙기세요.',
        '대기질이 좋지 않아 오래 머물면 불편할 수 있어요. 외출한다면 보건용 마스크를 준비하는 게 좋아요.',
        '오늘 대기질을 확인하세요',
        '대기질이 좋지 않아요. 외출한다면 보건용 마스크를 챙기세요.',
      )];
    case 'OZONE':
      return [copy(
        '오존 농도가 높아요. 오래 외출하지 마세요.',
        '오존 농도가 높아요. 민감하다면 긴 야외 활동을 줄여주세요.',
        '현재 오존 농도가 높아 야외 활동이 불편할 수 있어요. 민감하다면 오래 외출하지 않는 게 좋아요.',
        '오존 농도가 높아요',
        '오존 농도가 높아요. 민감하다면 긴 야외 활동을 줄여주세요.',
      )];
    case 'VISIBILITY':
      return [copy(
        '시야가 좋지 않아요. 운전에 주의하세요.',
        '시야가 좋지 않아요. 운전할 때 주변을 더 살펴주세요.',
        (selection.snapshot.visibilityMeters ?? Infinity) < 200
          ? '앞이 매우 잘 보이지 않아요. 운전한다면 속도를 줄이고 차간 거리를 넉넉히 두세요.'
          : '시야가 탁해 먼 곳이 잘 보이지 않아요. 운전할 때 감속하고 주변을 살펴주세요.',
        '시야가 좋지 않아요',
        '시야가 좋지 않아요. 운전할 때 감속하고 주변을 살펴주세요.',
      )];
    case 'THERMAL_HOT':
      return [copy(
        '덥게 느껴져요. 물을 챙기세요.',
        '기상청 방식 체감온도가 높아요. 물을 자주 마셔주세요.',
        '기상청 방식 체감온도가 높아요. 오래 활동한다면 물을 자주 마셔주세요.',
        '덥게 느껴지는 날씨예요',
        '덥게 느껴질 수 있어요. 오래 활동한다면 물을 자주 마셔주세요.',
      )];
    case 'THERMAL_COLD':
      return [copy(
        '쌀쌀하게 느껴져요. 겉옷을 챙기세요.',
        '기상청 방식 체감온도가 낮아요. 겉옷을 챙기세요.',
        '기상청 방식 체감온도가 낮아요. 외출한다면 겉옷을 챙기는 게 좋아요.',
        '쌀쌀하게 느껴지는 날씨예요',
        '쌀쌀하게 느껴질 수 있어요. 외출한다면 겉옷을 챙기세요.',
      )];
    case 'THERMAL_COMFORTABLE':
      return [
        copy(
          '덥지도 춥지도 않아 쾌적해요.',
          '기온과 체감 차이가 크지 않고, 덥지도 춥지도 않아 쾌적해요.',
          '기온과 체감 차이가 크지 않아요. 크게 덥거나 춥지 않아 활동하기 편안한 날씨예요.',
          '쾌적한 날씨예요',
          '덥지도 춥지도 않아 활동하기 편안한 날씨예요.',
        ),
        copy(
          '선선하고 편안한 날씨예요.',
          '크게 덥거나 춥지 않아 편안하게 느껴져요.',
          '기온과 체감이 크게 다르지 않아요. 야외에서 활동하기 편안한 날씨예요.',
          '편안한 날씨예요',
          '크게 덥거나 춥지 않아 활동하기 편안해요.',
        ),
      ];
    case 'WIND':
      return [copy(
        '바람이 강해요. 소지품을 살펴주세요.',
        `${selection.active ? '지금' : time.eventStart} 바람이 강할 수 있어요. 소지품을 단단히 고정하세요.`,
        `${time.eventRange} 바람이 강할 수 있어요. 외출한다면 모자나 가벼운 소지품이 날리지 않게 살펴주세요.`,
        '강한 바람에 주의하세요',
        `${time.eventRange} 바람이 강할 수 있어요. 소지품을 단단히 고정하세요.`,
      )];
    case 'HUMIDITY_HIGH':
      return [copy(
        '공기가 습해요.',
        (selection.snapshot.temperature ?? 0) >= 25
          ? '공기가 후텁지근해요. 움직이면 더 덥게 느껴질 수 있어요.'
          : '실외 공기가 눅눅해요. 빨래가 더디게 마를 수 있어요.',
        (selection.snapshot.temperature ?? 0) >= 25
          ? '습도가 높아 후텁지근해요. 바람도 약하면 움직일 때 더 덥게 느껴질 수 있어요.'
          : '실외 공기가 눅눅하게 느껴져요. 빨래는 평소보다 더디게 마를 수 있어요.',
        '공기가 습해요',
        (selection.snapshot.temperature ?? 0) >= 25
          ? '공기가 후텁지근해요. 움직이면 더 덥게 느껴질 수 있어요.'
          : '실외 공기가 눅눅해요. 빨래가 더디게 마를 수 있어요.',
      )];
    case 'HUMIDITY_LOW':
      return [copy(
        '공기가 건조해요.',
        '실외 공기가 건조해 코나 목이 마르게 느껴질 수 있어요.',
        '실외 공기가 건조해요. 오래 밖에 있다면 물을 자주 마시고 코나 목이 마르지 않게 살펴주세요.',
        '공기가 건조해요',
        '실외 공기가 건조해요. 물을 자주 마셔주세요.',
      )];
    case 'CLEAR_COMFORTABLE':
      return [copy(
        '시야가 맑고 편안한 날씨예요.',
        '멀리까지 또렷하게 보일 만큼 시야가 좋아요.',
        '날씨 조건만 보면 멀리 있는 건물까지 또렷하게 보일 만큼 시야가 좋아요.',
        '시야가 좋은 날씨예요',
        '멀리까지 또렷하게 보일 만큼 시야가 좋아요.',
      )];
    default:
      return [copy(
        '시간별 예보를 확인하세요.',
        '오늘은 특별한 예보가 없어요. 외출 전에 시간별 예보를 확인해 보세요.',
        '오늘은 특별한 예보가 없어요. 외출 계획이 있다면 시간별 예보를 한 번 확인해 보세요.',
        '오늘 날씨 안내',
        '외출 전에 시간별 예보를 확인해 주세요.',
      )];
  }
}

function copy(
  short: string,
  medium: string,
  long: string,
  notificationTitle: string,
  notificationBody: string,
): BriefingCopy {
  return { short, medium, long, notificationTitle, notificationBody };
}

function normalizeCopy(value: BriefingCopy): BriefingCopy {
  return Object.fromEntries(Object.entries(value).map(([key, text]) => [
    key,
    normalizeSentence(text),
  ])) as unknown as BriefingCopy;
}

function normalizeSentence(value: string): string {
  return value.trim()
    .replace(/\s+/g, ' ')
    .replace(/오후\s+(1[3-9]|2[0-3])시/g, (_, hour: string) =>
      `오후 ${Number(hour) - 12}시`)
    .replace(/현재\s+지금/g, '지금');
}

function sceneMeaning(
  scene: WeatherBriefScene,
  expandedPreparations = false,
): {
  topic: string;
  severity: CanonicalBriefingIntent['severity'];
  evidenceFields: string[];
  headlineFact: string;
  action?: string;
  recommendedItems: RecommendationType[];
} {
  switch (scene) {
    case 'SNOW': return meaning('눈', 'HIGH', ['PTY', 'POP', 'SNO'], '눈 가능성', 'CHECK_SNOW_TRAVEL', expandedPreparations ? ['WINTER_BOOTS', 'SNOW_CHAINS', 'POWER_BANK'] : ['WINTER_BOOTS']);
    case 'RAIN': return meaning('비', 'MODERATE', ['PTY', 'POP', 'PCP'], '비 가능성', 'TAKE_UMBRELLA', expandedPreparations ? ['UMBRELLA', 'RAINCOAT', 'RAIN_BOOTS'] : ['UMBRELLA']);
    case 'UV': return meaning('자외선', 'MODERATE', ['UV'], '높은 자외선', 'SUN_PROTECTION', expandedPreparations ? ['SUNSCREEN', 'PARASOL', 'SUNGLASSES'] : ['SUNSCREEN', 'PARASOL']);
    case 'AIR_QUALITY': return meaning('대기질', 'MODERATE', ['PM10', 'PM25'], '좋지 않은 대기질', 'TAKE_MASK', ['MASK']);
    case 'OZONE': return meaning('오존', 'MODERATE', ['O3'], '높은 오존', 'LIMIT_OUTDOOR_ACTIVITY', []);
    case 'VISIBILITY': return meaning('가시거리', 'HIGH', ['VS'], '낮은 가시거리', 'DRIVE_CAREFULLY', []);
    case 'THERMAL_HOT': return meaning('체감온도', 'MODERATE', ['apparentTemperature', 'temperature'], '높은 기상청 체감온도', 'HYDRATE', expandedPreparations ? ['WATER', 'PORTABLE_FAN', 'COOLING_ITEM'] : ['WATER']);
    case 'THERMAL_COLD': return meaning('체감온도', 'MODERATE', ['apparentTemperature', 'temperature'], '낮은 기상청 체감온도', 'TAKE_OUTERWEAR', expandedPreparations ? ['OUTERWEAR', 'SCARF', 'HAND_WARMER'] : ['OUTERWEAR']);
    case 'THERMAL_COMFORTABLE': return meaning('체감온도', 'INFO', ['apparentTemperature'], '쾌적한 기상청 체감온도', undefined, []);
    case 'WIND': return meaning('바람', 'MODERATE', ['WSD'], '강한 바람', 'SECURE_BELONGINGS', []);
    case 'HUMIDITY_HIGH': return meaning('습도', 'INFO', ['REH'], '높은 습도', undefined, []);
    case 'HUMIDITY_LOW': return meaning('습도', 'INFO', ['REH'], '낮은 습도', 'HYDRATE', ['WATER']);
    case 'CLEAR_COMFORTABLE': return meaning('가시거리', 'INFO', ['VS'], '좋은 가시거리', undefined, []);
    default: return meaning('날씨', 'INFO', [], '특별한 생활 위험 없음', undefined, []);
  }
}

function meaning(
  topic: string,
  severity: CanonicalBriefingIntent['severity'],
  evidenceFields: string[],
  headlineFact: string,
  action: string | undefined,
  recommendedItems: RecommendationType[],
) {
  return { topic, severity, evidenceFields, headlineFact, action, recommendedItems };
}

function briefingBoundaries(
  forecast: WeatherForecast,
  context: WeatherBriefContext,
  start: number,
  horizon: number,
): number[] {
  const values = new Set<number>([start, horizon]);
  for (const raw of [context.sunriseAt, context.sunsetAt]) {
    const value = timestamp(raw);
    if (value !== undefined && value > start && value < horizon) values.add(value);
  }
  for (const snapshot of [forecast.current, ...forecast.hourly.slice(0, 24)]) {
    const normal = snapshotInterval(snapshot, false);
    const wet = snapshotInterval(snapshot, true);
    for (const value of [normal?.start, normal?.end, wet?.start, wet?.end]) {
      if (value !== undefined && value > start && value < horizon) values.add(value);
    }
  }
  return [...values].sort((left, right) => left - right);
}

function sameTimelineMeaning(
  left: BriefingTimelineEntry,
  right: BriefingTimelineEntry,
): boolean {
  return left.sceneId === right.sceneId &&
    left.targetFrom === right.targetFrom &&
    left.targetUntil === right.targetUntil &&
    left.action === right.action &&
    left.copyVariantKey === right.copyVariantKey &&
    left.copy.short === right.copy.short &&
    left.copy.medium === right.copy.medium &&
    left.copy.long === right.copy.long &&
    left.copy.notificationTitle === right.copy.notificationTitle &&
    left.copy.notificationBody === right.copy.notificationBody;
}

function eventTimeFor(selection: SceneSelection): string | undefined {
  if (selection.scene === 'DEFAULT' || selection.scene === 'CLEAR_COMFORTABLE' ||
      selection.scene === 'THERMAL_COMFORTABLE') return undefined;
  if (selection.active) return '지금';
  const start = new Date(selection.start).toISOString();
  const end = new Date(selection.end).toISOString();
  return selection.precipitation ? periodLabel(start, end) : koreanHour(start);
}

function targetTime(selection: SceneSelection, start: boolean): string | undefined {
  if (selection.scene === 'DEFAULT' || selection.scene === 'CLEAR_COMFORTABLE') {
    return undefined;
  }
  return new Date(start ? selection.start : selection.end).toISOString();
}

function timeContext(
  selection: SceneSelection,
  context: WeatherBriefContext,
): string {
  if (!selection.active) return 'EVENT_BEFORE';
  if (selection.precipitation) return 'EVENT_ACTIVE';
  const sunset = timestamp(context.sunsetAt);
  if (sunset !== undefined && selection.start >= sunset) return 'EVENING';
  const hour = new Date(selection.start + 9 * HOUR).getUTCHours();
  return hour >= 22 || hour < 5 ? 'NIGHT' : 'DAYLIGHT';
}

function deterministicIndex(seed: string, length: number): number {
  let hash = 2166136261;
  for (let index = 0; index < seed.length; index += 1) {
    hash ^= seed.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return length === 0 ? 0 : (hash >>> 0) % length;
}

function confidenceFor(
  snapshot: WeatherSnapshot,
): CanonicalBriefingIntent['confidence'] {
  if (snapshot.qualityFlags?.some((flag) =>
    ['SOURCE_DELAYED', 'LOCATION_FALLBACK'].includes(flag))) return 'MEDIUM';
  return 'HIGH';
}

function isSnowy(snapshot: WeatherSnapshot): boolean {
  return snapshot.snowExpected === true ||
    snapshot.precipitationType === 'SNOW' ||
    snapshot.precipitationType === 'RAIN_SNOW';
}

function isRainy(snapshot: WeatherSnapshot): boolean {
  return (snapshot.precipitationProbability ?? 0) >=
      defaultRuleConfig.rain.minProbability ||
    snapshot.precipitationType === 'RAIN' ||
    snapshot.precipitationType === 'SHOWER';
}

function hasPoorAirQuality(snapshot: WeatherSnapshot): boolean {
  const grade = String(snapshot.airQualityGrade ?? '').toLowerCase();
  return (snapshot.pm25 ?? 0) >= defaultRuleConfig.airQuality.pm25 ||
    (snapshot.pm10 ?? 0) >= defaultRuleConfig.airQuality.pm10 ||
    grade.includes('bad') || grade.includes('나쁨');
}

function isHot(snapshot: WeatherSnapshot): boolean {
  return (officialApparentTemperature(snapshot) ?? -Infinity) >=
      defaultRuleConfig.heat.actionApparentTemperature ||
    (snapshot.temperature ?? -Infinity) >=
      defaultRuleConfig.heat.actionAirTemperature;
}

function isCold(snapshot: WeatherSnapshot): boolean {
  return (officialApparentTemperature(snapshot) ?? Infinity) <=
      defaultRuleConfig.cold.apparentTemperature ||
    (snapshot.temperature ?? Infinity) <= defaultRuleConfig.cold.temperature;
}

function isComfortable(snapshot: WeatherSnapshot): boolean {
  const apparentTemperature = officialApparentTemperature(snapshot);
  return apparentTemperature !== undefined &&
    apparentTemperature > defaultRuleConfig.cold.apparentTemperature &&
    apparentTemperature < defaultRuleConfig.heat.actionApparentTemperature;
}

function officialApparentTemperature(
  snapshot: WeatherSnapshot,
): number | undefined {
  return snapshot.kmaApparentTemperature ?? snapshot.apparentTemperature;
}

function koreanDayPeriod(value: number): string {
  const hour = new Date(value + 9 * HOUR).getUTCHours();
  if (hour < 6) return '밤늦게';
  if (hour < 12) return '오전';
  if (hour < 18) return '오후';
  return '저녁';
}

function timestamp(value: string | undefined): number | undefined {
  if (!value) return undefined;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function compactTime(value: string): string {
  return value.replace(/\D/g, '').slice(0, 12);
}

function nextKoreanMidnight(value: number): number {
  const korean = new Date(value + 9 * HOUR);
  return Date.UTC(
    korean.getUTCFullYear(),
    korean.getUTCMonth(),
    korean.getUTCDate() + 1,
  ) - 9 * HOUR;
}
