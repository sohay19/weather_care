import { z } from 'zod';
import type { DailyAirQualityForecast } from '../weather/weatherProvider';
import { UV_AREA_GRID_ROWS, uvAreaNoForGrid } from '../../regions/kmaUvAreaGridCatalog';
import { kmaGridCoordinates } from '../../regions/kmaGridCoordinates';

const AIRKOREA_FORECAST_URL =
  'https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMinuDustFrcstDspth';
const AIRKOREA_WEEKLY_URL =
  'https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMinuDustWeekFrcstDspth';

const shortItemSchema = z.object({
  dataTime: z.coerce.string(),
  informCode: z.coerce.string(),
  informData: z.coerce.string(),
  informGrade: z.coerce.string(),
  informCause: z.coerce.string().optional(),
});

const weeklyItemSchema = z.object({
  frcstOneDt: z.coerce.string().optional(),
  frcstOneCn: z.coerce.string().optional(),
  frcstTwoDt: z.coerce.string().optional(),
  frcstTwoCn: z.coerce.string().optional(),
  frcstThreeDt: z.coerce.string().optional(),
  frcstThreeCn: z.coerce.string().optional(),
  frcstFourDt: z.coerce.string().optional(),
  frcstFourCn: z.coerce.string().optional(),
});

function responseSchema<T extends z.ZodTypeAny>(item: T) {
  return z.object({
    response: z.object({
      header: z.object({
        resultCode: z.coerce.string(),
        resultMsg: z.coerce.string(),
      }),
      body: z.object({
        items: z.union([item, z.array(item)]),
      }).optional(),
    }),
  });
}

const portalErrorSchema = z.object({
  OpenAPI_ServiceResponse: z.object({
    cmmMsgHeader: z.object({
      errMsg: z.coerce.string(),
      returnReasonCode: z.coerce.string(),
    }),
  }),
});

export interface DailyAirQualityForecastAtDate
  extends DailyAirQualityForecast {
  date: string;
}

export const AIRKOREA_FORECAST_AREAS = Object.freeze([
  '서울', '인천', '경기남부', '경기북부', '영서', '영동',
  '충북', '충남', '대전', '세종', '전북', '전남', '광주',
  '경북', '경남', '대구', '울산', '부산', '제주',
]);

interface AirKoreaForecastProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  now?: () => Date;
  timeoutMs?: number;
}

export class AirKoreaForecastProviderError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AirKoreaForecastProviderError';
  }
}

export class AirKoreaForecastProvider {
  private readonly serviceKey: string;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;
  private readonly timeoutMs: number;

  constructor(options: AirKoreaForecastProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher = options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.now = options.now ?? (() => new Date());
    this.timeoutMs = options.timeoutMs ?? 6_000;
  }

  async getForecast(
    regionName: string | undefined,
    nx: number,
    ny: number,
  ): Promise<DailyAirQualityForecastAtDate[]> {
    if (!this.serviceKey) {
      throw new AirKoreaForecastProviderError('AirKorea service key is not configured');
    }
    const area = airKoreaForecastArea(regionName, nx, ny);
    if (!area) return [];
    const searchDate = koreanDate(this.now());
    const [shortResult, weeklyResult] = await Promise.allSettled([
      this.fetchShort(searchDate, area),
      this.fetchWeekly(searchDate, area),
    ]);
    const byDate = new Map<string, DailyAirQualityForecastAtDate>();
    for (const day of shortResult.status === 'fulfilled' ? shortResult.value : []) {
      byDate.set(day.date, day);
    }
    for (const day of weeklyResult.status === 'fulfilled' ? weeklyResult.value : []) {
      byDate.set(day.date, { ...byDate.get(day.date), ...day });
    }
    if (byDate.size === 0) {
      const reason = shortResult.status === 'rejected'
        ? shortResult.reason
        : weeklyResult.status === 'rejected'
          ? weeklyResult.reason
          : undefined;
      throw new AirKoreaForecastProviderError(
        reason instanceof Error ? reason.message : 'AirKorea forecast is unavailable',
      );
    }
    return [...byDate.values()].sort((left, right) => left.date.localeCompare(right.date));
  }

  async getForecastsByAreas(): Promise<Record<string, DailyAirQualityForecastAtDate[]>> {
    const requests = new Map<string, Promise<Response>>();
    const sharedFetcher: typeof fetch = (input, init) => {
      const key = String(input);
      let request = requests.get(key);
      if (!request) {
        request = this.fetcher(input, init);
        requests.set(key, request);
      }
      return request.then((response) => response.clone());
    };
    const shared = new AirKoreaForecastProvider({
      serviceKey: this.serviceKey,
      fetcher: sharedFetcher,
      now: this.now,
      timeoutMs: this.timeoutMs,
    });
    const entries = await Promise.all(AIRKOREA_FORECAST_AREAS.map(async (area) =>
      [area, await shared.getForecast(area, 0, 0)] as const));
    return Object.fromEntries(entries);
  }

  private async fetchShort(
    searchDate: string,
    area: string,
  ): Promise<DailyAirQualityForecastAtDate[]> {
    const payloads = await Promise.allSettled(
      ['PM10', 'PM25', 'O3'].map((informCode) =>
        this.fetchJson(AIRKOREA_FORECAST_URL, searchDate, { InformCode: informCode }),
      ),
    );
    const items: z.infer<typeof shortItemSchema>[] = [];
    for (const result of payloads) {
      if (result.status !== 'fulfilled') continue;
      const parsed = responseSchema(shortItemSchema).safeParse(result.value);
      if (!parsed.success) continue;
      const { header, body } = parsed.data.response;
      if (header.resultCode !== '00' || body === undefined) continue;
      items.push(...(Array.isArray(body.items) ? body.items : [body.items]));
    }
    if (items.length === 0) {
      const failure = payloads.find(
        (result): result is PromiseRejectedResult => result.status === 'rejected',
      );
      throw new AirKoreaForecastProviderError(
        failure?.reason instanceof Error
          ? failure.reason.message
          : 'AirKorea short forecast is unavailable',
      );
    }
    const byDate = new Map<string, DailyAirQualityForecastAtDate>();
    const issueByDateCode = new Map<string, string>();
    for (const item of items) {
      const date = compactDate(item.informData);
      if (!date) continue;
      const grade = gradeForArea(item.informGrade, area);
      if (!grade) continue;
      const issueKey = `${date}:${item.informCode}`;
      const issue = sortableIssueTime(item.dataTime);
      const previousIssue = issueByDateCode.get(issueKey);
      if (previousIssue !== undefined && previousIssue >= issue) continue;
      const current = byDate.get(date) ?? { date };
      if (item.informCode === 'PM10') current.pm10Grade = grade;
      if (item.informCode === 'PM25') current.pm25Grade = grade;
      if (item.informCode === 'O3') current.ozoneGrade = grade;
      if (item.informCause?.includes('황사')) current.yellowDustMentioned = true;
      byDate.set(date, current);
      issueByDateCode.set(issueKey, issue);
    }
    return [...byDate.values()];
  }

  private async fetchWeekly(
    searchDate: string,
    area: string,
  ): Promise<DailyAirQualityForecastAtDate[]> {
    const payload = await this.fetchJson(AIRKOREA_WEEKLY_URL, searchDate);
    const parsed = responseSchema(weeklyItemSchema).safeParse(payload);
    if (!parsed.success) {
      throw new AirKoreaForecastProviderError('AirKorea weekly forecast schema is invalid');
    }
    const { header, body } = parsed.data.response;
    validateHeader(header.resultCode, header.resultMsg, body !== undefined);
    const items = body === undefined
      ? []
      : Array.isArray(body.items) ? body.items : [body.items];
    const item = items[0];
    if (!item) return [];
    return [
      [item.frcstOneDt, item.frcstOneCn],
      [item.frcstTwoDt, item.frcstTwoCn],
      [item.frcstThreeDt, item.frcstThreeCn],
      [item.frcstFourDt, item.frcstFourCn],
    ].flatMap(([rawDate, content]) => {
      const date = compactDate(rawDate);
      const pm25Grade = content ? gradeForArea(content, area) : undefined;
      if (!date || !pm25Grade) return [];
      return [{
        date,
        pm25Grade,
        confidence: forecastConfidence(content),
      } satisfies DailyAirQualityForecastAtDate];
    });
  }

  private async fetchJson(
    url: string,
    searchDate: string,
    additionalQuery: Record<string, string> = {},
  ): Promise<unknown> {
    const query = new URLSearchParams({
      serviceKey: this.serviceKey,
      returnType: 'json',
      numOfRows: '100',
      pageNo: '1',
      searchDate,
      ...additionalQuery,
    });
    const response = await this.fetcher(`${url}?${query}`, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 3_600 },
    });
    const payload: unknown = await response.json();
    const portalError = portalErrorSchema.safeParse(payload);
    if (portalError.success) {
      const header = portalError.data.OpenAPI_ServiceResponse.cmmMsgHeader;
      throw new AirKoreaForecastProviderError(
        `AirKorea authorization failed ${header.returnReasonCode}: ${header.errMsg}`,
      );
    }
    if (!response.ok) {
      throw new AirKoreaForecastProviderError(
        `AirKorea forecast request failed with status ${response.status}`,
      );
    }
    return payload;
  }
}

export function airKoreaForecastArea(
  regionName: string | undefined,
  nx: number,
  ny: number,
): string | undefined {
  const name = regionName?.replaceAll(' ', '') ?? '';
  if (AIRKOREA_FORECAST_AREAS.includes(name)) return name;
  if (name.includes('경기') || /(수원|시흥|안산|화성|평택|성남|용인|안양|광명|과천|부천|군포|의왕|오산|안성|이천|여주|광주시|하남|고양|파주|의정부|양주|동두천|포천|연천|가평|남양주|구리|양평|김포)/.test(name)) {
    return /(고양|파주|의정부|양주|동두천|포천|연천|가평)/.test(name)
      ? '경기북부'
      : '경기남부';
  }
  const direct = [
    '서울', '인천', '대전', '세종', '광주', '부산', '대구', '울산', '제주',
  ].find((area) => name.includes(area));
  if (direct) return direct;
  if (name.includes('강원') || /(강릉|동해|삼척|속초|고성|양양|태백)/.test(name)) {
    return /(강릉|동해|삼척|속초|고성|양양|태백)/.test(name) ? '영동' : '영서';
  }
  const provinceAreas: ReadonlyArray<readonly [RegExp, string]> = [
    [/충청남도|충남/, '충남'], [/충청북도|충북/, '충북'],
    [/전라북도|전북/, '전북'], [/전라남도|전남/, '전남'],
    [/경상북도|경북/, '경북'], [/경상남도|경남/, '경남'],
  ];
  for (const [pattern, area] of provinceAreas) {
    if (pattern.test(name)) return area;
  }
  if (nx === 60 && ny === 121) return '경기남부';
  if (nx === 60 && ny === 127) return '서울';
  return undefined;
}

export function airKoreaForecastAreaForGrid(nx: number, ny: number): string | undefined {
  let prefix = uvAreaNoForGrid(nx, ny)?.slice(0, 2);
  if (prefix === '12') {
    let nearest: (typeof UV_AREA_GRID_ROWS)[number] | undefined;
    let distanceSquared = Number.POSITIVE_INFINITY;
    for (const row of UV_AREA_GRID_ROWS) {
      if (row[2].startsWith('12')) continue;
      const distance = (row[0] - nx) ** 2 + (row[1] - ny) ** 2;
      if (distance < distanceSquared) {
        nearest = row;
        distanceSquared = distance;
      }
    }
    prefix = nearest?.[2].slice(0, 2);
  }
  const areaByPrefix: Record<string, string> = {
    '11': '서울', '26': '부산', '27': '대구', '28': '인천',
    '30': '대전', '31': '울산', '36': '세종', '43': '충북',
    '44': '충남', '47': '경북', '48': '경남', '50': '제주',
    '52': '전북',
  };
  if (prefix && areaByPrefix[prefix]) return areaByPrefix[prefix];
  if (prefix === '41') {
    return (kmaGridCoordinates(nx, ny)?.latitude ?? 37) >= 37.65
      ? '경기북부' : '경기남부';
  }
  if (prefix === '51') {
    return (kmaGridCoordinates(nx, ny)?.longitude ?? 128) >= 128.3
      ? '영동' : '영서';
  }
  return undefined;
}

function gradeForArea(content: string, area: string): string | undefined {
  const areaPattern = escapeRegExp(area);
  return content.match(new RegExp(`(?:^|,)\\s*${areaPattern}\\s*:\\s*([^,]+)`))
    ?.[1]?.trim();
}

function forecastConfidence(content: string | undefined): '높음' | '낮음' | undefined {
  const raw = content?.match(/신뢰도\s*:\s*([^,]+)/)?.[1]?.trim();
  if (!raw) return undefined;
  return raw === '높음' ? '높음' : '낮음';
}

function validateHeader(resultCode: string, resultMsg: string, hasBody: boolean): void {
  if (resultCode !== '00') {
    throw new AirKoreaForecastProviderError(
      `AirKorea returned ${resultCode}: ${resultMsg}`,
    );
  }
  if (!hasBody) throw new AirKoreaForecastProviderError('AirKorea returned no body');
}

function compactDate(value: string | undefined): string | undefined {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return undefined;
  const parsed = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value
    ? value.replaceAll('-', '')
    : undefined;
}

function koreanDate(date: Date): string {
  return new Date(date.getTime() + 9 * 3_600_000).toISOString().slice(0, 10);
}

function sortableIssueTime(value: string): string {
  const match = value.trim().match(/^(\d{4}-\d{2}-\d{2})\s+(\d{1,2})시/);
  return match ? `${match[1]}T${match[2].padStart(2, '0')}` : value.trim();
}

function normalizeServiceKey(value: string): string {
  const trimmed = value.trim();
  try {
    return decodeURIComponent(trimmed);
  } catch {
    return trimmed;
  }
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
