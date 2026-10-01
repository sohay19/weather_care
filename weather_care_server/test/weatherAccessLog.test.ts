import { createExecutionContext, env } from 'cloudflare:test';
import { describe, expect, it, vi } from 'vitest';
import worker from '../src/index';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import { seedCollectedRegion } from './collectedWeatherFixture';

describe('weather access log', () => {
  it('links a device, grid, status and field presence without logging private values', async () => {
    const currentAt = new Date();
    currentAt.setUTCMinutes(0, 0, 0);
    const nextAt = new Date(currentAt.getTime() + 60 * 60 * 1000);
    const current = {
      observedAt: currentAt.toISOString(),
      forecastAt: currentAt.toISOString(),
      temperature: 21,
      apparentTemperature: 22,
      humidity: 70,
      windSpeed: 2,
      skyCondition: '맑음',
    };
    const forecast: WeatherForecast = {
      current,
      hourly: [current, {
        observedAt: nextAt.toISOString(),
        forecastAt: nextAt.toISOString(),
        temperature: 20,
        humidity: 65,
        windSpeed: 3,
        skyCondition: '맑음',
      }],
      daily: [],
      baseDate: '20260930',
      baseTime: '1700',
      dataSource: 'test',
    };
    await seedCollectedRegion(57, 124, forecast);

    const secret = 'a'.repeat(64);
    const log = vi.spyOn(console, 'log').mockImplementation(() => {});
    try {
      const response = await worker.fetch(new Request(
        'https://example.invalid/api/v1/weather/main?nx=57&ny=124&' +
        'latitude=37.123456&longitude=126.987654&regionName=private-location',
        { headers: { Authorization: `Bearer ${secret}` } },
      ), env, createExecutionContext());
      expect(response.status).toBe(200);
      const requestId = response.headers.get('X-Request-Id');
      expect(requestId).toBeTruthy();
      const today = await worker.fetch(new Request(
        'https://example.invalid/api/v1/weather/today?nx=57&ny=124',
        { headers: { Authorization: `Bearer ${secret}` } },
      ), env, createExecutionContext());
      expect(today.status).toBe(200);

      const entries = log.mock.calls.map(([line]) => JSON.parse(String(line)))
        .filter((value) => value.event === 'weather_access');
      const entry = entries
        .find((value) => value.event === 'weather_access');
      expect(entry).toMatchObject({
        requestId,
        route: '/api/v1/weather/main',
        nx: 57,
        ny: 124,
        coordinatesProvided: true,
        status: 200,
        fields: {
          currentTemperature: false,
          currentApparentTemperature: false,
          nextTemperature: true,
          nextApparentTemperature: true,
          nextForecastAt: nextAt.toISOString(),
        },
      });
      expect(entry.deviceTag).toMatch(/^[0-9a-f]{24}$/);
      expect(entries.find((value) => value.route === '/api/v1/weather/today'))
        .toMatchObject({ status: 200, nx: 57, ny: 124, deviceTag: entry.deviceTag });
      const serialized = JSON.stringify(log.mock.calls);
      expect(serialized).not.toContain(secret);
      expect(serialized).not.toContain('37.123456');
      expect(serialized).not.toContain('126.987654');
      expect(serialized).not.toContain('private-location');
    } finally {
      log.mockRestore();
    }
  });

  it('records an unavailable weekly response without reading its body', async () => {
    const log = vi.spyOn(console, 'log').mockImplementation(() => {});
    try {
      const response = await worker.fetch(new Request(
        'https://example.invalid/api/v1/weather/weekly?nx=37&ny=37&installationId=private-installation',
      ), env, createExecutionContext());
      expect(response.status).toBe(503);
      expect(await response.json()).toEqual({ error: 'WEATHER_CACHE_NOT_READY' });
      const entry = log.mock.calls.map(([line]) => JSON.parse(String(line)))
        .find((value) => value.event === 'weather_access');
      expect(entry).toMatchObject({
        route: '/api/v1/weather/weekly',
        nx: 37,
        ny: 37,
        deviceTag: null,
        status: 503,
        fields: { errorCode: 'WEATHER_CACHE_NOT_READY' },
      });
      expect(JSON.stringify(log.mock.calls)).not.toContain('private-installation');
    } finally {
      log.mockRestore();
    }
  });
});
