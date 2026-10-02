import { strFromU8, unzipSync } from 'fflate';
import { RoadIceRisk } from '../../types';
import { providerHttpFailureMessage } from '../providerHttpFailure';
import { mapWithConcurrency } from '../../utils/concurrencyLimiter';

const ROAD_RISK_URL =
  'https://apihub.kma.go.kr/api/typ04/url/road_file_down.php';
const DEFAULT_MAX_DISTANCE_METERS = 3_000;

const ROAD_NAMES: Record<string, string> = {
  '001': '경부선',
  '012': '무안광주대구선',
  '015': '서해안선',
  '020': '새만금포항선',
  '025': '호남선',
  '027': '순천완주선',
  '030': '서산영덕선',
  '035': '통영대전중부선',
  '045': '중부내륙선',
  '050': '영동선',
  '055': '중앙선',
  '251': '호남선의지선',
};

export const ROAD_ICE_ROAD_NUMBERS = Object.freeze(Object.keys(ROAD_NAMES));

interface KmaRoadIceProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  now?: () => Date;
  timeoutMs?: number;
  maxDistanceMeters?: number;
}

export interface RoadIceSegment {
  producedAt: string;
  roadNumber: string;
  linkId: string;
  level: 0 | 1 | 2 | 3;
  sourceType: 'ANALYSIS' | 'OBSERVATION';
  fromLatitude: number;
  fromLongitude: number;
  toLatitude: number;
  toLongitude: number;
}

export interface RoadIceCollectionLocation {
  latitude: number;
  longitude: number;
}

export class KmaRoadIceProviderError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'KmaRoadIceProviderError';
  }
}

export class KmaRoadIceProvider {
  private readonly serviceKey: string;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;
  private readonly timeoutMs: number;
  private readonly maxDistanceMeters: number;

  constructor(options: KmaRoadIceProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher =
      options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.now = options.now ?? (() => new Date());
    this.timeoutMs = options.timeoutMs ?? 15_000;
    this.maxDistanceMeters =
      options.maxDistanceMeters ?? DEFAULT_MAX_DISTANCE_METERS;
  }

  async getNearestRiskByLocation(
    latitude: number,
    longitude: number,
    roadNumbers: readonly string[] = ROAD_ICE_ROAD_NUMBERS,
  ): Promise<RoadIceRisk | undefined> {
    validateLocation(latitude, longitude);
    if (!this.serviceKey) {
      throw new KmaRoadIceProviderError(
        'KMA APIHub service key is not configured',
      );
    }
    if (!isRoadIceSeason(this.now()) || roadNumbers.length === 0) {
      return undefined;
    }

    const segmentGroups = await mapWithConcurrency(
      roadNumbers,
      2,
      (roadNumber) => this.fetchRoadSegments(roadNumber),
    );
    return nearestRoadIceRisk(
      segmentGroups.flat(),
      latitude,
      longitude,
      this.maxDistanceMeters,
    );
  }

  async getNearestRisksByLocations(
    locations: readonly RoadIceCollectionLocation[],
    roadNumbers: readonly string[] = ROAD_ICE_ROAD_NUMBERS,
  ): Promise<Array<RoadIceRisk | undefined>> {
    for (const location of locations) {
      validateLocation(location.latitude, location.longitude);
    }
    if (!this.serviceKey) {
      throw new KmaRoadIceProviderError(
        'KMA APIHub service key is not configured',
      );
    }
    if (locations.length === 0 || !isRoadIceSeason(this.now()) || roadNumbers.length === 0) {
      return locations.map(() => undefined);
    }
    const segmentGroups = await mapWithConcurrency(
      roadNumbers,
      2,
      (roadNumber) => this.fetchRoadSegments(roadNumber),
    );
    const segments = segmentGroups.flat();
    return locations.map((location) => nearestRoadIceRisk(
      segments,
      location.latitude,
      location.longitude,
      this.maxDistanceMeters,
    ));
  }

  async getRiskSegments(
    roadNumbers: readonly string[] = ROAD_ICE_ROAD_NUMBERS,
  ): Promise<RoadIceSegment[]> {
    if (!this.serviceKey) {
      throw new KmaRoadIceProviderError('KMA APIHub service key is not configured');
    }
    if (!isRoadIceSeason(this.now()) || roadNumbers.length === 0) return [];
    const groups = await mapWithConcurrency(
      roadNumbers, 2, (roadNumber) => this.fetchRoadSegments(roadNumber),
    );
    return groups.flat().filter((segment) => segment.level > 0);
  }

  private async fetchRoadSegments(
    roadNumber: string,
  ): Promise<RoadIceSegment[]> {
    if (!(roadNumber in ROAD_NAMES)) {
      throw new KmaRoadIceProviderError(
        `Unsupported KMA road number: ${roadNumber}`,
      );
    }
    const query = new URLSearchParams({
      roadNum: roadNumber,
      authKey: this.serviceKey,
    });
    const response = await this.fetcher(`${ROAD_RISK_URL}?${query}`, {
      headers: { Accept: 'application/zip' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 300 },
    });
    if (!response.ok) {
      throw new KmaRoadIceProviderError(
        await providerHttpFailureMessage(response, 'KMA road risk request'),
      );
    }
    return parseRoadIceArchive(await response.arrayBuffer(), roadNumber);
  }
}

export function nearestRoadIceRisk(
  segments: readonly RoadIceSegment[],
  latitude: number,
  longitude: number,
  maxDistanceMeters = DEFAULT_MAX_DISTANCE_METERS,
): RoadIceRisk | undefined {
  const candidates = segments
      .filter((segment) => segment.level > 0)
      .map((segment) => ({
        segment,
        distanceMeters: distanceToSegmentMeters(
          latitude,
          longitude,
          segment.fromLatitude,
          segment.fromLongitude,
          segment.toLatitude,
          segment.toLongitude,
        ),
      }))
      .filter((item) => item.distanceMeters <= maxDistanceMeters)
      .sort(
        (left, right) =>
          right.segment.level - left.segment.level ||
          left.distanceMeters - right.distanceMeters,
      );
  const selected = candidates[0];
  if (!selected) return undefined;

  const segment = selected.segment;
  const level = segment.level as 1 | 2 | 3;
  return {
      producedAt: segment.producedAt,
      roadNumber: segment.roadNumber,
      roadName: ROAD_NAMES[segment.roadNumber] ?? `고속도로 ${segment.roadNumber}`,
      linkId: segment.linkId,
      level,
      levelLabel: level === 1 ? '관심' : level === 2 ? '주의' : '위험',
      sourceType: segment.sourceType,
      fromLatitude: segment.fromLatitude,
      fromLongitude: segment.fromLongitude,
      toLatitude: segment.toLatitude,
      toLongitude: segment.toLongitude,
      distanceMeters: Math.round(selected.distanceMeters),
      provider: '기상청 도로살얼음 발생 가능 정보',
  };
}

export function parseRoadIceArchive(
  payload: ArrayBuffer,
  roadNumber: string,
): RoadIceSegment[] {
  const bytes = new Uint8Array(payload);
  if (bytes.length < 4 || bytes[0] !== 0x50 || bytes[1] !== 0x4b) {
    throw new KmaRoadIceProviderError(
      'KMA road risk response is not a ZIP archive',
    );
  }

  let entries: Record<string, Uint8Array>;
  try {
    entries = unzipSync(bytes);
  } catch {
    throw new KmaRoadIceProviderError(
      'KMA road risk ZIP archive could not be decompressed',
    );
  }
  const selected = Object.entries(entries).find(([name]) =>
    /_1KM_FRG_\d{12}\.csv$/i.test(name),
  );
  if (!selected) {
    throw new KmaRoadIceProviderError(
      'KMA road risk archive has no 1km ice file',
    );
  }

  const [fileName, content] = selected;
  const timeMatch = /_1KM_FRG_(\d{12})\.csv$/i.exec(fileName);
  if (!timeMatch) {
    throw new KmaRoadIceProviderError(
      'KMA road risk filename has no production time',
    );
  }
  return parseRoadIceCsv(
    strFromU8(content).replace(/^\uFEFF/, ''),
    roadNumber,
    compactUtcToIso(timeMatch[1]),
  );
}

function parseRoadIceCsv(
  csv: string,
  roadNumber: string,
  producedAt: string,
): RoadIceSegment[] {
  const lines = csv
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  const header = lines[0]?.split(',').map((value) => value.trim());
  const expected = [
    'LINK_ID',
    'F_LON',
    'F_LAT',
    'T_LON',
    'T_LAT',
    'B_ICE',
    'FLAG',
  ];
  if (!header || expected.some((name) => !header.includes(name))) {
    throw new KmaRoadIceProviderError(
      'KMA road risk CSV header is invalid',
    );
  }
  const index = Object.fromEntries(
    header.map((name, position) => [name, position]),
  );

  return lines.slice(1).map((line) => {
    const values = line.split(',').map((value) => value.trim());
    const level = Number(values[index.B_ICE]);
    const flag = values[index.FLAG];
    const segment = {
      producedAt,
      roadNumber,
      linkId: values[index.LINK_ID],
      level,
      sourceType: flag === '1' ? 'OBSERVATION' as const : 'ANALYSIS' as const,
      fromLongitude: Number(values[index.F_LON]),
      fromLatitude: Number(values[index.F_LAT]),
      toLongitude: Number(values[index.T_LON]),
      toLatitude: Number(values[index.T_LAT]),
    };
    if (
      !segment.linkId ||
      ![0, 1, 2, 3].includes(level) ||
      !['0', '1'].includes(flag) ||
      ![
        segment.fromLongitude,
        segment.fromLatitude,
        segment.toLongitude,
        segment.toLatitude,
      ].every(Number.isFinite)
    ) {
      throw new KmaRoadIceProviderError(
        'KMA road risk CSV contains an invalid row',
      );
    }
    return segment as RoadIceSegment;
  });
}

export function isRoadIceSeason(now: Date): boolean {
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const month = kst.getUTCMonth() + 1;
  const day = kst.getUTCDate();
  return month === 12 || month <= 2 || (month === 11 && day >= 15) ||
    (month === 3 && day <= 15);
}

function distanceToSegmentMeters(
  latitude: number,
  longitude: number,
  fromLatitude: number,
  fromLongitude: number,
  toLatitude: number,
  toLongitude: number,
): number {
  const radians = Math.PI / 180;
  const metresPerLatitude = 111_320;
  const metresPerLongitude =
    metresPerLatitude * Math.cos(latitude * radians);
  const ax = (fromLongitude - longitude) * metresPerLongitude;
  const ay = (fromLatitude - latitude) * metresPerLatitude;
  const bx = (toLongitude - longitude) * metresPerLongitude;
  const by = (toLatitude - latitude) * metresPerLatitude;
  const dx = bx - ax;
  const dy = by - ay;
  const lengthSquared = dx * dx + dy * dy;
  const t =
    lengthSquared === 0
      ? 0
      : Math.max(0, Math.min(1, -(ax * dx + ay * dy) / lengthSquared));
  return Math.hypot(ax + t * dx, ay + t * dy);
}

function compactUtcToIso(value: string): string {
  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}T${value.slice(8, 10)}:${value.slice(10, 12)}:00Z`;
}

function normalizeServiceKey(value: string): string {
  const trimmed = value.trim();
  try {
    return decodeURIComponent(trimmed);
  } catch {
    return trimmed;
  }
}

function validateLocation(latitude: number, longitude: number): void {
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < 30 ||
    latitude > 44 ||
    longitude < 120 ||
    longitude > 134
  ) {
    throw new KmaRoadIceProviderError(
      'Location is outside the supported Korean road area',
    );
  }
}
