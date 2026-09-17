import { z } from 'zod';
import { DailyWeatherForecast } from './weatherProvider';
import { KmaMidTermRegionIds } from '../../regions/kmaMidTermRegionCatalog';
import { providerHttpFailureMessage } from '../providerHttpFailure';

const KMA_PUBLIC_MID_TERM_URL =
  'https://apis.data.go.kr/1360000/MidFcstInfoService';
const KMA_API_HUB_MID_TERM_URL =
  'https://apihub.kma.go.kr/api/typ02/openApi/MidFcstInfoService';
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const PUBLICATION_DELAY_MS = 30 * 60 * 1000;

const itemSchema = z.object({ regId: z.coerce.string() }).catchall(
  z.union([z.string(), z.number(), z.null()]),
);
const responseSchema = z.object({
  response: z.object({
    header: z.object({
      resultCode: z.coerce.string(),
      resultMsg: z.coerce.string(),
    }),
    body: z.object({
      items: z.object({
        item: z.union([itemSchema, z.array(itemSchema)]),
      }),
    }).optional(),
  }),
});

interface KmaMidTermProviderOptions {
  serviceKey?: string;
  apiHubKey?: string;
  fetcher?: typeof fetch;
  now?: () => Date;
  timeoutMs?: number;
}

export class KmaMidTermProviderError extends Error {
  constructor(message: string, readonly retryable = false) {
    super(message);
    this.name = 'KmaMidTermProviderError';
  }
}

export class KmaMidTermProvider {
  private readonly serviceKey: string;
  private readonly apiHubKey: string;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;
  private readonly timeoutMs: number;

  constructor(options: KmaMidTermProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.apiHubKey = normalizeServiceKey(options.apiHubKey);
    this.fetcher = options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.now = options.now ?? (() => new Date());
    this.timeoutMs = options.timeoutMs ?? 6_000;
  }

  async getForecast(region: KmaMidTermRegionIds): Promise<DailyWeatherForecast[]> {
    if (!this.serviceKey && !this.apiHubKey) {
      throw new KmaMidTermProviderError('KMA mid-term key is not configured');
    }

    let lastError: unknown;
    for (const issueTime of latestMidTermIssueTimes(this.now(), 3)) {
      try {
        const [temperature, land] = await Promise.all([
          this.fetchItem('getMidTa', region.temperatureRegionId, issueTime),
          this.fetchItem('getMidLandFcst', region.landRegionId, issueTime),
        ]);
        return buildMidTermDailyForecast(issueTime, temperature, land);
      } catch (error) {
        lastError = error;
        if (!(error instanceof KmaMidTermProviderError) || !error.retryable) {
          throw error;
        }
      }
    }
    throw new KmaMidTermProviderError(
      lastError instanceof Error ? lastError.message : 'KMA mid-term forecast is unavailable',
    );
  }

  private async fetchItem(
    endpoint: 'getMidTa' | 'getMidLandFcst',
    regionId: string,
    issueTime: string,
  ): Promise<z.infer<typeof itemSchema>> {
    const query = new URLSearchParams({
      ...(this.apiHubKey
        ? { authKey: this.apiHubKey }
        : { ServiceKey: this.serviceKey }),
      pageNo: '1',
      numOfRows: '10',
      dataType: 'JSON',
      regId: regionId,
      tmFc: issueTime,
    });
    const baseUrl = this.apiHubKey
      ? KMA_API_HUB_MID_TERM_URL
      : KMA_PUBLIC_MID_TERM_URL;
    const response = await this.fetcher(`${baseUrl}/${endpoint}?${query}`, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 21_600 },
    });
    const text = await response.text();
    if (!response.ok) {
      throw new KmaMidTermProviderError(
        await providerHttpFailureMessage(
          response,
          'KMA mid-term request',
          text,
        ),
        response.status >= 500,
      );
    }
    let payload: unknown;
    try {
      payload = JSON.parse(text);
    } catch {
      throw new KmaMidTermProviderError('KMA mid-term response is not JSON');
    }
    const parsed = responseSchema.safeParse(payload);
    if (!parsed.success) {
      throw new KmaMidTermProviderError('KMA mid-term response schema is invalid');
    }
    const { header, body } = parsed.data.response;
    if (!['0', '00'].includes(header.resultCode)) {
      const retryable = header.resultCode === '03' || /NO_DATA|NODATA/i.test(header.resultMsg);
      throw new KmaMidTermProviderError(
        `KMA mid-term returned ${header.resultCode}: ${header.resultMsg}`,
        retryable,
      );
    }
    if (!body) throw new KmaMidTermProviderError('KMA mid-term returned no body', true);
    const items = Array.isArray(body.items.item) ? body.items.item : [body.items.item];
    const item = items.find((candidate) => candidate.regId === regionId) ?? items[0];
    if (!item) throw new KmaMidTermProviderError('KMA mid-term returned no item', true);
    return item;
  }
}

export function latestMidTermIssueTimes(now: Date, limit: number): string[] {
  const effectiveKst = new Date(now.getTime() + KST_OFFSET_MS - PUBLICATION_DELAY_MS);
  const candidates: string[] = [];
  for (let dayOffset = 0; candidates.length < limit; dayOffset += 1) {
    const date = new Date(Date.UTC(
      effectiveKst.getUTCFullYear(),
      effectiveKst.getUTCMonth(),
      effectiveKst.getUTCDate() - dayOffset,
    ));
    for (const hour of [18, 6]) {
      if (dayOffset === 0 && hour > effectiveKst.getUTCHours()) continue;
      date.setUTCHours(hour, 0, 0, 0);
      candidates.push(compactIssueTime(date));
      if (candidates.length === limit) break;
    }
  }
  return candidates;
}

export function buildMidTermDailyForecast(
  issueTime: string,
  temperature: z.infer<typeof itemSchema>,
  land: z.infer<typeof itemSchema>,
): DailyWeatherForecast[] {
  if (!/^\d{12}$/.test(issueTime)) {
    throw new KmaMidTermProviderError('KMA mid-term issue time is invalid');
  }
  const issueDate = new Date(Date.UTC(
    Number(issueTime.slice(0, 4)),
    Number(issueTime.slice(4, 6)) - 1,
    Number(issueTime.slice(6, 8)),
  ));
  const issuedAt = `${issueTime.slice(0, 4)}-${issueTime.slice(4, 6)}-${issueTime.slice(6, 8)}T${issueTime.slice(8, 10)}:${issueTime.slice(10, 12)}:00+09:00`;

  return Array.from({ length: 7 }, (_, index) => index + 4).flatMap((offset) => {
    const minTemperature = numeric(temperature[`taMin${offset}`]);
    const maxTemperature = numeric(temperature[`taMax${offset}`]);
    const weatherValues = offset <= 7
      ? [textValue(land[`wf${offset}Am`]), textValue(land[`wf${offset}Pm`])]
      : [textValue(land[`wf${offset}`])];
    const probabilityValues = offset <= 7
      ? [numeric(land[`rnSt${offset}Am`]), numeric(land[`rnSt${offset}Pm`])]
      : [numeric(land[`rnSt${offset}`])];
    const weather = weatherValues.filter((value): value is string => value !== undefined);
    const probabilities = probabilityValues.filter((value): value is number => value !== undefined);
    if (minTemperature === undefined && maxTemperature === undefined && weather.length === 0) {
      return [];
    }
    const skyCondition = representativeMidTermWeather(weather);
    const precipitationProbability = probabilities.length === 0 ? 0 : Math.max(...probabilities);
    const date = new Date(issueDate.getTime() + offset * 86_400_000)
      .toISOString()
      .slice(0, 10)
      .replaceAll('-', '');
    const snowExpected = skyCondition.includes('눈');
    return [{
      date,
      forecastSource: 'KMA_MID_TERM',
      issuedAt,
      minTemperature,
      maxTemperature,
      minTemperatureSource: minTemperature === undefined ? undefined : 'DAILY',
      maxTemperatureSource: maxTemperature === undefined ? undefined : 'DAILY',
      weatherDataComplete:
        minTemperature !== undefined && maxTemperature !== undefined &&
        weather.length === (offset <= 7 ? 2 : 1),
      precipitationDetail: {
        kind: 'EXTENDED',
        hours: [],
        extendedMaxProbability:
          probabilities.length === 0 ? undefined : precipitationProbability,
      },
      skyCondition,
      precipitationProbability,
      precipitationAmount: 0,
      snowProbability: snowExpected ? precipitationProbability : 0,
      snowfallAmount: 0,
    }];
  });
}

function representativeMidTermWeather(values: string[]): string {
  const joined = values.join(' ');
  const rain = /비|소나기/.test(joined);
  const snow = /눈/.test(joined);
  if (rain && snow) return '비/눈';
  if (snow) return '눈';
  if (/소나기/.test(joined)) return '소나기';
  if (rain) return '비';
  if (/흐/.test(joined)) return '흐림';
  if (/구름/.test(joined)) return '구름많음';
  if (/맑/.test(joined)) return '맑음';
  return '정보 없음';
}

function numeric(value: unknown): number | undefined {
  if (value === null || value === undefined || value === '') return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function textValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

function compactIssueTime(date: Date): string {
  return date.toISOString().slice(0, 13).replace(/[-T:]/g, '') + '00';
}

function normalizeServiceKey(value: string | undefined): string {
  if (!value) return '';
  try {
    return decodeURIComponent(value.trim());
  } catch {
    return value.trim();
  }
}
