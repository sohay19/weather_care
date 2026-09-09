import { OfficialRoadControl } from '../../types';

const DEFAULT_RADIUS_METERS = 3_000;
const ITS_EVENT_URL = 'https://openapi.its.go.kr:9443/eventInfo';

interface ItsRoadControlProviderOptions {
  apiKey?: string;
  relayUrl?: string;
  relayToken?: string;
  fetcher?: typeof fetch;
  now?: () => Date;
  radiusMeters?: number;
  timeoutMs?: number;
}

export interface ItsRoadControlEnvironment {
  ITS_API_KEY?: string;
  ITS_RELAY_URL?: string;
  ITS_RELAY_TOKEN?: string;
}

interface ItsEventItem {
  type?: unknown;
  eventType?: unknown;
  eventDetailType?: unknown;
  startDate?: unknown;
  coordX?: unknown;
  coordY?: unknown;
  linkId?: unknown;
  roadName?: unknown;
  roadNo?: unknown;
  roadDrcType?: unknown;
  lanesBlockType?: unknown;
  lanesBlocked?: unknown;
  message?: unknown;
  endDate?: unknown;
}

export class ItsRoadControlProvider {
  private readonly apiKey?: string;
  private readonly relayEndpoint?: string;
  private readonly relayToken?: string;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;
  private readonly radiusMeters: number;
  private readonly timeoutMs: number;

  constructor(options: ItsRoadControlProviderOptions) {
    const apiKey = options.apiKey?.trim();
    const relayUrl = options.relayUrl?.trim();
    const relayToken = options.relayToken?.trim();
    if ((relayUrl && !relayToken) || (!relayUrl && relayToken)) {
      throw new Error('ITS relay is not configured completely');
    }
    if (!apiKey && !relayUrl) {
      throw new Error('ITS road control provider is not configured');
    }
    this.apiKey = apiKey;
    this.relayEndpoint = relayUrl ? relayEndpoint(relayUrl) : undefined;
    this.relayToken = relayToken;
    this.fetcher =
      options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.now = options.now ?? (() => new Date());
    this.radiusMeters = options.radiusMeters ?? DEFAULT_RADIUS_METERS;
    this.timeoutMs = options.timeoutMs ?? 10_000;
  }

  async getNearestActiveControl(
    latitude: number,
    longitude: number,
  ): Promise<OfficialRoadControl | undefined> {
    const bounds = boundingBox(latitude, longitude, this.radiusMeters);
    const request = this.relayEndpoint
      ? relayRequest(this.relayEndpoint, this.relayToken!, bounds)
      : directRequest(this.apiKey!, bounds);

    let response: Response;
    try {
      response = await this.fetcher(request.url, {
        ...request.init,
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (error) {
      if (error instanceof Error && error.name === 'TimeoutError') {
        throw new ItsRoadControlProviderError(
          'ITS road control request timed out',
        );
      }
      throw new ItsRoadControlProviderError(
        'ITS road control network request failed',
      );
    }
    if (!response.ok) {
      throw new Error(`ITS road control request failed: ${response.status}`);
    }
    let payload: unknown;
    try {
      payload = await response.json();
    } catch {
      throw new Error('ITS road control response is not JSON');
    }

    return parseItsRoadControls(payload, {
      latitude,
      longitude,
      radiusMeters: this.radiusMeters,
      now: this.now(),
    })[0];
  }
}

export function itsRoadControlProviderFromEnvironment(
  environment: ItsRoadControlEnvironment,
): ItsRoadControlProvider | undefined {
  const relayUrl = environment.ITS_RELAY_URL?.trim();
  const relayToken = environment.ITS_RELAY_TOKEN?.trim();
  if (relayUrl && relayToken) {
    return new ItsRoadControlProvider({ relayUrl, relayToken });
  }
  const apiKey = environment.ITS_API_KEY?.trim();
  return apiKey ? new ItsRoadControlProvider({ apiKey }) : undefined;
}

export function hasItsRoadControlConfiguration(
  environment: ItsRoadControlEnvironment,
): boolean {
  const relayConfigured = Boolean(
    environment.ITS_RELAY_URL?.trim() &&
      environment.ITS_RELAY_TOKEN?.trim(),
  );
  return relayConfigured || Boolean(environment.ITS_API_KEY?.trim());
}

class ItsRoadControlProviderError extends Error {
  readonly providerFailureDetail = 'ROAD_CONTROL_FETCH_FAILED' as const;

  constructor(message: string) {
    super(message);
    this.name = 'ItsRoadControlProviderError';
  }
}

export function parseItsRoadControls(
  payload: unknown,
  options: {
    latitude: number;
    longitude: number;
    radiusMeters?: number;
    now: Date;
  },
): OfficialRoadControl[] {
  const root = record(payload);
  const response = record(root.response ?? root);
  const header = record(response.header);
  const resultCode = text(header.resultCode ?? response.resultCode);
  if (resultCode !== '0') {
    throw new Error(
      `ITS road control provider error: ${text(header.resultMsg ?? response.resultMsg) || resultCode || 'invalid response'}`,
    );
  }

  const body = record(response.body);
  const itemValue = record(body.items).item ?? body.items ?? response.items;
  const items = Array.isArray(itemValue)
    ? itemValue
    : itemValue === undefined || itemValue === null
      ? []
      : [itemValue];
  const radiusMeters = options.radiusMeters ?? DEFAULT_RADIUS_METERS;

  return items
    .map((value) => roadControlFromItem(record(value) as ItsEventItem, options))
    .filter((value): value is OfficialRoadControl => value !== undefined)
    .filter((value) => value.distanceMeters <= radiusMeters)
    .sort((left, right) => {
      const kindDifference = controlRank(right.controlKind) - controlRank(left.controlKind);
      if (kindDifference !== 0) return kindDifference;
      return left.distanceMeters - right.distanceMeters;
    });
}

function roadControlFromItem(
  item: ItsEventItem,
  options: { latitude: number; longitude: number; now: Date },
): OfficialRoadControl | undefined {
  const startedAt = parseKoreanDate(text(item.startDate));
  if (!startedAt || startedAt.getTime() > options.now.getTime()) return undefined;
  const rawEndDate = text(item.endDate);
  const endsAt = rawEndDate ? parseKoreanDate(rawEndDate) : undefined;
  if (rawEndDate && !endsAt) return undefined;
  if (endsAt && endsAt.getTime() <= options.now.getTime()) return undefined;

  const latitude = number(item.coordY);
  const longitude = number(item.coordX);
  if (latitude === undefined || longitude === undefined) return undefined;

  const lanesBlockType = text(item.lanesBlockType);
  const lanesBlocked = text(item.lanesBlocked);
  const message = text(item.message);
  if (!hasExplicitControl(lanesBlockType, lanesBlocked, message)) return undefined;

  const roadName = text(item.roadName);
  const linkId = text(item.linkId);
  const eventType = text(item.eventType);
  const eventDetailType = text(item.eventDetailType);
  const direction = text(item.roadDrcType);
  const eventKey = [
    linkId || `${longitude.toFixed(6)},${latitude.toFixed(6)}`,
    text(item.startDate),
    eventType,
    eventDetailType,
  ].join('|');
  const controlKind = isFullControl(lanesBlockType, lanesBlocked, message)
    ? 'FULL'
    : 'PARTIAL';

  return {
    eventKey,
    startedAt: startedAt.toISOString(),
    endsAt: endsAt?.toISOString(),
    roadName: roadName || undefined,
    direction: direction || undefined,
    controlKind,
    lanesBlocked: lanesBlocked || lanesBlockType || undefined,
    eventType: eventType || '돌발상황',
    eventDetailType: eventDetailType || undefined,
    message,
    linkId: linkId || undefined,
    latitude,
    longitude,
    distanceMeters: Math.round(
      distanceMeters(options.latitude, options.longitude, latitude, longitude),
    ),
    provider: '국가교통정보센터 돌발상황정보',
  };
}

function hasExplicitControl(
  lanesBlockType: string,
  lanesBlocked: string,
  message: string,
): boolean {
  if (lanesBlockType || lanesBlocked) return true;
  return /(전면|전차로|양방향|일부 차로|\d+\s*차로).{0,8}(통제|차단|폐쇄)|통행\s*금지|진입\s*금지|도로\s*(통제|폐쇄)/.test(
    message,
  );
}

function isFullControl(
  lanesBlockType: string,
  lanesBlocked: string,
  message: string,
): boolean {
  return /(전면|전차로|전체\s*차로|양방향).{0,8}(통제|차단|폐쇄)|통행\s*금지|도로\s*폐쇄|완전\s*통제/.test(
    `${lanesBlockType} ${lanesBlocked} ${message}`,
  );
}

function parseKoreanDate(value: string): Date | undefined {
  const match = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/.exec(value);
  if (!match) return undefined;
  const result = new Date(
    `${match[1]}-${match[2]}-${match[3]}T${match[4]}:${match[5]}:${match[6]}+09:00`,
  );
  return Number.isNaN(result.getTime()) ? undefined : result;
}

function boundingBox(latitude: number, longitude: number, radiusMeters: number) {
  const latitudeDelta = radiusMeters / 111_320;
  const longitudeDelta =
    radiusMeters / (111_320 * Math.max(Math.cos((latitude * Math.PI) / 180), 0.01));
  return {
    minLatitude: latitude - latitudeDelta,
    maxLatitude: latitude + latitudeDelta,
    minLongitude: longitude - longitudeDelta,
    maxLongitude: longitude + longitudeDelta,
  };
}

function directRequest(
  apiKey: string,
  bounds: ReturnType<typeof boundingBox>,
): { url: URL; init: RequestInit } {
  const url = new URL(ITS_EVENT_URL);
  url.searchParams.set('apiKey', apiKey);
  url.searchParams.set('type', 'all');
  url.searchParams.set('eventType', 'all');
  url.searchParams.set('minX', bounds.minLongitude.toFixed(6));
  url.searchParams.set('maxX', bounds.maxLongitude.toFixed(6));
  url.searchParams.set('minY', bounds.minLatitude.toFixed(6));
  url.searchParams.set('maxY', bounds.maxLatitude.toFixed(6));
  url.searchParams.set('getType', 'json');
  return { url, init: {} };
}

function relayRequest(
  endpoint: string,
  relayToken: string,
  bounds: ReturnType<typeof boundingBox>,
): { url: URL; init: RequestInit } {
  return {
    url: new URL(endpoint),
    init: {
      method: 'POST',
      headers: {
        authorization: `Bearer ${relayToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(bounds),
    },
  };
}

function relayEndpoint(value: string): string {
  const url = new URL(value);
  if (url.protocol !== 'https:') {
    throw new Error('ITS relay URL must use HTTPS');
  }
  if ((url.pathname && url.pathname !== '/') || url.search || url.hash) {
    throw new Error('ITS relay URL must contain only an HTTPS origin');
  }
  return new URL('/v1/its/event-info', url.origin).toString();
}

function distanceMeters(
  latitude1: number,
  longitude1: number,
  latitude2: number,
  longitude2: number,
): number {
  const radians = (value: number) => (value * Math.PI) / 180;
  const latitudeDelta = radians(latitude2 - latitude1);
  const longitudeDelta = radians(longitude2 - longitude1);
  const left = Math.sin(latitudeDelta / 2) ** 2;
  const right =
    Math.cos(radians(latitude1)) *
    Math.cos(radians(latitude2)) *
    Math.sin(longitudeDelta / 2) ** 2;
  return 6_371_000 * 2 * Math.atan2(Math.sqrt(left + right), Math.sqrt(1 - left - right));
}

function record(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number'
    ? String(value).trim()
    : '';
}

function number(value: unknown): number | undefined {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function controlRank(value: OfficialRoadControl['controlKind']): number {
  return value === 'FULL' ? 2 : 1;
}
