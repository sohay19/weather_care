import { defaultRuleConfig } from '../config/ruleConfig';
import type { WeatherForecast } from '../providers/weather/weatherProvider';
import { snapshotTime } from '../rules/timeWindows';
import { precipitationDecisionSnapshot, precipitationPeriod } from '../rules/precipitationWindows';
import type { NotificationSettings, RecommendationType, WeatherMessagePart, WeatherSnapshot } from '../types';
import { buildPreparationEvidence, type PreparationReason } from './preparationEvidence';
import { pollenEvidence } from '../services/livingIndexAdvice';
import { drynessLevel, drynessPreparation } from '../rules/dryness';

export interface PreparationCandidate {
  type: RecommendationType;
  reason: string;
  validFrom?: string;
  /** 종료 시각은 포함하지 않는다. */
  validUntil?: string;
  evidence: WeatherMessagePart[];
}

type Category = 'snow' | 'heat' | 'cold' | 'rain' | 'air' | 'uv' | 'humidity';
type Level = 0 | 1 | 2 | 3;

const categoryPriority: Category[] = ['snow', 'heat', 'cold', 'rain', 'air', 'uv', 'humidity'];
const HOUR = 3_600_000;

interface PreparationWindow {
  preparationSettings?: Partial<NotificationSettings>;
  drynessPreparations?: boolean;
  now?: Date;
  end?: number;
  sunriseAt?: string;
  sunsetAt?: string;
  includeSnowUmbrella?: boolean;
}

/** 한 시간대의 위험을 단계로 바꾸고, 같은 역할의 물품은 상위 물품으로 교체한다. */
export function preparationsForSnapshots(
  snapshots: WeatherSnapshot[],
  window: PreparationWindow = {},
): PreparationCandidate[] {
  const settings = window.preparationSettings;
  const enabledReasons: Partial<Record<PreparationReason, boolean>> = {
    rain: settings?.umbrellaEnabled,
    snow: settings?.snowPreparationEnabled ?? settings?.heavySnowEnabled,
    cold: settings?.outerwearEnabled,
    heat: settings?.waterEnabled,
    uv: settings?.uvPreparationEnabled,
    humidity: settings?.drynessEnabled,
  };
  const levels: Record<Category, Level> = {
    snow: 0, heat: 0, cold: 0, rain: 0, air: 0, uv: 0, humidity: 0,
  };
  const first: Record<Category, number> = {
    snow: Infinity, heat: Infinity, cold: Infinity, rain: Infinity,
    air: Infinity, uv: Infinity, humidity: Infinity,
  };
  const itemStart = new Map<RecommendationType, number>();
  const itemEnd = new Map<RecommendationType, number>();
  const itemReason = new Map<RecommendationType, PreparationReason>();
  const evidence = new Map<RecommendationType, WeatherMessagePart[]>();
  let unsuitableParasol = false;
  const maskReasons = new Set<string>();
  for (const raw of snapshots) {
    const item = precipitationDecisionSnapshot(raw, window.now);
    const time = Date.parse(snapshotTime(item));
    const intervalFor = (reason: PreparationReason) => {
      const period = reason === 'rain' || reason === 'snow' ? precipitationPeriod(item) : undefined;
      let start = period ? Date.parse(period.start) : time;
      let end = period ? Date.parse(period.end) : time +
        (item.dataRole === 'OBSERVATION' ? HOUR / 2 : HOUR);
      const validTo = Date.parse(item.validTo ?? '');
      if (!period && Number.isFinite(validTo) && validTo > start) {
        // 기상청의 xx:59:59(또는 .999) 종료를 배타적 시각으로 정규화한다.
        const inclusive = validTo % HOUR >= HOUR - 1_000;
        end = Math.min(end, inclusive ? Math.ceil((validTo + 1) / HOUR) * HOUR : validTo);
      }
      if (reason === 'uv') {
        const sunrise = Date.parse(window.sunriseAt ?? '');
        const sunset = Date.parse(window.sunsetAt ?? '');
        if (Number.isFinite(sunrise)) start = Math.max(start, sunrise);
        if (Number.isFinite(sunset)) end = Math.min(end, sunset);
      }
      end = Math.min(end, window.end ?? Infinity);
      return { start, end };
    };
    const usable = (reason: PreparationReason) => {
      const { start, end } = intervalFor(reason);
      return Number.isFinite(start) && end > start &&
        end > (window.now?.getTime() ?? -Infinity) && start < (window.end ?? Infinity);
    };
    const mark = (category: Category, active: boolean) => {
      if (active && Number.isFinite(time)) first[category] = Math.min(first[category], time);
    };
    const record = (type: RecommendationType, active: boolean, reason: PreparationReason, criterion: string) => {
      // 구 앱의 우산 선택은 대설 알림 선택과 무관하게 눈 대비 우산도 포함한다.
      const legacySnowUmbrella = reason === 'snow' && type === 'UMBRELLA' &&
        settings?.snowPreparationEnabled === undefined && settings?.umbrellaEnabled !== false;
      if (enabledReasons[reason] === false && !legacySnowUmbrella) return;
      const { start, end } = intervalFor(reason);
      if (active && usable(reason)) {
        const parts = buildPreparationEvidence(item, reason, criterion);
        if (!parts.length) return;
        itemEnd.set(type, Math.max(itemEnd.get(type) ?? -Infinity, end));
        if (start < (itemStart.get(type) ?? Infinity)) {
          itemStart.set(type, start);
          itemReason.set(type, reason);
          if (type !== 'MASK') evidence.set(type, parts);
        }
        if (type === 'MASK') {
          const combined = [...(evidence.get(type) ?? []), ...parts];
          evidence.set(type, [...new Map(combined.map((part) => [`${part.role}:${part.source}`, part])).values()]);
        }
      }
    };
    const rainAmount = item.precipitationAmountRange?.min ?? item.precipitationAmount ?? 0;
    const snowAmount = item.snowfallAmountRange?.min ?? item.snowfallAmount ?? 0;
    const rain = usable('rain') && (['RAIN', 'RAIN_SNOW', 'SHOWER'].includes(item.precipitationType ?? '') ||
      (item.precipitationType !== 'SNOW' &&
        ((item.precipitationProbability ?? 0) >= defaultRuleConfig.rain.minProbability ||
          rainAmount >= defaultRuleConfig.rain.minAmount)));
    const snow = usable('snow') && (['SNOW', 'RAIN_SNOW'].includes(item.precipitationType ?? '') ||
      item.snowExpected === true || (item.snowProbability ?? 0) >= 40 || snowAmount > 0);
    const rainLevel = rain
      ? rainAmount >= 15 ? 3 : rainAmount >= 5 || (item.precipitationProbability ?? 0) >= 70 ? 2 : 1
      : 0;
    levels.rain = Math.max(levels.rain, rainLevel) as Level;
    mark('rain', rain);
    record('UMBRELLA', rain || (window.includeSnowUmbrella === true && snow),
      rain ? 'rain' : 'snow', '비·눈·소나기 또는 강수확률·강수량 기준에 따른 강수 대비');
    record('RAINCOAT', rainLevel >= 2, 'rain', '비가 예상되고 1시간 강수량 5mm 이상 또는 강수확률 70% 이상');
    record('RAIN_BOOTS', rainLevel >= 3, 'rain', '비가 예상되고 1시간 강수량 15mm 이상');
    const snowLevel = snow
      ? snowAmount >= 5 ? 3 : snowAmount >= 1 ? 2 : 1
      : 0;
    levels.snow = Math.max(levels.snow, snowLevel) as Level;
    mark('snow', snow);
    record('SLIP_RESISTANT_SHOES', snow, 'snow', '눈·비/눈 또는 눈 예보·눈 판단 지표 40% 이상 또는 신적설 양수');
    record('WINTER_BOOTS', snowLevel >= 2, 'snow', '눈이 예상되고 1시간 신적설 1cm 이상');
    record('SNOW_CHAINS', snowLevel >= 3, 'snow', '눈이 예상되고 1시간 신적설 5cm 이상');
    const uv = usable('uv') ? item.uvIndex ?? 0 : 0;
    levels.uv = Math.max(levels.uv, uv >= 8 ? 3 : uv >= 6 ? 2 : uv >= 3 ? 1 : 0) as Level;
    mark('uv', uv >= 3);
    record('SUNSCREEN', uv >= 3, 'uv', '자외선지수 3 이상');
    record('SUN_HAT', uv >= 6, 'uv', '자외선지수 6 이상');
    record('SUNGLASSES', uv >= 6, 'uv', '자외선지수 6 이상');
    record('PARASOL', uv >= 8, 'uv', '자외선지수 8 이상이며 비·눈·강풍이 없음');
    const thermal = item.kmaApparentTemperature ?? item.apparentTemperature ?? item.temperature;
    if (thermal !== undefined && usable('heat')) {
      levels.heat = Math.max(levels.heat, thermal >= 33 ? 3 : thermal >= 30 ? 2 : thermal >= 26 ? 1 : 0) as Level;
      levels.cold = Math.max(levels.cold, thermal <= 0 ? 3 : thermal <= 10 ? 2 : thermal <= 17 ? 1 : 0) as Level;
      mark('heat', thermal >= 26);
      mark('cold', thermal <= 17);
      const metric = item.kmaApparentTemperature !== undefined || item.apparentTemperature !== undefined ? '체감온도' : '기온';
      record('WATER', thermal >= 26, 'heat', `${metric} 26℃ 이상`);
      record('COOLING_ITEM', thermal >= 30, 'heat', `${metric} 30℃ 이상`);
      record('PORTABLE_FAN', thermal >= 33, 'heat', `${metric} 33℃ 이상`);
      record('LIGHT_OUTERWEAR', thermal <= 17, 'cold', `${metric} 17℃ 이하`);
      record('OUTERWEAR', thermal <= 10, 'cold', `${metric} 10℃ 이하`);
      record('SCARF', thermal <= 0, 'cold', `${metric} 0℃ 이하`);
      record('HAND_WARMER', thermal <= 0, 'cold', `${metric} 0℃ 이하`);
    }
    if (window.drynessPreparations && usable('humidity')) {
      const level = drynessLevel(item.humidity) ?? 0;
      levels.humidity = Math.max(levels.humidity, level) as Level;
      mark('humidity', level > 0);
      // 낮은 단계 물품을 누적하지 않고 해당 시간대의 물품에만 근거를 연결한다.
      const preparation = drynessPreparation(item.humidity);
      if (preparation) record(preparation, true, 'humidity', level === 3
        ? '상대습도 20% 이하: 매우 건조' : level === 2
        ? '상대습도 20% 초과~30% 이하: 건조' : '상대습도 30% 초과~40% 이하: 약한 건조');
    }
    const poorParticles = settings?.maskEnabled !== false && usable('air') && ((item.pm10 ?? 0) >= defaultRuleConfig.airQuality.pm10 ||
      (item.pm25 ?? 0) >= defaultRuleConfig.airQuality.pm25 ||
      /bad|나쁨/i.test(item.pm25ForecastGrade ?? ''));
    const highPollen = (settings?.pollenEnabled ?? settings?.maskEnabled ?? true) && usable('air') && pollenEvidence(item).length > 0;
    if (poorParticles) maskReasons.add('air');
    if (highPollen) maskReasons.add('pollen');
    if (poorParticles || highPollen) levels.air = 1;
    mark('air', poorParticles || highPollen);
    record('MASK', poorParticles || highPollen, 'air', [
      ...(poorParticles ? [`미세먼지 ${defaultRuleConfig.airQuality.pm10}㎍/㎥ 이상 또는 초미세먼지 ${defaultRuleConfig.airQuality.pm25}㎍/㎥ 이상 또는 초미세먼지 예보 나쁨`] : []),
      ...(highPollen ? ['꽃가루 예측 높음 이상'] : []),
    ].join(' 또는 '));
    unsuitableParasol ||= rain || snow || (usable('uv') && (item.windSpeed ?? 0) >= defaultRuleConfig.wind.caution);
  }

  const groups: Record<Category, { base?: RecommendationType; extras: RecommendationType[] }> = {
    humidity: {
      base: levels.humidity === 3 ? 'PORTABLE_HUMIDIFIER'
        : levels.humidity === 2 ? 'HAND_CREAM' : levels.humidity === 1 ? 'LIP_BALM' : undefined,
      extras: [],
    },
    snow: {
      base: levels.snow >= 2 ? 'WINTER_BOOTS' : levels.snow ? 'SLIP_RESISTANT_SHOES' : undefined,
      extras: [
        ...(levels.snow && window.includeSnowUmbrella ? ['UMBRELLA' as const] : []),
        ...(levels.snow >= 3 ? ['SNOW_CHAINS' as const] : []),
      ],
    },
    heat: {
      base: levels.heat ? 'WATER' : undefined,
      extras: levels.heat >= 2
        ? ['COOLING_ITEM', ...(levels.heat >= 3 ? ['PORTABLE_FAN' as const] : [])]
        : [],
    },
    cold: {
      base: levels.cold >= 2 ? 'OUTERWEAR' : levels.cold ? 'LIGHT_OUTERWEAR' : undefined,
      extras: levels.cold >= 3 ? ['SCARF', 'HAND_WARMER'] : [],
    },
    rain: {
      base: levels.rain ? 'UMBRELLA' : undefined,
      extras: levels.rain >= 2
        ? ['RAINCOAT', ...(levels.rain >= 3 && !levels.snow ? ['RAIN_BOOTS' as const] : [])]
        : [],
    },
    air: { base: levels.air ? 'MASK' : undefined, extras: [] },
    uv: {
      base: levels.uv ? 'SUNSCREEN' : undefined,
      extras: levels.uv >= 2
        ? [
            'SUNGLASSES',
            levels.uv >= 3 && !unsuitableParasol ? 'PARASOL' : 'SUN_HAT',
          ]
        : [],
    },
  };
  const output: PreparationCandidate[] = [];
  const add = (category: Category, type: RecommendationType) => {
    if (output.some((candidate) => candidate.type === type)) return;
    const parts = evidence.get(type);
    if (!parts?.length) return;
    output.push({
      type,
      reason: type === 'MASK' && maskReasons.has('pollen')
        ? maskReasons.has('air') ? 'air+pollen' : 'pollen' : itemReason.get(type) ?? category,
      validFrom: Number.isFinite(itemStart.get(type) ?? first[category])
        ? new Date(itemStart.get(type) ?? first[category]).toISOString() : undefined,
      validUntil: new Date(itemEnd.get(type)!).toISOString(),
      evidence: parts,
    });
  };
  // 먼저 각 상황의 필수 물품을 하나씩, 그다음 추가 물품을 배치한다.
  const active = categoryPriority.filter((category) => groups[category].base);
  active.sort((left, right) =>
    levels[right] - levels[left] ||
    first[left] - first[right] ||
    categoryPriority.indexOf(left) - categoryPriority.indexOf(right));
  for (const category of active) add(category, groups[category].base!);
  for (const category of active) {
    for (const type of groups[category].extras) add(category, type);
  }
  return output;
}

/** 한국시간 오늘 남은 예보에서 항목별 대표를 먼저 고르고 남는 칸은 추가 물품으로 채운다. */
export function preparationsForWindow(
  forecast: WeatherForecast,
  now: Date,
  options: { sunriseAt?: string; sunsetAt?: string; allowedRecommendedItems?: RecommendationType[]; drynessPreparations?: boolean; preparationSettings?: Partial<NotificationSettings> } = {},
): PreparationCandidate[] {
  const korea = new Date(now.getTime() + 9 * HOUR);
  const end = Date.UTC(korea.getUTCFullYear(), korea.getUTCMonth(), korea.getUTCDate() + 1) - 9 * HOUR;
  // 같은 시점의 예보 복사본은 hourly의 실제 강수 구간을 우선한다.
  const currentIsCopy = forecast.current.dataRole !== 'OBSERVATION' &&
    forecast.hourly.some((item) => snapshotTime(item) === snapshotTime(forecast.current));
  const snapshots = currentIsCopy ? forecast.hourly : [forecast.current, ...forecast.hourly];
  const candidates = preparationsForSnapshots(snapshots, {
    now, end, ...options, includeSnowUmbrella: true,
  }).filter((item) => options.allowedRecommendedItems === undefined || options.allowedRecommendedItems.includes(item.type));
  const representatives: RecommendationType[][] = [
    ['UMBRELLA', 'SNOW_CHAINS', 'WINTER_BOOTS', 'SLIP_RESISTANT_SHOES', 'RAIN_BOOTS', 'RAINCOAT'],
    ['HAND_WARMER', 'OUTERWEAR', 'LIGHT_OUTERWEAR', 'SCARF'],
    ['PORTABLE_FAN', 'COOLING_ITEM', 'WATER'],
    ['MASK'],
    ['PARASOL', 'SUN_HAT', 'SUNSCREEN', 'SUNGLASSES'],
    ['PORTABLE_HUMIDIFIER', 'HAND_CREAM', 'LIP_BALM'],
  ];
  const severity: Partial<Record<RecommendationType, number>> = {
    HAND_WARMER: 3, OUTERWEAR: 2, LIGHT_OUTERWEAR: 1,
    PORTABLE_FAN: 3, COOLING_ITEM: 2, WATER: 1,
    MASK: 2, PARASOL: 3, SUN_HAT: 2, SUNSCREEN: 1,
    PORTABLE_HUMIDIFIER: 3, HAND_CREAM: 2, LIP_BALM: 1,
  };
  const groups = representatives.map((types, priority) => ({ priority,
    items: types.flatMap((type) => {
      const candidate = candidates.find((item) => item.type === type);
      return candidate ? [candidate] : [];
    }),
  })).filter((group) => group.items.length).sort((left, right) => {
    if (left.priority === 0 || right.priority === 0) return left.priority - right.priority;
    return (severity[right.items[0].type] ?? 0) - (severity[left.items[0].type] ?? 0) || left.priority - right.priority;
  }).map((group) => group.items);
  return [...groups.map((items) => items[0]), ...groups.flatMap((items) => items.slice(1))];
}
