import { defaultRuleConfig } from '../config/ruleConfig';
import type { WeatherForecast } from '../providers/weather/weatherProvider';
import { snapshotTime } from '../rules/timeWindows';
import type { RecommendationType, WeatherSnapshot } from '../types';

export interface PreparationCandidate {
  type: RecommendationType;
  reason: string;
  validFrom?: string;
}

type Category = 'snow' | 'heat' | 'cold' | 'rain' | 'air' | 'uv';
type Level = 0 | 1 | 2 | 3;

const categoryPriority: Category[] = ['snow', 'heat', 'cold', 'rain', 'air', 'uv'];

/** 한 시간대의 위험을 단계로 바꾸고, 같은 역할의 물품은 상위 물품으로 교체한다. */
export function preparationsForSnapshots(
  snapshots: WeatherSnapshot[],
): PreparationCandidate[] {
  const levels: Record<Category, Level> = {
    snow: 0, heat: 0, cold: 0, rain: 0, air: 0, uv: 0,
  };
  const first: Record<Category, number> = {
    snow: Infinity, heat: Infinity, cold: Infinity, rain: Infinity,
    air: Infinity, uv: Infinity,
  };
  const itemStart = new Map<RecommendationType, number>();
  let unsuitableParasol = false;
  for (const item of snapshots) {
    const time = Date.parse(snapshotTime(item));
    const mark = (category: Category, active: boolean) => {
      if (active && Number.isFinite(time)) first[category] = Math.min(first[category], time);
    };
    const record = (type: RecommendationType, active: boolean) => {
      if (active && Number.isFinite(time)) {
        itemStart.set(type, Math.min(itemStart.get(type) ?? Infinity, time));
      }
    };
    const rainAmount = item.precipitationAmountRange?.min ?? item.precipitationAmount ?? 0;
    const snowAmount = item.snowfallAmountRange?.min ?? item.snowfallAmount ?? 0;
    const rain = ['RAIN', 'RAIN_SNOW', 'SHOWER'].includes(item.precipitationType ?? '') ||
      (item.precipitationType !== 'SNOW' &&
        ((item.precipitationProbability ?? 0) >= defaultRuleConfig.rain.minProbability ||
          rainAmount >= defaultRuleConfig.rain.minAmount));
    const snow = ['SNOW', 'RAIN_SNOW'].includes(item.precipitationType ?? '') ||
      item.snowExpected === true || (item.snowProbability ?? 0) >= 40 || snowAmount > 0;
    const rainLevel = rain
      ? rainAmount >= 15 ? 3 : rainAmount >= 5 || (item.precipitationProbability ?? 0) >= 70 ? 2 : 1
      : 0;
    levels.rain = Math.max(levels.rain, rainLevel) as Level;
    mark('rain', rain);
    record('UMBRELLA', rain);
    record('RAINCOAT', rainLevel >= 2);
    record('RAIN_BOOTS', rainLevel >= 3);
    const snowLevel = snow
      ? snowAmount >= 5 ? 3 : snowAmount >= 1 ? 2 : 1
      : 0;
    levels.snow = Math.max(levels.snow, snowLevel) as Level;
    mark('snow', snow);
    record('SLIP_RESISTANT_SHOES', snow);
    record('WINTER_BOOTS', snowLevel >= 2);
    record('SNOW_CHAINS', snowLevel >= 3);
    const uv = item.uvIndex ?? 0;
    levels.uv = Math.max(levels.uv, uv >= 8 ? 3 : uv >= 6 ? 2 : uv >= 3 ? 1 : 0) as Level;
    mark('uv', uv >= 3);
    record('SUNSCREEN', uv >= 3);
    record('SUN_HAT', uv >= 6);
    record('SUNGLASSES', uv >= 6);
    record('PARASOL', uv >= 8);
    const thermal = item.kmaApparentTemperature ?? item.apparentTemperature ?? item.temperature;
    if (thermal !== undefined) {
      levels.heat = Math.max(levels.heat, thermal >= 33 ? 3 : thermal >= 30 ? 2 : thermal >= 26 ? 1 : 0) as Level;
      levels.cold = Math.max(levels.cold, thermal <= 0 ? 3 : thermal <= 10 ? 2 : thermal <= 17 ? 1 : 0) as Level;
      mark('heat', thermal >= 26);
      mark('cold', thermal <= 17);
      record('WATER', thermal >= 26);
      record('COOLING_ITEM', thermal >= 30);
      record('PORTABLE_FAN', thermal >= 33);
      record('LIGHT_OUTERWEAR', thermal <= 17);
      record('OUTERWEAR', thermal <= 10);
      record('SCARF', thermal <= 0);
      record('HAND_WARMER', thermal <= 0);
    }
    const poorParticles = (item.pm10 ?? 0) >= defaultRuleConfig.airQuality.pm10 ||
      (item.pm25 ?? 0) >= defaultRuleConfig.airQuality.pm25 ||
      /bad|나쁨/i.test(item.pm25ForecastGrade ?? '');
    if (poorParticles) levels.air = 1;
    mark('air', poorParticles);
    record('MASK', poorParticles);
    unsuitableParasol ||= rain || snow || (item.windSpeed ?? 0) >= defaultRuleConfig.wind.caution;
  }

  const groups: Record<Category, { base?: RecommendationType; extras: RecommendationType[] }> = {
    snow: {
      base: levels.snow >= 2 ? 'WINTER_BOOTS' : levels.snow ? 'SLIP_RESISTANT_SHOES' : undefined,
      extras: levels.snow >= 3 ? ['SNOW_CHAINS'] : [],
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
    output.push({
      type,
      reason: category,
      validFrom: Number.isFinite(itemStart.get(type) ?? first[category])
        ? new Date(itemStart.get(type) ?? first[category]).toISOString() : undefined,
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

/** 현재부터 3시간 안에 맞닥뜨릴 예보만 체크리스트에 사용한다. */
export function preparationsForWindow(
  forecast: WeatherForecast,
  now: Date,
): PreparationCandidate[] {
  const start = now.getTime();
  const end = start + 3 * 60 * 60 * 1000;
  const snapshots = [forecast.current, ...forecast.hourly].filter((item) => {
    const point = Date.parse(snapshotTime(item));
    return Number.isFinite(point) && point >= start - 60 * 60 * 1000 && point <= end;
  });
  return preparationsForSnapshots(snapshots);
}
