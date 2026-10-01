import type { MiddlewareHandler } from 'hono';
import type { WeatherForecast } from '../providers/weather/weatherProvider';
import { bearerSecret } from '../security/installationAccess';
import type { ServerEnv, TodayWeatherResponse } from '../types';

export interface WeatherAccessFields {
  errorCode?: 'WEATHER_CACHE_NOT_READY' | 'WEATHER_CACHE_UNAVAILABLE';
  cacheUpdatedAt?: string;
  forecastBase?: string;
  currentTemperature?: boolean;
  currentApparentTemperature?: boolean;
  nextForecastAt?: string;
  nextTemperature?: boolean;
  nextApparentTemperature?: boolean;
  nextHumidity?: boolean;
  nextWindSpeed?: boolean;
  hourlyCount?: number;
  weeklyDaysCount?: number;
  weeklyCompleteDaysCount?: number;
}

export type WeatherAccessEnv = {
  Bindings: ServerEnv;
  Variables: { weatherAccessFields?: WeatherAccessFields };
};

const LOGGED_ROUTES = new Set([
  '/api/v1/weather/main',
  '/api/v1/weather/today',
  '/api/v1/weather/weekly',
]);

export const weatherAccessLog: MiddlewareHandler<WeatherAccessEnv> = async (c, next) => {
  if (!LOGGED_ROUTES.has(c.req.path) || c.req.method !== 'GET') {
    await next();
    return;
  }

  const startedAt = Date.now();
  const requestId = crypto.randomUUID();
  let threw = false;
  try {
    await next();
  } catch (error) {
    threw = true;
    throw error;
  } finally {
    if (!threw) c.header('X-Request-Id', requestId);
    try {
      const query = new URL(c.req.url).searchParams;
      const secret = bearerSecret(c.req.header('Authorization'));
      const deviceTag = secret ? await tagForSecret(secret) : null;
      console.log(JSON.stringify({
        event: 'weather_access',
        requestId,
        at: new Date(startedAt).toISOString(),
        route: c.req.path,
        deviceTag,
        nx: gridNumber(query.get('nx'), 60),
        ny: gridNumber(query.get('ny'), 121),
        coordinatesProvided: query.has('latitude') && query.has('longitude'),
        status: threw ? 500 : c.res.status,
        durationMs: Date.now() - startedAt,
        fields: c.get('weatherAccessFields') ?? null,
      }));
    } catch {
      // Logging must never change the weather response.
      console.error(JSON.stringify({ event: 'weather_access_log_failed', requestId }));
    }
  }
};

export function todayWeatherAccessFields(
  response: TodayWeatherResponse,
  cacheUpdatedAt: string,
  forecast: WeatherForecast,
): WeatherAccessFields {
  const next = response.nextForecast;
  return {
    cacheUpdatedAt,
    forecastBase: `${forecast.baseDate}${forecast.baseTime}`,
    currentTemperature: presentNumber(response.current.temperature),
    currentApparentTemperature: presentNumber(
      response.current.kmaApparentTemperature ?? response.current.apparentTemperature,
    ),
    nextForecastAt: next.forecastAt ?? next.observedAt,
    nextTemperature: presentNumber(next.temperature),
    nextApparentTemperature: presentNumber(
      next.kmaApparentTemperature ?? next.apparentTemperature,
    ),
    nextHumidity: presentNumber(next.humidity),
    nextWindSpeed: presentNumber(next.windSpeed),
    hourlyCount: response.hourly.length,
  };
}

function presentNumber(value: number | undefined): boolean {
  return value !== undefined && Number.isFinite(value);
}

function gridNumber(value: string | null, fallback: number): number | null {
  const parsed = Number.parseInt(value ?? String(fallback), 10);
  return Number.isSafeInteger(parsed) ? parsed : null;
}

async function tagForSecret(secret: string): Promise<string> {
  const bytes = new TextEncoder().encode(`weather-access-v1:${secret}`);
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
  return Array.from(digest.slice(0, 12), (byte) => byte.toString(16).padStart(2, '0')).join('');
}
