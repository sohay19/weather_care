import { z } from 'zod';
import { kmaGridCoordinates } from '../../regions/kmaGridCoordinates';
import {
  AirQualityProvider,
  AirQualitySnapshot,
} from './airQualityProvider';

const AIRKOREA_URL =
  'https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty';
const AIRKOREA_PROVINCE_URL =
  'https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getCtprvnRltmMesureDnsty';
const AIRKOREA_STATION_URL =
  'https://apis.data.go.kr/B552584/MsrstnInfoInqireSvc/getMsrstnList';
export const NEARBY_STATION_ATTEMPTS = 5;
export const AIRKOREA_PROVINCES = Object.freeze([
  '서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종',
  '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
]);
const STATION_PAGE_SIZE = 1000;
const MAX_STATION_PAGES = 10;

const airItemSchema = z.object({
  stationName: z.coerce.string().optional(),
  dataTime: z.coerce.string(),
  pm10Value: z.union([z.string(), z.number(), z.null()]).optional(),
  pm25Value: z.union([z.string(), z.number(), z.null()]).optional(),
  pm10Grade: z.union([z.string(), z.number(), z.null()]).optional(),
  pm25Grade: z.union([z.string(), z.number(), z.null()]).optional(),
  pm10Grade1h: z.union([z.string(), z.number(), z.null()]).optional(),
  pm25Grade1h: z.union([z.string(), z.number(), z.null()]).optional(),
  o3Value: z.union([z.string(), z.number(), z.null()]).optional(),
  o3Grade: z.union([z.string(), z.number(), z.null()]).optional(),
});

const airResponseSchema = z.object({
  response: z.object({
    header: z.object({
      resultCode: z.coerce.string(),
      resultMsg: z.coerce.string(),
    }),
    body: z
      .object({
        items: z.union([airItemSchema, z.array(airItemSchema)]),
      })
      .optional(),
  }),
});

const stationItemSchema = z.object({
  stationName: z.coerce.string(),
  dmX: z.union([z.string(), z.number(), z.null()]).optional(),
  dmY: z.union([z.string(), z.number(), z.null()]).optional(),
});

const stationResponseSchema = z.object({
  response: z.object({
    header: z.object({
      resultCode: z.coerce.string(),
      resultMsg: z.coerce.string(),
    }),
    body: z
      .object({
        items: z.union([stationItemSchema, z.array(stationItemSchema)]),
        totalCount: z.coerce.number().int().nonnegative(),
        pageNo: z.coerce.number().int().positive(),
        numOfRows: z.coerce.number().int().positive(),
      })
      .optional(),
  }),
});

export const airStationCatalogSchema = z.object({
  fetchedAt: z.string().datetime(),
  stations: z.array(z.object({
    stationName: z.string().trim().min(1),
    latitude: z.number().min(30).max(44),
    longitude: z.number().min(120).max(134),
  })).min(1),
});

export type AirStationCatalog = z.infer<typeof airStationCatalogSchema>;

export type LocatedStation = AirStationCatalog['stations'][number] & {
  distanceMeters: number;
};

const portalErrorSchema = z.object({
  OpenAPI_ServiceResponse: z.object({
    cmmMsgHeader: z.object({
      errMsg: z.coerce.string(),
      returnAuthMsg: z.coerce.string(),
      returnReasonCode: z.coerce.string(),
    }),
  }),
});

interface AirKoreaAirQualityProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  now?: () => Date;
  timeoutMs?: number;
  signal?: AbortSignal;
}

export class AirKoreaAirQualityProviderError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AirKoreaAirQualityProviderError';
  }
}

export class AirKoreaAirQualityProvider implements AirQualityProvider {
  private readonly serviceKey: string;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;
  private readonly timeoutMs: number;
  private readonly signal?: AbortSignal;

  constructor(options: AirKoreaAirQualityProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher =
      options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.now = options.now ?? (() => new Date());
    this.timeoutMs = options.timeoutMs ?? 6_000;
    this.signal = options.signal;
  }

  async getByRegion(
    nx: number,
    ny: number,
    stationName?: string,
  ): Promise<AirQualitySnapshot> {
    this.requireServiceKey();
    if (!stationName?.trim()) {
      const coordinates = kmaGridCoordinates(nx, ny);
      if (!coordinates) throw new AirKoreaAirQualityProviderError('AirKorea grid is invalid');
      return this.getByLocation(coordinates.latitude, coordinates.longitude);
    }

    return this.getByStation(stationName.trim());
  }

  async getByLocation(
    latitude: number,
    longitude: number,
  ): Promise<AirQualitySnapshot> {
    this.requireServiceKey();
    validateLocation(latitude, longitude);
    const stations = nearestAirStations(await this.getStationCatalog(), latitude, longitude);
    let lastError: unknown;
    for (const station of stations.slice(0, NEARBY_STATION_ATTEMPTS)) {
      try {
        return await this.getByStation(station.stationName);
      } catch (error) {
        lastError = error;
      }
    }
    throw new AirKoreaAirQualityProviderError(
      lastError instanceof Error
        ? lastError.message
        : 'AirKorea returned no nearby station measurements',
    );
  }

  async getByStation(
    stationName: string,
  ): Promise<AirQualitySnapshot> {
    this.requireServiceKey();
    const query = new URLSearchParams({
      serviceKey: this.serviceKey,
      returnType: 'json',
      numOfRows: '6',
      pageNo: '1',
      stationName,
      dataTerm: 'DAILY',
      ver: '1.3',
    });
    const response = await this.fetcher(`${AIRKOREA_URL}?${query}`, {
      headers: { Accept: 'application/json' },
      signal: this.requestSignal(),
    });
    const payload = await boundedJson(response);
    const portalError = portalErrorSchema.safeParse(payload);
    if (portalError.success) {
      const header = portalError.data.OpenAPI_ServiceResponse.cmmMsgHeader;
      throw new AirKoreaAirQualityProviderError(
        `AirKorea authorization failed ${header.returnReasonCode}: ${header.errMsg}`,
      );
    }
    if (!response.ok) {
      throw new AirKoreaAirQualityProviderError(
        `AirKorea request failed with status ${response.status}`,
      );
    }

    const parsed = airResponseSchema.safeParse(payload);
    if (!parsed.success) {
      throw new AirKoreaAirQualityProviderError(
        'AirKorea response schema is invalid',
      );
    }

    const { header, body } = parsed.data.response;
    if (header.resultCode !== '00') {
      throw new AirKoreaAirQualityProviderError(
        `AirKorea returned ${header.resultCode}: ${header.resultMsg}`,
      );
    }
    if (!body) {
      throw new AirKoreaAirQualityProviderError('AirKorea returned no body');
    }

    const items = Array.isArray(body.items) ? body.items : [body.items];
    for (const item of items) {
      if (item.stationName?.trim() && item.stationName.trim() !== stationName) continue;
      const observedAt = airKoreaTimeToIso(item.dataTime);
      if (!observedAt) continue;
      if (!isRecentAirObservation(observedAt, this.now())) continue;
      const pm10 = numericValue(item.pm10Value);
      const pm25 = numericValue(item.pm25Value);
      const ozone = numericValue(item.o3Value);
      if (pm10 === undefined && pm25 === undefined && ozone === undefined) {
        continue;
      }

      return {
        observedAt,
        stationName: item.stationName?.trim() || stationName,
        pm10,
        pm25,
        airQualityGrade: worstGrade([
          item.pm10Grade1h ?? item.pm10Grade,
          item.pm25Grade1h ?? item.pm25Grade,
        ]),
        ozone,
        ozoneGrade: gradeLabel(item.o3Grade),
        provider: 'AIRKOREA',
      };
    }

    throw new AirKoreaAirQualityProviderError(
      'AirKorea returned no usable measurements',
    );
  }

  async getProvinceMeasurements(province: string): Promise<AirQualitySnapshot[]> {
    this.requireServiceKey();
    if (!AIRKOREA_PROVINCES.includes(province)) {
      throw new AirKoreaAirQualityProviderError('Unsupported AirKorea province');
    }
    const query = new URLSearchParams({
      serviceKey: this.serviceKey,
      returnType: 'json',
      numOfRows: '1000',
      pageNo: '1',
      sidoName: province,
      ver: '1.3',
    });
    const response = await this.fetcher(`${AIRKOREA_PROVINCE_URL}?${query}`, {
      headers: { Accept: 'application/json' },
      signal: this.requestSignal(),
    });
    const payload = await boundedJson(response);
    const parsed = airResponseSchema.safeParse(payload);
    if (!parsed.success || !response.ok) {
      throw new AirKoreaAirQualityProviderError('AirKorea province response is invalid');
    }
    const { header, body } = parsed.data.response;
    if (header.resultCode !== '00' || !body) {
      throw new AirKoreaAirQualityProviderError(
        `AirKorea province returned ${header.resultCode}: ${header.resultMsg}`,
      );
    }
    const items = Array.isArray(body.items) ? body.items : [body.items];
    const observations = items.flatMap((item) => {
      const stationName = item.stationName?.trim();
      const observedAt = airKoreaTimeToIso(item.dataTime);
      if (!stationName || !observedAt || !isRecentAirObservation(observedAt, this.now())) return [];
      const pm10 = numericValue(item.pm10Value);
      const pm25 = numericValue(item.pm25Value);
      const ozone = numericValue(item.o3Value);
      if (pm10 === undefined && pm25 === undefined && ozone === undefined) return [];
      return [{
        observedAt, stationName, pm10, pm25,
        airQualityGrade: worstGrade([item.pm10Grade1h ?? item.pm10Grade,
          item.pm25Grade1h ?? item.pm25Grade]),
        ozone, ozoneGrade: gradeLabel(item.o3Grade), provider: 'AIRKOREA' as const,
      }];
    });
    if (observations.length === 0) {
      throw new AirKoreaAirQualityProviderError(
        `AirKorea province returned no usable measurements: ${province}`,
      );
    }
    return observations;
  }

  async getStationCatalog(): Promise<AirStationCatalog> {
    this.requireServiceKey();
    const items: z.infer<typeof stationItemSchema>[] = [];
    let expectedTotal: number | undefined;
    for (let pageNo = 1; pageNo <= MAX_STATION_PAGES; pageNo++) {
      const page = await this.getStationPage(pageNo);
      const rows = Array.isArray(page.items) ? page.items : [page.items];
      if (page.pageNo !== pageNo || (expectedTotal !== undefined && expectedTotal !== page.totalCount)) {
        throw new AirKoreaAirQualityProviderError('AirKorea station response pagination is invalid');
      }
      expectedTotal = page.totalCount;
      items.push(...rows);
      if (items.length === expectedTotal) break;
      if (items.length > expectedTotal || rows.length === 0 || pageNo === MAX_STATION_PAGES) {
        throw new AirKoreaAirQualityProviderError('AirKorea station response is incomplete');
      }
    }
    const stations = items.flatMap((item) => {
      const coordinates = stationCoordinates(item.dmX, item.dmY);
      if (!coordinates || !item.stationName.trim()) return [];
      return [{ stationName: item.stationName.trim(), ...coordinates }];
    });
    if (stations.length === 0) {
      throw new AirKoreaAirQualityProviderError('AirKorea station service returned no usable coordinates');
    }
    return { fetchedAt: this.now().toISOString(), stations };
  }

  private async getStationPage(pageNo: number) {
    const query = new URLSearchParams({
      serviceKey: this.serviceKey,
      returnType: 'json',
      numOfRows: String(STATION_PAGE_SIZE),
      pageNo: String(pageNo),
    });
    const response = await this.fetcher(`${AIRKOREA_STATION_URL}?${query}`, {
      headers: { Accept: 'application/json' },
      signal: this.requestSignal(),
    });
    const payload = await boundedJson(response);
    const portalError = portalErrorSchema.safeParse(payload);
    if (portalError.success) {
      const header = portalError.data.OpenAPI_ServiceResponse.cmmMsgHeader;
      throw new AirKoreaAirQualityProviderError(
        `AirKorea station authorization failed ${header.returnReasonCode}: ${header.errMsg}`,
      );
    }
    if (!response.ok) {
      throw new AirKoreaAirQualityProviderError(
        `AirKorea station request failed with status ${response.status}`,
      );
    }
    const parsed = stationResponseSchema.safeParse(payload);
    if (!parsed.success) {
      throw new AirKoreaAirQualityProviderError(
        'AirKorea station response schema is invalid',
      );
    }
    const { header, body } = parsed.data.response;
    if (header.resultCode !== '00') {
      throw new AirKoreaAirQualityProviderError(
        `AirKorea station service returned ${header.resultCode}: ${header.resultMsg}`,
      );
    }
    if (!body) {
      throw new AirKoreaAirQualityProviderError(
        'AirKorea station service returned no body',
      );
    }
    return body;
  }

  private requireServiceKey(): void {
    if (!this.serviceKey) {
      throw new AirKoreaAirQualityProviderError(
        'AirKorea service key is not configured',
      );
    }
  }

  private requestSignal(): AbortSignal {
    const timeout = AbortSignal.timeout(this.timeoutMs);
    return this.signal ? AbortSignal.any([this.signal, timeout]) : timeout;
  }
}

async function boundedJson(response: Response): Promise<unknown> {
  if (!response.ok) {
    await response.body?.cancel();
    throw new AirKoreaAirQualityProviderError(`AirKorea request failed with status ${response.status}`);
  }
  const reader = response.body?.getReader();
  if (!reader) throw new AirKoreaAirQualityProviderError('AirKorea returned no body');
  const decoder = new TextDecoder();
  let size = 0;
  let text = '';
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      size += chunk.value.byteLength;
      if (size > 2 * 1024 * 1024) {
        await reader.cancel();
        throw new AirKoreaAirQualityProviderError('AirKorea response size is invalid');
      }
      text += decoder.decode(chunk.value, { stream: true });
    }
    return JSON.parse(text + decoder.decode()) as unknown;
  } finally {
    reader.releaseLock();
  }
}

export function nearestAirStations(
  catalog: AirStationCatalog,
  latitude: number,
  longitude: number,
): LocatedStation[] {
  validateLocation(latitude, longitude);
  const seen = new Set<string>();
  return catalog.stations.map((station) => ({
    ...station,
    distanceMeters: haversineMeters(latitude, longitude, station.latitude, station.longitude),
  })).sort((left, right) => left.distanceMeters - right.distanceMeters)
    .filter((station) => {
      if (seen.has(station.stationName)) return false;
      seen.add(station.stationName);
      return true;
    }).slice(0, NEARBY_STATION_ATTEMPTS);
}

function stationCoordinates(
  dmX: string | number | null | undefined,
  dmY: string | number | null | undefined,
): { latitude: number; longitude: number } | undefined {
  const first = numericValue(dmX);
  const second = numericValue(dmY);
  if (first === undefined || second === undefined) return undefined;
  if (isLatitude(first) && isLongitude(second)) {
    return { latitude: first, longitude: second };
  }
  if (isLongitude(first) && isLatitude(second)) {
    return { latitude: second, longitude: first };
  }
  return undefined;
}

function isLatitude(value: number): boolean {
  return value >= 30 && value <= 44;
}

function isLongitude(value: number): boolean {
  return value >= 120 && value <= 134;
}

function validateLocation(latitude: number, longitude: number): void {
  if (!isLatitude(latitude) || !isLongitude(longitude)) {
    throw new AirKoreaAirQualityProviderError(
      'Location is outside the supported Korean air-quality area',
    );
  }
}

function haversineMeters(
  latitude: number,
  longitude: number,
  targetLatitude: number,
  targetLongitude: number,
): number {
  const radians = Math.PI / 180;
  const latitudeDelta = (targetLatitude - latitude) * radians;
  const longitudeDelta = (targetLongitude - longitude) * radians;
  const leftLatitude = latitude * radians;
  const rightLatitude = targetLatitude * radians;
  const a = Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(leftLatitude) * Math.cos(rightLatitude) *
      Math.sin(longitudeDelta / 2) ** 2;
  return 2 * 6_371_008.8 * Math.asin(Math.min(1, Math.sqrt(a)));
}

function numericValue(value: unknown): number | undefined {
  if (value === undefined || value === null) return undefined;
  const normalized = String(value).trim();
  if (!normalized || normalized === '-') return undefined;
  const parsed = Number(normalized);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : undefined;
}

function worstGrade(values: unknown[]): string | undefined {
  const grades = values
    .map((value) => numericValue(value))
    .filter((value): value is number => value !== undefined);
  if (grades.length === 0) return undefined;
  return gradeLabel(Math.max(...grades));
}

function gradeLabel(value: unknown): string | undefined {
  const grade = numericValue(value);
  return {
    1: 'Good',
    2: 'Moderate',
    3: 'Bad',
    4: 'Very Bad',
  }[grade ?? 0];
}

function airKoreaTimeToIso(value: string): string | undefined {
  const match = /^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})$/.exec(
    value.trim(),
  );
  if (!match) {
    return undefined;
  }
  return `${match[1]}-${match[2]}-${match[3]}T${match[4]}:${match[5]}:00+09:00`;
}

export function isRecentAirObservation(observedAt: string, now: Date): boolean {
  const timestamp = Date.parse(observedAt);
  if (!Number.isFinite(timestamp)) return false;
  const age = now.getTime() - timestamp;
  return age >= -60 * 60 * 1000 && age <= 4 * 60 * 60 * 1000;
}

function normalizeServiceKey(value: string): string {
  const trimmed = value.trim();
  try {
    return decodeURIComponent(trimmed);
  } catch {
    return trimmed;
  }
}
