import { LifestyleInsight, Recommendation, NotificationSettings, RecommendationType } from '../types';
import { descriptionFor, titleFor } from './recommendationTemplates';
import { sortRecommendations } from './recommendationPriority';

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
  LAUNDRY_GOOD: 'PARASOL',
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
    const reason = [insight.type];
    recs.push({
      type: t,
      recommended: !!enabled[t],
      priority: Math.min(100, Math.max(10, insight.score)),
      title: titleFor(t),
      description: descriptionFor(t, [insight.type]),
      reasonCodes: reason,
      validFrom: undefined,
      validUntil: undefined,
      notificationEligible: t !== 'OUTERWEAR' || insight.score >= 70,
    });
  }

  // 기본 가드: 우산/양산/선크림은 함께 나올 수 있어도 duplicate는 제거
  const dedup = deduplicate(recs);
  return sortRecommendations(dedup);
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

