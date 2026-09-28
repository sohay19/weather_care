import type {
  BriefingTimelineEntry,
  CanonicalBriefingIntent,
  TodayWeatherResponse,
  WeatherSnapshot,
} from '../types';

type WeeklyWidgetDay = {
  forecastDate?: string;
  historical?: boolean;
  min?: string | number;
  max?: string | number;
};

type WeeklyWidgetResponse = { days?: WeeklyWidgetDay[] };

const preparationLabels: Record<string, string> = {
  UMBRELLA: '우산',
  RAINCOAT: '우비',
  RAIN_BOOTS: '장화',
  PARASOL: '양산',
  SUNSCREEN: '선크림',
  SUNGLASSES: '선글라스',
  WATER: '물',
  PORTABLE_FAN: '휴대용 선풍기',
  COOLING_ITEM: '쿨링제품',
  OUTERWEAR: '두꺼운 겉옷',
  SCARF: '목도리',
  HAND_WARMER: '핫팩',
  SNOW_CHAINS: '스노우체인',
  POWER_BANK: '보조배터리',
  WINTER_BOOTS: '방한부츠',
  HEAVY_SNOW_CAUTION: '많은 눈 대비',
  MASK: '마스크',
};

export function buildHomeWidgetSnapshot(
  today: TodayWeatherResponse,
  weekly: WeeklyWidgetResponse,
  now = new Date(),
) {
  const timeline = widgetTimeline(today);
  const active = timeline.find((entry) => activeAt(entry, now));
  const fallbackRecommendations = [...(today.recommendations ?? [])]
    .filter((item) => item.recommended)
    .sort((left, right) => right.priority - left.priority);
  const fallbackTypes = fallbackRecommendations.map((item) => item.type);
  const hasCanonicalBriefing = timeline.length > 0;
  const currentTypes = hasCanonicalBriefing
    ? active?.recommendedItems ?? []
    : fallbackTypes;
  const catalogTypes = hasCanonicalBriefing
    ? timeline.flatMap((entry) => entry.recommendedItems)
    : fallbackTypes;
  const daily = todayWidgetDay(weekly.days ?? [], now);
  const next = today.nextForecast;
  const fallbackBrief = singleSpaced(today.brief);
  const brief = singleSpaced(
    active?.longMessage ?? (today.briefing ? '' : fallbackBrief),
  );
  const validUntil = active?.validUntil ?? '';

  return {
    schemaVersion: 3,
    generatedAt: today.generatedAt ?? now.toISOString(),
    locationKey: today.briefing?.locationKey ??
      `${today.region.nx}_${today.region.ny}`,
    briefingId: active?.briefingId ?? '',
    sceneId: active?.sceneId ?? 'UNAVAILABLE',
    validFrom: active?.validFrom ?? '',
    validUntil,
    nextBriefingBoundary: today.briefing?.nextBriefingBoundary ?? validUntil,
    dataFreshUntil: timeline.length === 0
      ? validUntil
      : timeline[timeline.length - 1].validUntil,
    briefingTimeline: timeline,
    region: compactRegionName(today.region.name),
    refreshTime: refreshTime(today.generatedAt, now),
    condition: weatherCondition(today.current.skyCondition),
    currentTemperature: temperature(today.current.temperature),
    apparentTemperature: temperature(
      today.current.kmaApparentTemperature ??
      today.current.apparentTemperature ??
      today.current.temperature,
    ),
    minimumTemperature: temperature(daily?.min),
    maximumTemperature: temperature(daily?.max),
    shortMessage: singleSpaced(
      active?.shortMessage ?? '최신 날씨를 확인해 주세요.',
    ),
    brief: brief || '최신 날씨를 확인해 주세요.',
    nextTime: forecastTime(next),
    nextCondition: weatherCondition(next?.skyCondition ?? today.current.skyCondition),
    nextTemperature: temperature(next?.temperature),
    preparations: preparations(currentTypes, 3),
    preparationCatalog: preparations(catalogTypes),
  };
}

type WidgetBriefingEntry = {
  briefingId: string;
  sceneId: string;
  validFrom: string;
  validUntil: string;
  shortMessage: string;
  mediumMessage: string;
  longMessage: string;
  targetFrom?: string;
  targetUntil?: string;
  action?: string;
  copyVariantKey?: string;
  recommendedItems: string[];
};

function widgetTimeline(today: TodayWeatherResponse): WidgetBriefingEntry[] {
  const entries = (today.briefingTimeline ?? []).map(widgetBriefingEntry);
  if (entries.length === 0 && today.briefing) {
    entries.push(widgetBriefingEntry(today.briefing));
  }
  return entries;
}

function widgetBriefingEntry(
  entry: BriefingTimelineEntry | CanonicalBriefingIntent,
): WidgetBriefingEntry {
  return {
    briefingId: entry.briefingId,
    sceneId: entry.sceneId,
    validFrom: entry.validFrom,
    validUntil: entry.validUntil,
    shortMessage: entry.copy.short,
    mediumMessage: entry.copy.medium,
    longMessage: entry.copy.long,
    ...(entry.targetFrom ? { targetFrom: entry.targetFrom } : {}),
    ...(entry.targetUntil ? { targetUntil: entry.targetUntil } : {}),
    ...(entry.action ? { action: entry.action } : {}),
    ...(entry.copyVariantKey ? { copyVariantKey: entry.copyVariantKey } : {}),
    recommendedItems: entry.recommendedItems ?? [],
  };
}

function activeAt(entry: WidgetBriefingEntry, now: Date): boolean {
  const from = Date.parse(entry.validFrom);
  const until = Date.parse(entry.validUntil);
  return Number.isFinite(from) && Number.isFinite(until) &&
    from <= now.getTime() && now.getTime() < until;
}

function preparations(types: Iterable<string>, limit?: number) {
  const result: { type: string; label: string }[] = [];
  const seen = new Set<string>();
  for (const type of types) {
    const label = preparationLabels[type];
    if (!label || seen.has(type)) continue;
    seen.add(type);
    result.push({ type, label });
    if (limit !== undefined && result.length >= limit) break;
  }
  return result;
}

function todayWidgetDay(days: WeeklyWidgetDay[], now: Date) {
  const today = koreaDate(now);
  return days.find((day) => !day.historical && day.forecastDate === today) ??
    days.find((day) => !day.historical &&
      (numeric(day.min) !== undefined || numeric(day.max) !== undefined));
}

function temperature(value: unknown): string {
  const parsed = numeric(value);
  if (parsed === undefined) return '--°';
  return `${Number.isInteger(parsed) ? parsed : parsed.toFixed(1)}°`;
}

function numeric(value: unknown): number | undefined {
  const parsed = typeof value === 'number' ? value
    : typeof value === 'string' && value.trim() !== '' ? Number(value) : Number.NaN;
  return Number.isFinite(parsed) ? parsed : undefined;
}

function refreshTime(value: string | undefined, fallback: Date): string {
  const parsed = validDate(value) ?? fallback;
  const korea = koreaParts(parsed);
  return `${korea.hour < 12 ? '오전' : '오후'} ${hour12(korea.hour)}:` +
    `${String(korea.minute).padStart(2, '0')} 기준`;
}

function forecastTime(snapshot?: WeatherSnapshot): string {
  const parsed = validDate(snapshot?.forecastAt ?? snapshot?.issuedAt ?? snapshot?.observedAt);
  if (!parsed) return '예보 준비 중';
  const korea = koreaParts(parsed);
  const time = korea.minute === 0
    ? `${hour12(korea.hour)}시`
    : `${hour12(korea.hour)}:${String(korea.minute).padStart(2, '0')}`;
  return `${korea.hour < 12 ? '오전' : '오후'} ${time}`;
}

function validDate(value?: string): Date | undefined {
  if (!value) return undefined;
  const parsed = new Date(value);
  return Number.isFinite(parsed.getTime()) ? parsed : undefined;
}

function koreaParts(value: Date) {
  const shifted = new Date(value.getTime() + 9 * 60 * 60 * 1000);
  return { hour: shifted.getUTCHours(), minute: shifted.getUTCMinutes() };
}

function koreaDate(value: Date): string {
  return new Date(value.getTime() + 9 * 60 * 60 * 1000)
    .toISOString().slice(0, 10);
}

function hour12(hour: number): number {
  return hour % 12 || 12;
}

function weatherCondition(value?: string): string {
  const normalized = (value ?? '').trim().toLowerCase().replaceAll(' ', '');
  if (normalized.includes('빗방울/눈날림')) return 'lightWintryMix';
  if (['비/눈', '진눈깨비', 'rain/snow', 'sleet']
    .some((item) => normalized.includes(item))) return 'wintryMix';
  if (normalized.includes('소나기') || normalized.includes('shower')) return 'shower';
  if (['빗방울', '이슬비', '가랑비', '약한비', 'drizzle']
    .some((item) => normalized.includes(item))) return 'drizzle';
  if (normalized.includes('비') || normalized.includes('rain')) return 'rain';
  if (normalized.includes('눈날림') || normalized.includes('flurry')) return 'snowFlurry';
  if (normalized.includes('눈') || normalized.includes('snow')) return 'snow';
  if (normalized.includes('구름많음') || normalized.includes('partlycloudy')) {
    return 'partlyCloudy';
  }
  if (['흐림', 'overcast', 'cloudy', '구름']
    .some((item) => normalized.includes(item))) return 'overcast';
  if (['맑음', 'clear', 'sunny']
    .some((item) => normalized.includes(item))) return 'clear';
  return 'unknown';
}

function compactRegionName(value: string): string {
  const parts = value.trim().split(/\s+/).filter(Boolean);
  if (parts.length >= 3 && /(특별시|광역시|특별자치시|특별자치도|도)$/.test(parts[0])) {
    return parts.slice(1).join(' ');
  }
  return parts.join(' ');
}

function singleSpaced(value?: string): string {
  return (value ?? '').trim().replace(/\s+/g, ' ');
}
