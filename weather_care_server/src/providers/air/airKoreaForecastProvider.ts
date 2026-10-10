import { z } from 'zod';
import type { DailyAirQualityForecast } from '../weather/weatherProvider';
import { administrativeAreaForLocation } from '../../regions/nationwideLocation';
import { collectedCacheKey, getCollectedCache } from '../../database/collectedWeatherRepository';
import { latestAirKoreaForecastIssue } from '../../collection/sourcePublicationSchedule';

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
  requiredShortIssue?: string;
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
  private readonly requiredShortIssue?: string;

  constructor(options: AirKoreaForecastProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher = options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.now = options.now ?? (() => new Date());
    this.timeoutMs = options.timeoutMs ?? 6_000;
    this.requiredShortIssue = options.requiredShortIssue;
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
      requiredShortIssue: latestAirKoreaForecastIssue(this.now()),
    });
    const entries = await Promise.all(AIRKOREA_FORECAST_AREAS.map(async (area) =>
      [area, await shared.getForecast(area, 0, 0)] as const));
    const today = koreanDate(this.now()).replaceAll('-', '');
    if (entries.some(([, days]) => !days.some((day) => day.date === today &&
        day.pm10Grade && day.pm25Grade))) {
      throw new AirKoreaForecastProviderError('AirKorea nationwide forecast publication is incomplete');
    }
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
      const compactIssue = issue.replace(/[-T]/g, '') + '00';
      if (this.requiredShortIssue &&
          (!/^\d{12}$/.test(compactIssue) || compactIssue < this.requiredShortIssue)) continue;
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
    return /(고양|파주|의정부|양주|동두천|포천|연천|가평|김포|구리|남양주)/.test(name)
      ? '경기북부'
      : '경기남부';
  }
  const direct = [
    '서울', '인천', '대전', '세종', '광주', '부산', '대구', '울산', '제주',
  ].find((area) => name.includes(area));
  if (direct) return direct;
  if (name.includes('강원') || /(강릉|동해|삼척|속초|고성|양양|태백|양구|인제|홍천|평창|정선|철원|화천|춘천|횡성|원주|영월)/.test(name)) {
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
  return airKoreaForecastAreaForGrid(nx, ny);
}

export function airKoreaForecastAreaForGrid(nx: number, ny: number): string | undefined {
  return airKoreaForecastAreaForAdminCode(administrativeAreaForLocation({ nx, ny })?.[0]);
}

export function airKoreaForecastAreaForAdminCode(adminCode: string | undefined): string | undefined {
  if (!adminCode || !/^\d{10}$/.test(adminCode)) return undefined;
  const prefix = adminCode.slice(0, 2);
  if (prefix === '12') {
    // 기상청 2026-07 행정코드의 통합 지역도 에어코리아의 기존 예보 권역에 대응한다.
    return ['1221', '1224', '1227', '1230', '1233'].includes(adminCode.slice(0, 4))
      ? '광주' : '전남';
  }
  const areaByPrefix: Record<string, string> = {
    '11': '서울', '26': '부산', '27': '대구', '28': '인천',
    '29': '광주', '30': '대전', '31': '울산', '36': '세종', '43': '충북',
    '44': '충남', '46': '전남', '47': '경북', '48': '경남', '50': '제주',
    '52': '전북',
  };
  if (prefix && areaByPrefix[prefix]) return areaByPrefix[prefix];
  if (prefix === '41') {
    // 에어코리아 FAQ(2026-01-27)의 11개 경기북부 시군. 위도 경계로 나누지 않는다.
    // https://airkorea.or.kr/web/board/5/1171/?pMENU_NO=144
    return ['4128', '4148', '4115', '4163', '4125', '4165',
      '4180', '4182', '4157', '4131', '4136'].includes(adminCode.slice(0, 4))
      ? '경기북부' : '경기남부';
  }
  if (prefix === '51') {
    return ['5115', '5117', '5119', '5121', '5123', '5182', '5183']
      .includes(adminCode.slice(0, 4)) ? '영동' : '영서';
  }
  return undefined;
}

export interface NationwideAirForecast {
  issue: string;
  areas: Record<string, DailyAirQualityForecastAtDate[]>;
}

export function nationwideAirForecastIsUsable(snapshot: NationwideAirForecast, now: Date): boolean {
  const today = koreanDate(now).replaceAll('-', '');
  return snapshot?.issue === latestAirKoreaForecastIssue(now) &&
    AIRKOREA_FORECAST_AREAS.every((area) => Array.isArray(snapshot.areas?.[area]) &&
      snapshot.areas[area].some((day) => day.date === today && day.pm10Grade && day.pm25Grade));
}

export async function readCollectedAirForecast(
  db: D1Database | undefined,
  nx: number,
  ny: number,
  fallback: DailyAirQualityForecastAtDate[],
  now = new Date(),
  adminCode?: string,
  regionName?: string,
): Promise<DailyAirQualityForecastAtDate[]> {
  const record = await getCollectedCache<NationwideAirForecast>(db, collectedCacheKey.nationwideAirForecast);
  const area = airKoreaForecastAreaForAdminCode(adminCode) ?? airKoreaForecastArea(regionName, nx, ny);
  return record?.status === 'AVAILABLE' && record.value.issue === latestAirKoreaForecastIssue(now) && area
    ? record.value.areas[area] ?? fallback : fallback;
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
