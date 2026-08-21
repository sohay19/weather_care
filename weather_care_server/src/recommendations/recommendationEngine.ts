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

const INSIGHT_TO_RECOMMENDATION: Record<string, RecommendationType> = {
  RAIN_GEAR_USEFUL: 'UMBRELLA',
  STRONG_SUN_EXPOSURE: 'PARASOL',
  SNOW_TRAVEL_CAUTION: 'HEAVY_SNOW_CAUTION',
  OUTERWEAR_USEFUL: 'OUTERWEAR',
  MASK_USEFUL: 'MASK',
  HYDRATION_IMPORTANT: 'WATER',
  SUNSCREEN_USEFUL: 'SUNSCREEN',
  VERY_HOT_AND_HUMID: 'WATER',
  COOLER_THAN_TEMPERATURE: 'OUTERWEAR',
};

export function runRecommendationEngine(
  insights: LifestyleInsight[],
  settings?: Partial<NotificationSettings>,
): Recommendation[] {
  const enabled = {
    UMBRELLA: settings?.umbrellaEnabled ?? true,
    PARASOL: settings?.parasolEnabled ?? true,
    HEAVY_SNOW_CAUTION: settings?.heavySnowEnabled ?? true,
    OUTERWEAR: settings?.outerwearEnabled ?? true,
    MASK: settings?.maskEnabled ?? true,
    WATER: settings?.waterEnabled ?? true,
    SUNSCREEN: settings?.sunscreenEnabled ?? true,
  };

  const allTypes = new Set<RecommendationType>([
    'UMBRELLA',
    'PARASOL',
    'HEAVY_SNOW_CAUTION',
    'OUTERWEAR',
    'MASK',
    'WATER',
    'SUNSCREEN',
  ]);

  const recs: Recommendation[] = [];
  for (const insight of insights) {
    const t = INSIGHT_TO_RECOMMENDATION[insight.type];
    if (!t || !allTypes.has(t)) continue;
    if (
      t === 'HEAVY_SNOW_CAUTION' &&
      !insight.sourceFacts.includes(WeatherRuleFactType.HEAVY_SNOW)
    ) {
      continue;
    }
    const reasonCodes =
      insight.sourceFacts.length > 0
        ? [...new Set(insight.sourceFacts.map(String))]
        : [insight.type];
    const validFrom = stringContext(insight, 'validFrom');
    const validUntil = stringContext(insight, 'validUntil');
    const actionDeadline = stringContext(insight, 'actionDeadline');
    recs.push({
      type: t,
      recommended: !!enabled[t],
      priority: Math.min(100, Math.max(10, insight.score)),
      title: titleFor(t),
      description: descriptionFor(t, [insight.type]),
      reasonCodes,
      validFrom,
      validUntil,
      notificationEligible: t !== 'OUTERWEAR' || insight.score >= 70,
      level: recommendationLevel(insight.score),
      score: insight.score,
      reasons: [reasonLabel(insight.type)],
      sourceFields: sourceFieldsFor(insight),
      actionDeadline,
      providerRefs: ['KMA'],
      decisionVersion: DECISION_VERSION,
      catalogVersion: CATALOG_VERSION,
    });
  }

  // 기본 가드: 우산/양산/선크림은 함께 나올 수 있어도 duplicate는 제거
  const dedup = deduplicate(recs);
  return sortRecommendations(dedup);
}

function stringContext(
  insight: LifestyleInsight,
  key: string,
): string | undefined {
  const value = insight.context?.[key];
  return typeof value === 'string' ? value : undefined;
}

function recommendationLevel(
  score: number,
): 'NONE' | 'INFO' | 'CAUTION' | 'WARNING' | 'DANGER' {
  if (score >= 95) return 'DANGER';
  if (score >= 90) return 'WARNING';
  if (score >= 70) return 'CAUTION';
  if (score >= 40) return 'INFO';
  return 'NONE';
}

function reasonLabel(type: LifestyleInsight['type']): string {
  return {
    RAIN_GEAR_USEFUL: '비가 예상되는 시간대가 있어요.',
    STRONG_SUN_EXPOSURE: '햇볕과 더위가 함께 강해요.',
    SNOW_TRAVEL_CAUTION: '눈이 예상되는 시간대가 있어요.',
    OUTERWEAR_USEFUL: '기온이나 체감온도가 낮아요.',
    MASK_USEFUL: '대기질이 좋지 않은 시간이 있어요.',
    HYDRATION_IMPORTANT: '체감온도가 높은 시간이 이어져요.',
    SUNSCREEN_USEFUL: '자외선이 강한 시간이 있어요.',
  }[type] ?? '날씨 변화에 대비가 필요해요.';
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
