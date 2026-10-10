import type { CurrentVisibilityObservation } from '../../types';
import type { WeatherForecast } from './weatherProvider';

// 직전 정시 자료를 사용하고, 수집 실패 시 3시간 이내의 이전 값을 보존한다.
export const VISIBILITY_MAX_AGE_MS = 3 * 60 * 60 * 1000;

// APIHub 요청용 한국 시계: 13:00~13:59에는 12:00 회차를 선택한다.
export function latestVisibilityKoreanHour(now: Date): Date {
  const hour = new Date(now.getTime() + 9 * 3_600_000 - 3_600_000);
  hour.setUTCMinutes(0, 0, 0);
  return hour;
}

export function enrichForecastWithVisibility(
  forecast: WeatherForecast,
  observation: CurrentVisibilityObservation | undefined,
  now = new Date(),
): WeatherForecast {
  if (!usableVisibilityObservation(observation, now)) return forecast;
  return {
    ...forecast,
    current: {
      ...forecast.current,
      visibilityMeters: observation.visibilityMeters,
      visibilityObservedAt: observation.observedAt,
      visibilityStationId: observation.stationId,
      visibilityStationDistanceKm: observation.distanceKm,
    },
  };
}

export function usableVisibilityObservation(
  observation: CurrentVisibilityObservation | undefined,
  now = new Date(),
): observation is CurrentVisibilityObservation {
  if (!observation || !Number.isFinite(observation.distanceKm) || observation.distanceKm < 0 ||
      !Number.isFinite(observation.visibilityMeters) || observation.visibilityMeters < 0) {
    return false;
  }
  const observedAt = Date.parse(observation.observedAt);
  const age = now.getTime() - observedAt;
  const latestAllowed = latestVisibilityKoreanHour(now).getTime() - 9 * 3_600_000;
  return (
    Number.isFinite(observedAt) && observedAt <= latestAllowed && age <= VISIBILITY_MAX_AGE_MS
  );
}
