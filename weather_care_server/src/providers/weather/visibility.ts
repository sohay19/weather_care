import type { CurrentVisibilityObservation } from '../../types';
import type { WeatherForecast } from './weatherProvider';

// ASOS hourly data is requested after a 90-minute publication buffer and
// refreshed hourly, so a usable observation can be almost three hours old.
export const VISIBILITY_MAX_AGE_MS = 3 * 60 * 60 * 1000;
export const VISIBILITY_MAX_DISTANCE_KM = 30;

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
  if (!observation || observation.distanceKm > VISIBILITY_MAX_DISTANCE_KM) {
    return false;
  }
  const observedAt = Date.parse(observation.observedAt);
  const age = now.getTime() - observedAt;
  return (
    Number.isFinite(observedAt) && age >= 0 && age <= VISIBILITY_MAX_AGE_MS
  );
}
