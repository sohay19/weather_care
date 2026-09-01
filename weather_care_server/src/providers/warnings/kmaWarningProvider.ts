import { WeatherWarning } from '../../types';

const WARNING_STATUS_URL =
  'https://apihub.kma.go.kr/api/typ01/url/wrn_now_data_new.php';
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
export type KmaActiveWarningCommandCode = '1' | '2' | '5';

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
  constructor(message: string) {
    super(message);
    this.name = 'KmaWarningProviderError';
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
      tm: compactKst(now),
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
        `KMA warning request failed with status ${response.status}`,
      );
    }

    return parseActiveWarnings(await response.text(), regionIds, now);
  }
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

export function parseActiveWarnings(
  payload: string,
  regionIds: readonly string[],
  now: Date,
): OfficialWeatherWarning[] {
  if (/AUTH|인증|ERROR/i.test(payload) && !/L\d{7}/.test(payload)) {
    throw new KmaWarningProviderError('KMA warning response contains an error');
  }

  const selectedRegions = new Set(regionIds);
  const dataLines = payload
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && !line.startsWith('#'));
  const parsedRows = dataLines.map(parseWarningRow);
  if (parsedRows.some((row) => row === undefined)) {
    throw new KmaWarningProviderError(
      'KMA warning response has an unknown format',
    );
  }
  const rows = parsedRows as ParsedWarningRow[];

  return rows.flatMap((row) => {
    if (!selectedRegions.has(row.regionId)) return [];
    if (!isWarningTypeCode(row.typeCode)) return [];
    if (row.levelCode !== '2' && row.levelCode !== '3') return [];
    if (!['1', '2', '5'].includes(row.commandCode)) return [];

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

function parseWarningRow(line: string): ParsedWarningRow | undefined {
  const trimmed = line.trim();
  if (!trimmed) return undefined;

  const normalized = trimmed.replace(/\s*,\s*/g, ' ');
  const match = /^(L\d{7})\s+(.+?)\s+(L\d{7})\s+(.+?)\s+(\d{12})\s+(\d{12})\s+([A-Z])\s+([123])\s+([1-5])$/.exec(
    normalized,
  );
  if (!match) return undefined;
  return {
    regionId: match[3],
    regionName: match[4],
    announcedAt: match[5],
    effectiveAt: match[6],
    typeCode: match[7],
    levelCode: match[8],
    commandCode: match[9],
  };
}

function isWarningTypeCode(value: string): value is KmaWarningTypeCode {
  return value in WARNING_NAMES;
}

function compactKst(value: Date): string {
  const kst = new Date(value.getTime() + KST_OFFSET_MS);
  return `${kst.getUTCFullYear()}${String(kst.getUTCMonth() + 1).padStart(2, '0')}${String(kst.getUTCDate()).padStart(2, '0')}${String(kst.getUTCHours()).padStart(2, '0')}${String(kst.getUTCMinutes()).padStart(2, '0')}`;
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
