import { Recommendation } from '../types';

const HEAVY_SNOW_WEIGHT = 100;
const GENERAL_WEIGHT = 80;

export function sortRecommendations(input: Recommendation[]): Recommendation[] {
  return [...input].sort((a, b) => {
    const aw = a.type === 'HEAVY_SNOW_CAUTION' ? HEAVY_SNOW_WEIGHT : GENERAL_WEIGHT;
    const bw = b.type === 'HEAVY_SNOW_CAUTION' ? HEAVY_SNOW_WEIGHT : GENERAL_WEIGHT;
    if (aw !== bw) return bw - aw;
    return b.priority - a.priority;
  });
}

