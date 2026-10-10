import { WeatherWarning } from '../../types';
import {
  kmaApiHubErrorReason,
  kmaApiHubErrorStatus,
} from '../kmaApiHubResponse';
import { providerHttpFailureMessage } from '../providerHttpFailure';

const WARNING_STATUS_URL =
  'https://apihub.kma.go.kr/api/typ01/url/wrn_now_data_new.php';
const WARNING_REGION_MAPPING_URL =
  'https://apihub.kma.go.kr/api/typ01/url/wrn_reg_aws2.php';
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

export type KmaWarningTypeCode =
  | 'W'
  | 'R'
  | 'C'
  | 'D'
  | 'O'
  | 'N'
  | 'V'
  | 'T'
  | 'S'
  | 'Y'
  | 'H'
  | 'F'
  | 'K';

export type KmaWarningLevelCode = '2' | '3';
export type KmaActiveWarningCommandCode = '1' | '2' | '5' | '6';

type KmaWarningFailureDetail =
  | 'WARNING_SELECTED_REGION_ROW_INVALID'
  | 'WARNING_UNSUPPORTED_ROWS'
  | 'WARNING_JSON_RESPONSE'
  | 'WARNING_HTML_RESPONSE'
  | 'WARNING_ROWS_WITHOUT_TIMESTAMPS'
  | 'WARNING_COLUMN_FORMAT_CHANGED'
  | 'WARNING_REGION_MAPPING_INVALID';

export interface KmaWarningRegionMatch {
  regionId: string;
  regionName: string;
  stationId: string;
  stationName: string;
  distanceMeters: number;
}

export interface KmaWarningRegionStation {
  regionId: string;
  regionName: string;
  stationId: string;
  stationName: string;
  latitude: number;
  longitude: number;
}

export interface OfficialWeatherWarning extends WeatherWarning {
  typeCode: KmaWarningTypeCode;
  type: string;
  levelCode: KmaWarningLevelCode;
  level: '주의보' | '경보';
  commandCode: KmaActiveWarningCommandCode;
  regionId: string;
  regionName: string;
  announcedAt: string;
  validFrom: string;
  provider: '기상청 특보현황';
}

interface ParsedWarningRow {
  regionId: string;
  regionName: string;
  announcedAt: string;
  effectiveAt: string;
  typeCode: string;
  levelCode: string;
  commandCode: string;
}

interface KmaWarningProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  now?: () => Date;
  timeoutMs?: number;
}

export class KmaWarningProviderError extends Error {
  readonly providerFailureDetail?: KmaWarningFailureDetail;

  constructor(message: string, providerFailureDetail?: KmaWarningFailureDetail) {
    super(message);
    this.name = 'KmaWarningProviderError';
    this.providerFailureDetail = providerFailureDetail;
  }
}

export class KmaWarningProvider {
  private readonly serviceKey: string;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;
  private readonly timeoutMs: number;

  constructor(options: KmaWarningProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher =
      options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.now = options.now ?? (() => new Date());
    this.timeoutMs = options.timeoutMs ?? 10_000;
  }

  async getActiveForRegions(
    regionIds: readonly string[],
  ): Promise<OfficialWeatherWarning[]> {
    if (!this.serviceKey) {
      throw new KmaWarningProviderError(
        'KMA APIHub service key is not configured',
      );
    }
    if (regionIds.length === 0) return [];

    const now = this.now();
    const query = new URLSearchParams({
      fe: 'e',
      tm: compactKst(floorToFiveMinutes(now)),
      disp: '0',
      help: '0',
      authKey: this.serviceKey,
    });
    const response = await this.fetcher(`${WARNING_STATUS_URL}?${query}`, {
      headers: { Accept: 'text/plain' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 300 },
    });
    if (!response.ok) {
      throw new KmaWarningProviderError(
        await providerHttpFailureMessage(response, 'KMA warning request'),
      );
    }

    return parseActiveWarnings(await readWarningResponse(response), regionIds, now);
  }

  async resolveRegionByLocation(
    latitude: number,
    longitude: number,
  ): Promise<KmaWarningRegionMatch> {
    const matches = await this.resolveRegionsByLocations([{ latitude, longitude }]);
    return matches[0];
  }

  async resolveRegionsByLocations(
    locations: readonly { latitude: number; longitude: number }[],
  ): Promise<KmaWarningRegionMatch[]> {
    if (!this.serviceKey) {
      throw new KmaWarningProviderError(
        'KMA APIHub service key is not configured',
      );
    }
    for (const { latitude, longitude } of locations) {
      if (!isKoreanCoordinate(latitude, longitude)) {
        throw new KmaWarningProviderError(
          'KMA warning location is outside the valid Korean coordinate range',
        );
      }
    }
    if (locations.length === 0) return [];

    const stations = await this.getRegionStations();
    return locations.map(({ latitude, longitude }) =>
      nearestWarningRegion(stations, latitude, longitude));
  }

  async getRegionStations(): Promise<KmaWarningRegionStation[]> {
    if (!this.serviceKey) {
      throw new KmaWarningProviderError('KMA APIHub service key is not configured');
    }
    const query = new URLSearchParams({
      tm: '',
      disp: '0',
      help: '0',
      authKey: this.serviceKey,
    });
    const response = await this.fetcher(`${WARNING_REGION_MAPPING_URL}?${query}`, {
      headers: { Accept: 'text/plain' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 86_400 },
    });
    if (!response.ok) {
      throw new KmaWarningProviderError(
        await providerHttpFailureMessage(
          response,
          'KMA warning region mapping request',
        ),
      );
    }

    return parseWarningRegionStations(await readWarningResponse(response));
  }
}

export function nearestWarningRegion(
  stations: readonly KmaWarningRegionStation[],
  latitude: number,
  longitude: number,
): KmaWarningRegionMatch {
  if (!isKoreanCoordinate(latitude, longitude)) {
    throw new KmaWarningProviderError(
      'KMA warning location is outside the valid Korean coordinate range',
    );
  }
  let nearest: KmaWarningRegionStation | undefined;
  let distanceMeters = Number.POSITIVE_INFINITY;
  for (const station of stations) {
    const distance = haversineMeters(
      latitude, longitude, station.latitude, station.longitude,
    );
    if (distance < distanceMeters) {
      nearest = station;
      distanceMeters = distance;
    }
  }
  if (!nearest) {
    throw new KmaWarningProviderError(
      'KMA warning region mapping response has no usable stations',
      'WARNING_REGION_MAPPING_INVALID',
    );
  }
  return {
    regionId: nearest.regionId,
    regionName: nearest.regionName,
    stationId: nearest.stationId,
    stationName: nearest.stationName,
    distanceMeters: Math.round(distanceMeters),
  };
}

const WARNING_NAMES: Record<KmaWarningTypeCode, string> = {
  W: '강풍',
  R: '호우',
  C: '한파',
  D: '건조',
  O: '해일',
  N: '지진해일',
  V: '풍랑',
  T: '태풍',
  S: '대설',
  Y: '황사',
  H: '폭염',
  F: '안개',
  K: '열대야',
};

// 기상청 특보 DB 코드표와 현황 응답의 한글 표기를 함께 지원한다.
const WARNING_LEVEL_CODES: Record<string, string> = {
  예비: '1', 예비특보: '1', 주의: '2', 주의보: '2', 경보: '3',
};
const WARNING_COMMAND_CODES: Record<string, string> = {
  발표: '1', 대치: '2', 해제: '3', 대치해제: '4',
  연장: '5', 변경: '6', 변경해제: '7',
};

async function readWarningResponse(response: Response): Promise<string> {
  const payload = await response.arrayBuffer();
  const charset = /charset\s*=\s*["']?([^\s;"']+)/i
    .exec(response.headers.get('content-type') ?? '')?.[1];
  if (charset) return new TextDecoder(charset, { fatal: true, ignoreBOM: false }).decode(payload);
  try {
    return new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(payload);
  } catch {
    // charset 없는 APIHub 응답도 EUC-KR로 제공될 수 있다.
    return new TextDecoder('euc-kr', { fatal: true, ignoreBOM: false }).decode(payload);
  }
}

export function parseActiveWarnings(
  payload: string,
  regionIds: readonly string[],
  now: Date,
): OfficialWeatherWarning[] {
  const apiHubStatus = kmaApiHubErrorStatus(payload);
  if (apiHubStatus !== undefined) {
    const reason = kmaApiHubErrorReason(payload);
    throw new KmaWarningProviderError(
      `KMA warning response failed with status ${apiHubStatus}${
        reason ? `: ${reason}` : ''
      }`,
    );
  }
  if (/AUTH|인증|ERROR/i.test(payload) && !/L\d{7}/.test(payload)) {
    throw new KmaWarningProviderError('KMA warning response contains an error');
  }

  const selectedRegions = new Set(regionIds);
  const dataLines = payload
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(
      (line) =>
        line.length > 0 && !line.startsWith('#') && line !== '=',
    );
  const parsedRows = dataLines.map(parseWarningRow);
  const selectedRegionRowIsInvalid = dataLines.some((line, index) => {
    if (parsedRows[index] !== undefined) return false;
    const tokens = line.split(/[\s,]+/).filter(Boolean);
    return tokens.some((token) => selectedRegions.has(token));
  });
  if (selectedRegionRowIsInvalid) {
    throw new KmaWarningProviderError(
      'KMA warning selected region row has an unknown format',
      'WARNING_SELECTED_REGION_ROW_INVALID',
    );
  }
  const rows = parsedRows.filter(
    (row): row is ParsedWarningRow => row !== undefined,
  );
  if (dataLines.length > 0 && rows.length === 0) {
    const detail = unsupportedWarningDetail(payload, dataLines);
    if (detail === 'WARNING_COLUMN_FORMAT_CHANGED') return [];
    throw new KmaWarningProviderError(
      'KMA warning response has unsupported rows',
      detail,
    );
  }

  return rows.flatMap((row) => {
    if (!selectedRegions.has(row.regionId)) return [];
    if (!isWarningTypeCode(row.typeCode)) return [];
    if (row.levelCode !== '2' && row.levelCode !== '3') return [];
    if (!['1', '2', '5', '6'].includes(row.commandCode)) return [];

    const effectiveAt = compactKstToIso(row.effectiveAt);
    if (Date.parse(effectiveAt) > now.getTime()) return [];
    const levelCode = row.levelCode as KmaWarningLevelCode;

    return [{
      typeCode: row.typeCode,
      type: WARNING_NAMES[row.typeCode],
      levelCode,
      level: levelCode === '2' ? '주의보' : '경보',
      commandCode: row.commandCode as KmaActiveWarningCommandCode,
      regionId: row.regionId,
      regionName: row.regionName,
      announcedAt: compactKstToIso(row.announcedAt),
      validFrom: effectiveAt,
      provider: '기상청 특보현황' as const,
    }];
  });
}

export function parseWarningRegionStations(
  payload: string,
): KmaWarningRegionStation[] {
  const apiHubStatus = kmaApiHubErrorStatus(payload);
  if (apiHubStatus !== undefined) {
    const reason = kmaApiHubErrorReason(payload);
    throw new KmaWarningProviderError(
      `KMA warning region mapping response failed with status ${apiHubStatus}${
        reason ? `: ${reason}` : ''
      }`,
    );
  }
  if (/AUTH|인증|ERROR/i.test(payload) && !/L\d{7}/.test(payload)) {
    throw new KmaWarningProviderError(
      'KMA warning region mapping response contains an error',
    );
  }

  const stations = payload
    .split(/\r?\n/)
    .map(parseWarningRegionStation)
    .filter(
      (station): station is KmaWarningRegionStation => station !== undefined,
    );
  if (stations.length === 0) {
    throw new KmaWarningProviderError(
      'KMA warning region mapping response has no valid rows',
      'WARNING_REGION_MAPPING_INVALID',
    );
  }
  return stations;
}

function unsupportedWarningDetail(
  payload: string,
  dataLines: readonly string[],
): KmaWarningFailureDetail {
  const trimmed = payload.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return 'WARNING_JSON_RESPONSE';
  }
  if (/^\s*</.test(payload)) return 'WARNING_HTML_RESPONSE';
  const tokens = dataLines.flatMap((line) =>
    line.split(/[\s,]+/).filter(Boolean),
  );
  if (!tokens.some((token) => /^\d{12}$/.test(token))) {
    return 'WARNING_ROWS_WITHOUT_TIMESTAMPS';
  }
  if (tokens.length > 0) return 'WARNING_COLUMN_FORMAT_CHANGED';
  return 'WARNING_UNSUPPORTED_ROWS';
}

function parseWarningRow(line: string): ParsedWarningRow | undefined {
  const trimmed = line.trim();
  if (!trimmed) return undefined;

  // ED_TM(해제예고 시점)과 행 끝 '='는 특보의 활성 여부를 바꾸지 않는다.
  const normalized = trimmed.replace(/\s*,\s*/g, ' ').replace(/\s*=\s*$/, '').trim();
  const match = /^(L\d{7})\s+(.+?)\s+(L\d{7})\s+(.+?)\s+(\d{12})\s+(\d{12})\s+(\S+)\s+(\S+)\s+(\S+)(?:\s+\d{12})?$/.exec(
    normalized,
  );
  if (!match) return undefined;
  const typeCode = isWarningTypeCode(match[7]) ? match[7]
    : (Object.keys(WARNING_NAMES) as KmaWarningTypeCode[])
      .find((code) => WARNING_NAMES[code] === match[7]) ??
      (match[7] === '폭풍해일' ? 'O' : undefined);
  const levelCode = WARNING_LEVEL_CODES[match[8]] ?? match[8];
  const commandCode = WARNING_COMMAND_CODES[match[9]] ?? match[9];
  if (!typeCode || !/^[123]$/.test(levelCode) || !/^[1-7]$/.test(commandCode)) {
    return undefined;
  }
  return {
    regionId: match[3],
    regionName: match[4],
    announcedAt: match[5],
    effectiveAt: match[6],
    typeCode,
    levelCode,
    commandCode,
  };
}

function parseWarningRegionStation(
  line: string,
): KmaWarningRegionStation | undefined {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#') || trimmed === '=') return undefined;
  const tokens = (trimmed.includes(',')
    ? trimmed.split(',')
    : trimmed.split(/\s+/)
  ).map((token) => token.trim()).filter(Boolean);
  if (tokens.length < 7 || !/^\d+$/.test(tokens[0])) return undefined;

  const coordinateIndex = tokens.findIndex((token, index) => {
    if (index < 2 || index >= tokens.length - 1) return false;
    const candidateLongitude = Number(token);
    const candidateLatitude = Number(tokens[index + 1]);
    return isKoreanCoordinate(candidateLatitude, candidateLongitude);
  });
  const warningRegionIndex = tokens.findIndex((token) => /^L\d{7}$/.test(token));
  if (
    coordinateIndex < 0 ||
    warningRegionIndex < 0 ||
    warningRegionIndex >= tokens.length - 1
  ) {
    return undefined;
  }

  return {
    stationId: tokens[0],
    stationName: tokens[1],
    longitude: Number(tokens[coordinateIndex]),
    latitude: Number(tokens[coordinateIndex + 1]),
    regionId: tokens[warningRegionIndex],
    // WRN_KO 뒤의 SFC_STN_ID(대표지점번호)와 '='는 이름에 포함하지 않는다.
    regionName: tokens.slice(warningRegionIndex + 1)
      .filter((token) => token !== '=' && !/^\d+$/.test(token)).join(' '),
  };
}

function isWarningTypeCode(value: string): value is KmaWarningTypeCode {
  return Object.hasOwn(WARNING_NAMES, value);
}

function compactKst(value: Date): string {
  const kst = new Date(value.getTime() + KST_OFFSET_MS);
  return `${kst.getUTCFullYear()}${String(kst.getUTCMonth() + 1).padStart(2, '0')}${String(kst.getUTCDate()).padStart(2, '0')}${String(kst.getUTCHours()).padStart(2, '0')}${String(kst.getUTCMinutes()).padStart(2, '0')}`;
}

function floorToFiveMinutes(value: Date): Date {
  return new Date(Math.floor(value.getTime() / 300_000) * 300_000);
}

function compactKstToIso(value: string): string {
  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}T${value.slice(8, 10)}:${value.slice(10, 12)}:00+09:00`;
}

function normalizeServiceKey(value: string): string {
  const trimmed = value.trim();
  try {
    return decodeURIComponent(trimmed);
  } catch {
    return trimmed;
  }
}

function isKoreanCoordinate(latitude: number, longitude: number): boolean {
  return Number.isFinite(latitude) &&
    Number.isFinite(longitude) &&
    latitude >= 30 &&
    latitude <= 44 &&
    longitude >= 124 &&
    longitude <= 132;
}

function haversineMeters(
  latitudeA: number,
  longitudeA: number,
  latitudeB: number,
  longitudeB: number,
): number {
  const radians = (value: number) => value * Math.PI / 180;
  const latitudeDelta = radians(latitudeB - latitudeA);
  const longitudeDelta = radians(longitudeB - longitudeA);
  const startLatitude = radians(latitudeA);
  const endLatitude = radians(latitudeB);
  const haversine =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(startLatitude) * Math.cos(endLatitude) *
      Math.sin(longitudeDelta / 2) ** 2;
  return 6_371_000 * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
}
