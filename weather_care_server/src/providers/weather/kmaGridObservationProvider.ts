import {
  kmaApiHubErrorReason,
  kmaApiHubErrorStatus,
} from '../kmaApiHubResponse';
import { providerHttpFailureMessage } from '../providerHttpFailure';
import type { UltraShortObservation } from './kmaUltraShortObservationProvider';

const GRID_OBSERVATION_URL =
  'https://apihub.kma.go.kr/api/typ01/cgi-bin/url/nph-dfs_odam_grd';
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const GRID_WIDTH = 149;
const GRID_HEIGHT = 253;

export const GRID_OBSERVATION_VARIABLES = [
  'T1H', 'REH', 'WSD', 'VEC', 'PTY', 'RN1',
] as const;

type GridObservationVariable = typeof GRID_OBSERVATION_VARIABLES[number];

export interface KmaObservationGridPoint {
  nx: number;
  ny: number;
}

interface ProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  timeoutMs?: number;
}

interface ParsedGrid {
  width: number;
  height: number;
  values: number[];
}

export class KmaGridObservationProviderError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'KmaGridObservationProviderError';
  }
}

export class KmaGridObservationProvider {
  private readonly serviceKey: string;
  private readonly fetcher: typeof fetch;
  private readonly timeoutMs: number;

  constructor(options: ProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher = options.fetcher ?? globalThis.fetch.bind(globalThis);
    this.timeoutMs = options.timeoutMs ?? 15_000;
  }

  async getAt(
    grids: readonly KmaObservationGridPoint[],
    koreanClock: Date,
  ): Promise<Map<string, UltraShortObservation>> {
    if (!this.serviceKey) {
      throw new KmaGridObservationProviderError(
        'KMA APIHub service key is not configured',
      );
    }
    for (const grid of grids) validateGrid(grid);
    if (grids.length === 0) return new Map();

    const compactTime = formatCompactKoreanTime(koreanClock);
    const fields = await Promise.all(
      GRID_OBSERVATION_VARIABLES.map(async (variable) => [
        variable,
        await this.fetchVariable(variable, compactTime),
      ] as const),
    );
    const valuesByField = new Map(fields);
    const observedAt = compactKoreanTimeToIso(compactTime);
    const observations = new Map<string, UltraShortObservation>();

    for (const grid of grids) {
      const temperature = valueAt(valuesByField.get('T1H')!, grid);
      const humidity = valueAt(valuesByField.get('REH')!, grid);
      const windSpeed = valueAt(valuesByField.get('WSD')!, grid);
      // 핵심 체감 입력은 같은 발표시각·같은 격자 세 값이 모두 있을 때만 쓴다.
      if (
        !validTemperature(temperature) ||
        !validHumidity(humidity) ||
        !validWindSpeed(windSpeed)
      ) continue;

      const precipitationTypeCode = valueAt(valuesByField.get('PTY')!, grid);
      const precipitationAmount = valueAt(valuesByField.get('RN1')!, grid);
      const windDirection = valueAt(valuesByField.get('VEC')!, grid);
      observations.set(gridKey(grid), {
        observedAt,
        rainDetected:
          validPrecipitationType(precipitationTypeCode) &&
          precipitationTypeCode! > 0,
        precipitationAmount: validPrecipitationAmount(precipitationAmount)
          ? precipitationAmount
          : undefined,
        precipitationTypeCode: validPrecipitationType(precipitationTypeCode)
          ? precipitationTypeCode
          : undefined,
        temperature,
        humidity,
        windSpeed,
        windDirection: validWindDirection(windDirection)
          ? windDirection
          : undefined,
        provider: 'KMA_APIHUB_GRID_OBSERVATION',
        sourceLocation: {
          type: 'GRID',
          nx: grid.nx,
          ny: grid.ny,
          locationMatch: 'EXACT_GRID',
        },
      });
    }
    return observations;
  }

  private async fetchVariable(
    variable: GridObservationVariable,
    compactTime: string,
  ): Promise<ParsedGrid> {
    const query = new URLSearchParams({
      tmfc: compactTime,
      vars: variable,
      authKey: this.serviceKey,
    });
    const response = await this.fetcher(`${GRID_OBSERVATION_URL}?${query}`, {
      headers: { Accept: 'application/octet-stream, text/plain' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 600 },
    });
    const payload = await response.arrayBuffer();
    if (!response.ok) {
      throw new KmaGridObservationProviderError(
        await providerHttpFailureMessage(
          response,
          `KMA grid observation ${variable} request`,
          decodeText(payload),
        ),
      );
    }
    return parseKmaGridObservationPayload(payload);
  }
}

export function parseKmaGridObservationPayload(payload: ArrayBuffer): ParsedGrid {
  const binary = parseBinaryGrid(payload);
  if (binary) return binary;
  return parseKmaGridObservation(decodeText(payload));
}

export function parseKmaGridObservation(payload: string): ParsedGrid {
  const apiHubStatus = kmaApiHubErrorStatus(payload);
  if (apiHubStatus !== undefined) {
    const reason = kmaApiHubErrorReason(payload);
    throw new KmaGridObservationProviderError(
      `KMA grid observation failed with status ${apiHubStatus}${
        reason ? `: ${reason}` : ''
      }`,
    );
  }
  const lines = payload.split(/\r?\n/);
  const dimensionIndex = lines.findIndex((line) => {
    if (line.trim().startsWith('#')) return false;
    const dimensions = numericTokens(line);
    return dimensions.length === 2 &&
      Number.isInteger(dimensions[0]) &&
      Number.isInteger(dimensions[1]) &&
      dimensions[0] > 0 && dimensions[1] > 0;
  });
  if (dimensionIndex < 0) {
    throw new KmaGridObservationProviderError(
      'KMA grid observation response has no grid dimensions',
    );
  }
  const [width, height] = numericTokens(lines[dimensionIndex]);
  if (width !== GRID_WIDTH || height !== GRID_HEIGHT) {
    throw new KmaGridObservationProviderError(
      `KMA grid observation dimensions are invalid: ${width}x${height}`,
    );
  }
  const expected = width * height;
  const values = lines.slice(dimensionIndex + 1)
    .filter((line) => !line.trim().startsWith('#'))
    .flatMap(numericTokens)
    .slice(0, expected);
  if (values.length !== expected) {
    throw new KmaGridObservationProviderError(
      `KMA grid observation value count is invalid: ${values.length}/${expected}`,
    );
  }
  return { width, height, values };
}

export function latestGridObservationTime(now: Date): Date {
  const koreanClock = new Date(now.getTime() + KST_OFFSET_MS - 10 * 60 * 1000);
  koreanClock.setUTCMinutes(
    Math.floor(koreanClock.getUTCMinutes() / 10) * 10,
    0,
    0,
  );
  return koreanClock;
}

export function gridObservationKoreanIso(koreanClock: Date): string {
  return compactKoreanTimeToIso(formatCompactKoreanTime(koreanClock));
}

function valueAt(grid: ParsedGrid, point: KmaObservationGridPoint): number | undefined {
  const index = (point.ny - 1) * grid.width + point.nx - 1;
  const value = grid.values[index];
  return value !== undefined && Number.isFinite(value) && value > -900
    ? value
    : undefined;
}

function numericTokens(line: string): number[] {
  return (line.match(/[-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?/g) ?? [])
    .map(Number)
    .filter(Number.isFinite);
}

function parseBinaryGrid(payload: ArrayBuffer): ParsedGrid | undefined {
  if (payload.byteLength < 4) return undefined;
  const view = new DataView(payload);
  for (const littleEndian of [true, false]) {
    const width = view.getUint16(0, littleEndian);
    const height = view.getUint16(2, littleEndian);
    if (width !== GRID_WIDTH || height !== GRID_HEIGHT) continue;
    const count = width * height;
    if (payload.byteLength === 4 + count * 4) {
      const values = Array.from({ length: count }, (_, index) =>
        view.getFloat32(4 + index * 4, littleEndian));
      return { width, height, values };
    }
    if (payload.byteLength === 4 + count * 8) {
      const values = Array.from({ length: count }, (_, index) =>
        view.getFloat64(4 + index * 8, littleEndian));
      return { width, height, values };
    }
  }
  return undefined;
}

function decodeText(payload: ArrayBuffer): string {
  return new TextDecoder('utf-8').decode(payload);
}

function validateGrid(grid: KmaObservationGridPoint): void {
  if (
    !Number.isInteger(grid.nx) || grid.nx < 1 || grid.nx > GRID_WIDTH ||
    !Number.isInteger(grid.ny) || grid.ny < 1 || grid.ny > GRID_HEIGHT
  ) {
    throw new KmaGridObservationProviderError('KMA observation grid is invalid');
  }
}

function validTemperature(value: number | undefined): value is number {
  return value !== undefined && value >= -80 && value <= 60;
}

function validHumidity(value: number | undefined): value is number {
  return value !== undefined && value >= 0 && value <= 100;
}

function validWindSpeed(value: number | undefined): value is number {
  return value !== undefined && value >= 0 && value <= 100;
}

function validWindDirection(value: number | undefined): value is number {
  return value !== undefined && value >= 0 && value <= 360;
}

function validPrecipitationType(value: number | undefined): value is number {
  return value !== undefined && Number.isInteger(value) && value >= 0 && value <= 7;
}

function validPrecipitationAmount(value: number | undefined): value is number {
  return value !== undefined && value >= 0 && value <= 500;
}

function gridKey(grid: KmaObservationGridPoint): string {
  return `${grid.nx}:${grid.ny}`;
}

function formatCompactKoreanTime(koreanClock: Date): string {
  return `${koreanClock.getUTCFullYear()}${String(koreanClock.getUTCMonth() + 1).padStart(2, '0')}${String(koreanClock.getUTCDate()).padStart(2, '0')}${String(koreanClock.getUTCHours()).padStart(2, '0')}${String(koreanClock.getUTCMinutes()).padStart(2, '0')}`;
}

function compactKoreanTimeToIso(value: string): string {
  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}T${value.slice(8, 10)}:${value.slice(10, 12)}:00+09:00`;
}

function normalizeServiceKey(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) return '';
  try {
    return decodeURIComponent(trimmed);
  } catch {
    return trimmed;
  }
}
