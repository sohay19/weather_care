import type { RecommendationType } from '../types';

export function drynessLevel(humidity: number | undefined): 0 | 1 | 2 | 3 | undefined {
  if (humidity === undefined || !Number.isFinite(humidity) || humidity < 0 || humidity > 100) return undefined;
  return humidity <= 20 ? 3 : humidity <= 30 ? 2 : humidity <= 40 ? 1 : 0;
}

export function drynessLabel(humidity: number | undefined): string {
  const level = drynessLevel(humidity);
  return level === undefined ? '자료 없음' : ['건조하지 않음', '약한 건조', '건조', '매우 건조'][level];
}

export function drynessPreparation(humidity: number | undefined): RecommendationType | undefined {
  switch (drynessLevel(humidity)) {
    case 1: return 'LIP_BALM';
    case 2: return 'HAND_CREAM';
    case 3: return 'PORTABLE_HUMIDIFIER';
    default: return undefined;
  }
}

export function isDrynessPreparation(type: RecommendationType): boolean {
  return type === 'LIP_BALM' || type === 'HAND_CREAM' || type === 'PORTABLE_HUMIDIFIER';
}
