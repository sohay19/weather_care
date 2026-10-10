import {
  kmaApiHubErrorReason,
  kmaApiHubErrorStatus,
} from '../kmaApiHubResponse';
import { providerHttpFailureMessage } from '../providerHttpFailure';
import { providerErrorDiagnostic } from '../../observability/providerErrorDiagnostics';
import { logProviderRequestFailure } from '../../observability/providerRequestDiagnostics';
import type { UltraShortObservation } from './kmaUltraShortObservationProvider';

const GRID_OBSERVATION_URL =
  'https://apihub.kma.go.kr/api/typ01/cgi-bin/url/nph-dfs_odam_grd';
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const GRID_WIDTH = 149;
const GRID_HEIGHT = 253;

export const REQUIRED_GRID_OBSERVATION_VARIABLES = ['T1H', 'REH', 'WSD'] as const;
export const GRID_OBSERVATION_VARIABLES = [
  ...REQUIRED_GRID_OBSERVATION_VARIABLES, 'VEC', 'PTY', 'RN1',
] as const;
const REQUIRED_GRID_VARIABLES = new Set<string>(REQUIRED_GRID_OBSERVATION_VARIABLES);

export type GridObservationVariable = typeof GRID_OBSERVATION_VARIABLES[number];

export interface GridObservationSnapshot {
  observedAt: string;
  fields: Partial<Record<GridObservationVariable, ParsedGrid>>;
  requestedVariables?: readonly GridObservationVariable[];
}

export interface KmaObservationGridPoint {
  nx: number;
  ny: number;
}

interface ProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  timeoutMs?: number;
}

export interface ParsedGrid {
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
    this.timeoutMs = options.timeoutMs ?? 30_000;
  }

  async getAt(
    grids: readonly KmaObservationGridPoint[],
    koreanClock: Date,
    options: { requiredOnly?: boolean } = {},
  ): Promise<Map<string, UltraShortObservation>> {
    if (!this.serviceKey) {
      throw new KmaGridObservationProviderError(
        'KMA APIHub service key is not configured',
      );
    }
    for (const grid of grids) validateGrid(grid);
    if (grids.length === 0) return new Map();
    return observationsFromGridSnapshot(await this.getSnapshot(koreanClock, options), grids);
  }

  async getSnapshot(
    koreanClock: Date,
    options: { requiredOnly?: boolean; seed?: GridObservationSnapshot;
      onField?: (variable: GridObservationVariable, grid: ParsedGrid) => Promise<void> } = {},
  ): Promise<GridObservationSnapshot> {
    if (!this.serviceKey) {
      throw new KmaGridObservationProviderError('KMA APIHub service key is not configured');
    }
    if (!Number.isFinite(koreanClock.getTime()) || koreanClock.getUTCMinutes() % 10 !== 0 ||
        koreanClock.getUTCSeconds() !== 0 || koreanClock.getUTCMilliseconds() !== 0) {
      throw new KmaGridObservationProviderError('KMA observation time is invalid');
    }

    const compactTime = formatCompactKoreanTime(koreanClock);
    const seed = options.seed && Date.parse(options.seed.observedAt) === Date.parse(compactKoreanTimeToIso(compactTime))
      ? options.seed.fields : undefined;
    const variables = options.requiredOnly
      ? REQUIRED_GRID_OBSERVATION_VARIABLES
      : GRID_OBSERVATION_VARIABLES;
    // 첫 파일 자체가 미제공이면 같은 회차의 나머지 요청을 보내지 않는다.
    // 정상 기온 파일은 재사용하므로 준비 확인에 추가 호출이 들지 않는다.
    let temperatureGrid: ParsedGrid;
    try {
      temperatureGrid = seed?.T1H ?? await this.fetchVariable('T1H', compactTime);
      if (!temperatureGrid.values.some(validTemperature)) {
        throw new KmaGridObservationProviderError(
          'KMA grid observation has no usable temperature values',
        );
      }
      if (!seed?.T1H) await options.onField?.('T1H', temperatureGrid);
    } catch (error) {
      console.error(JSON.stringify({
        event: 'grid_observation_required_variable_failed',
        variable: 'T1H',
        targetTime: compactTime,
        ...providerErrorDiagnostic(error),
      }));
      throw error;
    }
    const results = await Promise.allSettled(
      variables.map(async (variable) => {
        const grid = variable === 'T1H' ? temperatureGrid
          : seed?.[variable] ?? await this.fetchVariable(variable, compactTime);
        if (variable !== 'T1H' && !seed?.[variable]) await options.onField?.(variable, grid);
        return [variable, grid] as const;
      }),
    );
    const fields: Array<readonly [GridObservationVariable, ParsedGrid]> = [];
    let requiredFailure: unknown;
    for (const [index, result] of results.entries()) {
      const variable = variables[index];
      if (result.status === 'fulfilled') {
        fields.push(result.value);
      } else if (REQUIRED_GRID_VARIABLES.has(variable)) {
        console.error(JSON.stringify({
          event: 'grid_observation_required_variable_failed',
          variable,
          targetTime: compactTime,
          ...providerErrorDiagnostic(result.reason),
        }));
        requiredFailure ??= result.reason;
      } else {
        console.warn(JSON.stringify({
          event: 'grid_observation_optional_variable_failed',
          variable,
          targetTime: compactTime,
          ...providerErrorDiagnostic(result.reason),
        }));
      }
    }
    if (requiredFailure) throw requiredFailure;
    return { observedAt: compactKoreanTimeToIso(compactTime), fields: Object.fromEntries(fields), requestedVariables: variables };
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
    const startedAt = Date.now();
    const signal = AbortSignal.timeout(this.timeoutMs);
    const context = {
      endpoint: 'GRID_OBSERVATION' as const,
      variable,
      targetTime: compactTime,
      timeoutMs: this.timeoutMs,
    };
    let response: Response;
    try {
      response = await this.fetcher(`${GRID_OBSERVATION_URL}?${query}`, {
        headers: { Accept: 'application/octet-stream, text/plain' },
        signal,
        cf: { cacheEverything: true, cacheTtl: 60 },
      });
    } catch (error) {
      logProviderRequestFailure(error, signal, {
        ...context, phase: 'WAIT_HEADERS', elapsedMs: Date.now() - startedAt,
      });
      throw error;
    }
    let payload: ArrayBuffer;
    try {
      payload = await response.arrayBuffer();
    } catch (error) {
      logProviderRequestFailure(error, signal, {
        ...context, phase: 'READ_BODY', elapsedMs: Date.now() - startedAt,
        httpStatus: response.status,
      });
      throw error;
    }
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

export function observationsFromGridSnapshot(
  snapshot: GridObservationSnapshot,
  grids: readonly KmaObservationGridPoint[],
): Map<string, UltraShortObservation> {
  const valuesByField = new Map(Object.entries(snapshot.fields)) as Map<GridObservationVariable, ParsedGrid>;
  const observedAt = snapshot.observedAt;
  const observations = new Map<string, UltraShortObservation>();
  if (!REQUIRED_GRID_OBSERVATION_VARIABLES.every((field) => valuesByField.has(field))) return observations;
  for (const grid of grids) {
    validateGrid(grid);
    const temperature = valueAt(valuesByField.get('T1H')!, grid);
    const humidity = valueAt(valuesByField.get('REH')!, grid);
    const windSpeed = valueAt(valuesByField.get('WSD')!, grid);
    // 핵심 체감 입력은 같은 발표시각·같은 격자 세 값이 모두 있을 때만 쓴다.
    if (
      !validTemperature(temperature) ||
      !validHumidity(humidity) ||
      !validWindSpeed(windSpeed)
    ) continue;

    const precipitationTypeCode = valuesByField.has('PTY')
      ? valueAt(valuesByField.get('PTY')!, grid) : undefined;
    const precipitationAmount = valuesByField.has('RN1')
      ? valueAt(valuesByField.get('RN1')!, grid) : undefined;
    const windDirection = valuesByField.has('VEC')
      ? valueAt(valuesByField.get('VEC')!, grid) : undefined;
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
      ...(validPrecipitationType(precipitationTypeCode) ? {} : {
        qualityFlags: ['PRECIPITATION_TYPE_UNAVAILABLE'],
      }),
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

export function auditGridObservationSnapshot(snapshot: GridObservationSnapshot) {
  const validators = {
    T1H: validTemperature, REH: validHumidity, WSD: validWindSpeed,
    VEC: validWindDirection, PTY: validPrecipitationType, RN1: validPrecipitationAmount,
  };
  const fields = Object.fromEntries(GRID_OBSERVATION_VARIABLES.map((field) => {
    const values = snapshot.fields[field]?.values;
    const valid = values?.filter(validators[field]).length ?? 0;
    return [field, { storedCells: values?.length ?? 0, validCells: valid,
      sourceMissingCells: values ? GRID_WIDTH * GRID_HEIGHT - valid : undefined,
      fileAvailable: !!values }];
  }));
  let coreValidCells = 0;
  for (let index = 0; index < GRID_WIDTH * GRID_HEIGHT; index++) {
    if (REQUIRED_GRID_OBSERVATION_VARIABLES.every((field) =>
      validators[field](snapshot.fields[field]?.values[index]))) coreValidCells++;
  }
  return { observedAt: snapshot.observedAt, gridCount: GRID_WIDTH * GRID_HEIGHT, fields, coreValidCells };
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
  if (/^\s*#\s*dfs_file_read\s+error\s*\(-1\)\s*$/i.test(payload)) {
    throw new KmaGridObservationProviderError(
      'KMA grid observation file is not available',
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
    const values = lines
      .filter((line) => !line.trim().startsWith('#'))
      .flatMap(numericTokens);
    const expected = GRID_WIDTH * GRID_HEIGHT;
    if (values.length !== expected) {
      throw new KmaGridObservationProviderError(
        `KMA grid observation value count is invalid: ${values.length}/${expected}`,
      );
    }
    return { width: GRID_WIDTH, height: GRID_HEIGHT, values };
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
    .flatMap(numericTokens);
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
