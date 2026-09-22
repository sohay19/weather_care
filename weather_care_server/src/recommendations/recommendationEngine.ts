import {
  LifestyleInsight,
  NotificationSettings,
  Recommendation,
  RecommendationType,
  WeatherRuleFactType,
} from '../types';
import { descriptionFor, titleFor } from './recommendationTemplates';
import { CATALOG_VERSION } from './recommendationTemplates';
import { sortRecommendations } from './recommendationPriority';
import { DECISION_VERSION } from '../rules/weatherRuleEngine';

export const PREPARATION_RECOMMENDATION_CATALOG = 'PREPARATION_15';

export interface RecommendationEngineOptions {
  expandedPreparations?: boolean;
  includeLegacyHeavySnowCaution?: boolean;
}

export function enabledRecommendationTypes(
  settings?: Partial<NotificationSettings>,
): RecommendationType[] {
  return (Object.entries(recommendationTypeSettings(settings)) as
    [RecommendationType, boolean][])
    .filter(([, enabled]) => enabled)
    .map(([type]) => type);
}

const LEGACY_RECOMMENDATIONS: Partial<
  Record<LifestyleInsight['type'], RecommendationType[]>
> = {
  RAIN_GEAR_USEFUL: ['UMBRELLA'],
  STRONG_SUN_EXPOSURE: ['PARASOL'],
  OUTERWEAR_USEFUL: ['OUTERWEAR'],
  MASK_USEFUL: ['MASK'],
  HYDRATION_IMPORTANT: ['WATER'],
  SUNSCREEN_USEFUL: ['SUNSCREEN'],
  VERY_HOT_AND_HUMID: ['WATER'],
  COOLER_THAN_TEMPERATURE: ['OUTERWEAR'],
};

const PREPARATION_RANK: Partial<Record<RecommendationType, number>> = {
  UMBRELLA: 0,
  RAINCOAT: 1,
  RAIN_BOOTS: 2,
  SUNSCREEN: 0,
  PARASOL: 1,
  SUNGLASSES: 2,
  WATER: 0,
  PORTABLE_FAN: 1,
  COOLING_ITEM: 2,
  OUTERWEAR: 0,
  SCARF: 1,
  HAND_WARMER: 2,
  SNOW_CHAINS: 0,
  WINTER_BOOTS: 1,
  POWER_BANK: 2,
};

export function runRecommendationEngine(
  insights: LifestyleInsight[],
  settings?: Partial<NotificationSettings>,
  options: RecommendationEngineOptions = {},
): Recommendation[] {
  const enabled = recommendationTypeSettings(settings);

  const recs: Recommendation[] = [];
  const allInsightTypes = insights.map((item) => item.type);
  for (const insight of insights) {
    const types = recommendationTypesFor(insight, options);
    if (types.length === 0) continue;
    const reasonCodes =
      insight.sourceFacts.length > 0
        ? [...new Set(insight.sourceFacts.map(String))]
        : [insight.type];
    const validFrom = stringContext(insight, 'validFrom');
    const validUntil = stringContext(insight, 'validUntil');
    const actionDeadline = stringContext(insight, 'actionDeadline');
    for (const type of types) {
      recs.push({
        type,
        recommended: enabled[type],
        priority: Math.min(
          100,
          Math.max(
            10,
            insight.score -
              (options.expandedPreparations
                ? (PREPARATION_RANK[type] ?? 0)
                : 0),
          ),
        ),
        title: titleFor(type),
        description: descriptionFor(type, allInsightTypes),
        reasonCodes,
        validFrom,
        validUntil,
        actionDeadline,
        providerRefs: providerRefsFor(insight),
        sourceFields: sourceFieldsFor(insight),
        notificationEligible:
          !['OUTERWEAR', 'SCARF', 'HAND_WARMER'].includes(type) ||
          insight.score >= 70,
        reasons: [reasonLabel(insight.type)],
        decisionVersion: DECISION_VERSION,
        catalogVersion: CATALOG_VERSION,
      });
    }
  }

  // 기본 가드: 우산/양산/선크림은 함께 나올 수 있어도 duplicate는 제거
  const dedup = deduplicate(recs);
  return sortRecommendations(dedup);
}

function recommendationTypeSettings(
  settings?: Partial<NotificationSettings>,
): Record<RecommendationType, boolean> {
  return {
    UMBRELLA: settings?.umbrellaEnabled ?? true,
    RAINCOAT: settings?.umbrellaEnabled ?? true,
    RAIN_BOOTS: settings?.umbrellaEnabled ?? true,
    PARASOL: settings?.parasolEnabled ?? true,
    SUNGLASSES: settings?.parasolEnabled ?? true,
    HEAVY_SNOW_CAUTION: settings?.heavySnowEnabled ?? true,
    OUTERWEAR: settings?.outerwearEnabled ?? true,
    SCARF: settings?.outerwearEnabled ?? true,
    HAND_WARMER: settings?.outerwearEnabled ?? true,
    MASK: settings?.maskEnabled ?? true,
    WATER: settings?.waterEnabled ?? true,
    PORTABLE_FAN: settings?.waterEnabled ?? true,
    COOLING_ITEM: settings?.waterEnabled ?? true,
    SUNSCREEN: settings?.sunscreenEnabled ?? true,
    SNOW_CHAINS: settings?.heavySnowEnabled ?? true,
    POWER_BANK: settings?.heavySnowEnabled ?? true,
    WINTER_BOOTS: settings?.heavySnowEnabled ?? true,
  };
}

function recommendationTypesFor(
  insight: LifestyleInsight,
  options: RecommendationEngineOptions,
): RecommendationType[] {
  const heavySnow = insight.score >= 95;
  if (insight.type === 'SNOW_TRAVEL_CAUTION') {
    if (!options.expandedPreparations) {
      return heavySnow ? ['HEAVY_SNOW_CAUTION'] : [];
    }
    return [
      ...(heavySnow ? ['SNOW_CHAINS' as const] : []),
      'WINTER_BOOTS',
      ...(insight.score >= 70 ? ['POWER_BANK' as const] : []),
      ...(heavySnow && options.includeLegacyHeavySnowCaution
        ? ['HEAVY_SNOW_CAUTION' as const]
        : []),
    ];
  }
  if (!options.expandedPreparations) {
    return LEGACY_RECOMMENDATIONS[insight.type] ?? [];
  }
  switch (insight.type) {
    case 'RAIN_GEAR_USEFUL':
      return [
        'UMBRELLA',
        ...(insight.score >= 70 ? ['RAINCOAT' as const] : []),
        ...(insight.score >= 90 ? ['RAIN_BOOTS' as const] : []),
      ];
    case 'STRONG_SUN_EXPOSURE':
      return [
        'SUNSCREEN',
        ...(insight.score >= 80 ? ['PARASOL' as const] : []),
        ...(insight.score >= 100 ? ['SUNGLASSES' as const] : []),
      ];
    case 'SUNSCREEN_USEFUL':
      return ['SUNSCREEN'];
    case 'HYDRATION_IMPORTANT':
      return [
        'WATER',
        ...(insight.score >= 35 ? ['PORTABLE_FAN' as const] : []),
        ...(insight.score >= 38 ? ['COOLING_ITEM' as const] : []),
      ];
    case 'VERY_HOT_AND_HUMID':
      return ['WATER', 'PORTABLE_FAN', 'COOLING_ITEM'];
    case 'OUTERWEAR_USEFUL':
    case 'COOLER_THAN_TEMPERATURE':
      return [
        'OUTERWEAR',
        ...(insight.score >= 90 ? ['SCARF' as const] : []),
        ...(insight.score >= 95 ? ['HAND_WARMER' as const] : []),
      ];
    case 'MASK_USEFUL':
      return ['MASK'];
    default:
      return [];
  }
}

function stringContext(
  insight: LifestyleInsight,
  key: string,
): string | undefined {
  const value = insight.context?.[key];
  return typeof value === 'string' ? value : undefined;
}

function reasonLabel(type: LifestyleInsight['type']): string {
  return {
    RAIN_GEAR_USEFUL: '비가 예상되는 시간대가 있어요.',
    STRONG_SUN_EXPOSURE: '자외선지수가 높게 예보됐어요.',
    SNOW_TRAVEL_CAUTION: '눈이 예상되는 시간대가 있어요.',
    OUTERWEAR_USEFUL: '기온이 낮거나 예상 체감온도가 낮게 계산됐어요.',
    MASK_USEFUL: '미세먼지나 초미세먼지가 나쁨 단계예요.',
    HYDRATION_IMPORTANT: '예상 체감온도가 높은 시간이 있어요.',
    SUNSCREEN_USEFUL: '자외선지수가 높게 예보됐어요.',
  }[type] ?? '날씨 변화에 대비가 필요해요.';
}

function providerRefsFor(insight: LifestyleInsight): string[] {
  if (
    insight.sourceFacts.some((fact) =>
      [
        WeatherRuleFactType.AIR_QUALITY_BAD,
        WeatherRuleFactType.PM10_HIGH,
        WeatherRuleFactType.PM25_HIGH,
      ].includes(fact),
    )
  ) {
    return ['AIR_KOREA'];
  }
  if (insight.sourceFacts.includes(WeatherRuleFactType.UV_HIGH)) {
    return ['KMA_LIFE_WEATHER_INDEX'];
  }
  return ['KMA_VILLAGE_FORECAST'];
}

function sourceFieldsFor(insight: LifestyleInsight): string[] {
  const fields = new Set<string>();
  for (const fact of insight.sourceFacts) {
    if (
      fact === 'RAIN_LIKELY' ||
      fact === 'HEAVY_RAIN'
    ) {
      fields.add('precipitationProbability');
      fields.add('precipitationType');
      fields.add('precipitationAmountRange');
    }
    if (fact === 'SNOW_LIKELY' || fact === 'HEAVY_SNOW') {
      fields.add('precipitationType');
      fields.add('snowfallAmountRange');
    }
    if (fact === 'UV_HIGH') fields.add('uvIndex');
    if (
      fact === 'TEMPERATURE_LOW' ||
      fact === 'APPARENT_TEMPERATURE_HIGH'
    ) {
      fields.add('temperature');
      fields.add('apparentTemperature');
    }
    if (fact === 'PM10_HIGH') fields.add('pm10');
    if (fact === 'PM25_HIGH') fields.add('pm25');
    if (fact === 'AIR_QUALITY_BAD') fields.add('airQualityGrade');
  }
  return [...fields];
}

function deduplicate(input: Recommendation[]): Recommendation[] {
  const picked = new Map<RecommendationType, Recommendation>();
  for (const rec of input) {
    const existing = picked.get(rec.type);
    if (!existing || rec.priority > existing.priority) {
      picked.set(rec.type, rec);
    }
  }
  return Array.from(picked.values());
}
