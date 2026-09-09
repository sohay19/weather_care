import { z } from 'zod';
import {
  AirQualityProvider,
  AirQualitySnapshot,
} from './airQualityProvider';

const AIRKOREA_URL =
  'https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty';
const AIRKOREA_STATION_URL =
  'https://apis.data.go.kr/B552584/MsrstnInfoInqireSvc/getMsrstnList';
const NEARBY_STATION_ATTEMPTS = 5;

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
      })
      .optional(),
  }),
});

interface LocatedStation {
  stationName: string;
  latitude: number;
  longitude: number;
  distanceMeters: number;
}

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

  constructor(options: AirKoreaAirQualityProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher =
      options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.now = options.now ?? (() => new Date());
    this.timeoutMs = options.timeoutMs ?? 6_000;
  }

  async getByRegion(
    _nx: number,
    _ny: number,
    stationName?: string,
  ): Promise<AirQualitySnapshot> {
    this.requireServiceKey();
    if (!stationName?.trim()) {
      throw new AirKoreaAirQualityProviderError(
        'AirKorea station name is not configured',
      );
    }

    return this.getByStation(stationName.trim());
  }

  async getByLocation(
    latitude: number,
    longitude: number,
  ): Promise<AirQualitySnapshot> {
    this.requireServiceKey();
    validateLocation(latitude, longitude);
    const stations = await this.getNearestStations(latitude, longitude);
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

  private async getByStation(
    stationName: string,
  ): Promise<AirQualitySnapshot> {
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
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    const payload: unknown = await response.json();
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
      const observedAt = airKoreaTimeToIso(item.dataTime);
      if (!isRecentObservation(observedAt, this.now())) continue;
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

  private async getNearestStations(
    latitude: number,
    longitude: number,
  ): Promise<LocatedStation[]> {
    const query = new URLSearchParams({
      serviceKey: this.serviceKey,
      returnType: 'json',
      numOfRows: '1000',
      pageNo: '1',
    });
    const response = await this.fetcher(`${AIRKOREA_STATION_URL}?${query}`, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 86_400 },
    });
    const payload: unknown = await response.json();
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
    const items = Array.isArray(body.items) ? body.items : [body.items];
    const stations = items
      .flatMap((item) => {
        const coordinates = stationCoordinates(item.dmX, item.dmY);
        if (!coordinates || !item.stationName.trim()) return [];
        return [{
          stationName: item.stationName.trim(),
          ...coordinates,
          distanceMeters: haversineMeters(
            latitude,
            longitude,
            coordinates.latitude,
            coordinates.longitude,
          ),
        }];
      })
      .sort((left, right) => left.distanceMeters - right.distanceMeters);
    if (stations.length === 0) {
      throw new AirKoreaAirQualityProviderError(
        'AirKorea station service returned no usable coordinates',
      );
    }
    return stations;
  }

  private requireServiceKey(): void {
    if (!this.serviceKey) {
      throw new AirKoreaAirQualityProviderError(
        'AirKorea service key is not configured',
      );
    }
  }
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
  return Number.isFinite(parsed) ? parsed : undefined;
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

function airKoreaTimeToIso(value: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})$/.exec(
    value.trim(),
  );
  if (!match) {
    throw new AirKoreaAirQualityProviderError(
      'AirKorea observation time is invalid',
    );
  }
  return `${match[1]}-${match[2]}-${match[3]}T${match[4]}:${match[5]}:00+09:00`;
}

function isRecentObservation(observedAt: string, now: Date): boolean {
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
