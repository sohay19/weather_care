import { z } from 'zod';
import { WeatherSnapshot } from '../../types';
import {
  DailyWeatherForecast,
  WeatherForecast,
  WeatherProvider,
} from './weatherProvider';

const KMA_FORECAST_URL =
  'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst';
const KMA_DATA_SOURCE = '기상청 단기예보';
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const PUBLICATION_DELAY_MS = 15 * 60 * 1000;
const PUBLICATION_HOURS = [2, 5, 8, 11, 14, 17, 20, 23];

const forecastItemSchema = z.object({
  baseDate: z.coerce.string(),
  baseTime: z.coerce.string(),
  category: z.coerce.string(),
  fcstDate: z.coerce.string(),
  fcstTime: z.coerce.string(),
  fcstValue: z.union([z.string(), z.number()]).transform(String),
  nx: z.coerce.number(),
  ny: z.coerce.number(),
});

const forecastResponseSchema = z.object({
  response: z.object({
    header: z.object({
      resultCode: z.coerce.string(),
      resultMsg: z.coerce.string(),
    }),
    body: z
      .object({
        items: z.object({
          item: z.array(forecastItemSchema),
        }),
      })
      .optional(),
  }),
});

export type KmaForecastItem = z.infer<typeof forecastItemSchema>;

interface KmaWeatherProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  now?: () => Date;
  timeoutMs?: number;
}

interface BaseDateTime {
  baseDate: string;
  baseTime: string;
}

export class KmaWeatherProviderError extends Error {
  constructor(
    message: string,
    readonly retryable = false,
  ) {
    super(message);
    this.name = 'KmaWeatherProviderError';
  }
}

export class KmaWeatherProvider implements WeatherProvider {
  private readonly serviceKey: string;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;
  private readonly timeoutMs: number;

  constructor(options: KmaWeatherProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher = options.fetcher ?? fetch;
    this.now = options.now ?? (() => new Date());
    this.timeoutMs = options.timeoutMs ?? 8_000;
  }

  async getForecastByRegion(nx: number, ny: number): Promise<WeatherForecast> {
    if (!this.serviceKey) {
      throw new KmaWeatherProviderError('KMA service key is not configured');
    }
    if (!Number.isInteger(nx) || !Number.isInteger(ny)) {
      throw new KmaWeatherProviderError('KMA grid coordinates must be integers');
    }

    const now = this.now();
    let lastError: unknown;
    for (const base of latestBaseDateTimes(now, 4)) {
      try {
        const items = await this.fetchForecastItems(base, nx, ny);
        return buildForecastFromItems(items, now, base);
      } catch (error) {
        lastError = error;
        if (!(error instanceof KmaWeatherProviderError) || !error.retryable) {
          throw error;
        }
      }
    }

    throw new KmaWeatherProviderError(
      lastError instanceof Error
        ? lastError.message
        : 'KMA forecast is not available',
    );
  }

  private async fetchForecastItems(
    base: BaseDateTime,
    nx: number,
    ny: number,
  ): Promise<KmaForecastItem[]> {
    const query = new URLSearchParams({
      serviceKey: this.serviceKey,
      pageNo: '1',
      numOfRows: '1000',
      dataType: 'JSON',
      base_date: base.baseDate,
      base_time: base.baseTime,
      nx: String(nx),
      ny: String(ny),
    });
    const response = await this.fetcher(`${KMA_FORECAST_URL}?${query}`, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(this.timeoutMs),
    });

    if (!response.ok) {
      throw new KmaWeatherProviderError(
        `KMA request failed with status ${response.status}`,
      );
    }

    const payload: unknown = await response.json();
    const parsed = forecastResponseSchema.safeParse(payload);
    if (!parsed.success) {
      throw new KmaWeatherProviderError('KMA response schema is invalid');
    }

    const { header, body } = parsed.data.response;
    if (header.resultCode !== '00') {
      const noData = header.resultCode === '03' || /NO_DATA/i.test(header.resultMsg);
      throw new KmaWeatherProviderError(
        `KMA returned ${header.resultCode}: ${header.resultMsg}`,
        noData,
      );
    }
    if (!body || body.items.item.length === 0) {
      throw new KmaWeatherProviderError('KMA returned no forecast items', true);
    }
    return body.items.item;
  }
}

export function latestBaseDateTimes(
  now: Date,
  limit: number,
): BaseDateTime[] {
  const effectiveKst = new Date(
    now.getTime() + KST_OFFSET_MS - PUBLICATION_DELAY_MS,
  );
  const candidates: BaseDateTime[] = [];

  for (let dayOffset = 0; candidates.length < limit && dayOffset < 3; dayOffset += 1) {
    const date = new Date(
      Date.UTC(
        effectiveKst.getUTCFullYear(),
        effectiveKst.getUTCMonth(),
        effectiveKst.getUTCDate() - dayOffset,
      ),
    );
    const currentMinutes =
      effectiveKst.getUTCHours() * 60 + effectiveKst.getUTCMinutes();

    for (const hour of [...PUBLICATION_HOURS].reverse()) {
      if (dayOffset === 0 && hour * 60 > currentMinutes) continue;
      candidates.push({
        baseDate: formatKmaDate(date),
        baseTime: `${String(hour).padStart(2, '0')}00`,
      });
      if (candidates.length === limit) break;
    }
  }
  return candidates;
}

export function buildForecastFromItems(
  items: KmaForecastItem[],
  now: Date,
  base: BaseDateTime,
): WeatherForecast {
  const slots = new Map<string, Map<string, string>>();
  for (const item of items) {
    const slotKey = `${item.fcstDate}${item.fcstTime.padStart(4, '0')}`;
    const categories = slots.get(slotKey) ?? new Map<string, string>();
    categories.set(item.category, item.fcstValue);
    slots.set(slotKey, categories);
  }

  const allHourly = [...slots.entries()]
    .map(([slotKey, categories]) => snapshotFromSlot(slotKey, categories))
    .filter((snapshot): snapshot is WeatherSnapshot => snapshot !== null)
    .sort((left, right) => left.observedAt.localeCompare(right.observedAt));

  const cutoff = now.getTime() - 30 * 60 * 1000;
  const hourly = allHourly
    .filter((snapshot) => Date.parse(snapshot.observedAt) >= cutoff)
    .slice(0, 48);
  if (hourly.length === 0) {
    throw new KmaWeatherProviderError('KMA forecast has no current slots', true);
  }

  const today = formatKmaDate(new Date(now.getTime() + KST_OFFSET_MS));
  const daily = buildDailyForecast(items, allHourly)
    .filter((item) => item.date >= today)
    .slice(0, 4);
  const todaySummary = daily.find((item) => item.date === today);
  const current: WeatherSnapshot = {
    ...hourly[0],
    minTemperature: todaySummary?.minTemperature,
    maxTemperature: todaySummary?.maxTemperature,
  };

  return {
    current,
    hourly,
    daily,
    baseDate: base.baseDate,
    baseTime: base.baseTime,
    dataSource: KMA_DATA_SOURCE,
  };
}

function snapshotFromSlot(
  slotKey: string,
  categories: Map<string, string>,
): WeatherSnapshot | null {
  const temperature = numericValue(categories.get('TMP'));
  if (temperature === undefined) return null;

  const humidity = numericValue(categories.get('REH'));
  const windSpeed = numericValue(categories.get('WSD'));
  const precipitationProbability = numericValue(categories.get('POP')) ?? 0;
  const precipitationType = numericValue(categories.get('PTY')) ?? 0;
  const snowfallAmount = parsePrecipitationAmount(categories.get('SNO'));

  return {
    observedAt: kmaSlotToIso(slotKey),
    temperature,
    apparentTemperature: apparentTemperature(
      temperature,
      humidity,
      windSpeed,
    ),
    humidity,
    windSpeed,
    precipitationProbability,
    precipitationAmount: parsePrecipitationAmount(categories.get('PCP')),
    snowProbability: isSnowType(precipitationType)
      ? precipitationProbability
      : 0,
    snowfallAmount,
    skyCondition: weatherLabel(
      precipitationType,
      numericValue(categories.get('SKY')),
    ),
  };
}

function buildDailyForecast(
  items: KmaForecastItem[],
  hourly: WeatherSnapshot[],
): DailyWeatherForecast[] {
  const categoriesByDate = new Map<string, Map<string, string[]>>();
  for (const item of items) {
    const categories = categoriesByDate.get(item.fcstDate) ?? new Map();
    const values = categories.get(item.category) ?? [];
    values.push(item.fcstValue);
    categories.set(item.category, values);
    categoriesByDate.set(item.fcstDate, categories);
  }

  return [...categoriesByDate.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([date, categories]) => {
      const snapshots = hourly.filter(
        (snapshot) => compactDate(snapshot.observedAt) === date,
      );
      const temperatures = snapshots
        .map((snapshot) => snapshot.temperature)
        .filter((value): value is number => value !== undefined);
      const minTemperature =
        firstNumeric(categories.get('TMN')) ?? minimum(temperatures);
      const maxTemperature =
        firstNumeric(categories.get('TMX')) ?? maximum(temperatures);
      const precipitationProbability = maximum(
        snapshots.map((snapshot) => snapshot.precipitationProbability ?? 0),
      ) ?? 0;
      const snowProbability = maximum(
        snapshots.map((snapshot) => snapshot.snowProbability ?? 0),
      ) ?? 0;

      return {
        date,
        minTemperature,
        maxTemperature,
        skyCondition: representativeWeather(snapshots),
        precipitationProbability,
        precipitationAmount: snapshots.reduce(
          (sum, snapshot) => sum + (snapshot.precipitationAmount ?? 0),
          0,
        ),
        snowProbability,
        snowfallAmount: snapshots.reduce(
          (sum, snapshot) => sum + (snapshot.snowfallAmount ?? 0),
          0,
        ),
      };
    });
}

export function parsePrecipitationAmount(value?: string): number {
  if (!value || /없음/.test(value)) return 0;
  const match = value.replace(',', '.').match(/\d+(?:\.\d+)?/);
  return match ? Number(match[0]) : 0;
}

function normalizeServiceKey(value: string): string {
  const trimmed = value.trim();
  try {
    return decodeURIComponent(trimmed);
  } catch {
    return trimmed;
  }
}

function numericValue(value?: string): number | undefined {
  if (value === undefined) return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function firstNumeric(values?: string[]): number | undefined {
  if (!values) return undefined;
  for (const value of values) {
    const parsed = numericValue(value);
    if (parsed !== undefined) return parsed;
  }
  return undefined;
}

function minimum(values: number[]): number | undefined {
  return values.length === 0 ? undefined : Math.min(...values);
}

function maximum(values: number[]): number | undefined {
  return values.length === 0 ? undefined : Math.max(...values);
}

function formatKmaDate(date: Date): string {
  return `${date.getUTCFullYear()}${String(date.getUTCMonth() + 1).padStart(2, '0')}${String(date.getUTCDate()).padStart(2, '0')}`;
}

function kmaSlotToIso(slotKey: string): string {
  const date = slotKey.slice(0, 8);
  const time = slotKey.slice(8, 12);
  return `${date.slice(0, 4)}-${date.slice(4, 6)}-${date.slice(6, 8)}T${time.slice(0, 2)}:${time.slice(2, 4)}:00+09:00`;
}

function compactDate(iso: string): string {
  return `${iso.slice(0, 4)}${iso.slice(5, 7)}${iso.slice(8, 10)}`;
}

function isSnowType(precipitationType: number): boolean {
  return [2, 3, 6, 7].includes(precipitationType);
}

function weatherLabel(
  precipitationType: number,
  skyCode?: number,
): string {
  const precipitationLabels: Record<number, string> = {
    1: '비',
    2: '비/눈',
    3: '눈',
    4: '소나기',
    5: '빗방울',
    6: '빗방울/눈날림',
    7: '눈날림',
  };
  if (precipitationLabels[precipitationType]) {
    return precipitationLabels[precipitationType];
  }
  return { 1: '맑음', 3: '구름 많음', 4: '흐림' }[skyCode ?? 1] ?? '맑음';
}

function representativeWeather(snapshots: WeatherSnapshot[]): string {
  const priority = [
    '눈',
    '비/눈',
    '소나기',
    '비',
    '눈날림',
    '빗방울/눈날림',
    '빗방울',
    '흐림',
    '구름 많음',
    '맑음',
  ];
  for (const label of priority) {
    if (snapshots.some((snapshot) => snapshot.skyCondition === label)) {
      return label;
    }
  }
  return '정보 없음';
}

function apparentTemperature(
  temperature: number,
  humidity?: number,
  windSpeed?: number,
): number {
  if (temperature <= 10 && (windSpeed ?? 0) > 1.3) {
    const windKmh = (windSpeed ?? 0) * 3.6;
    return roundOne(
      13.12 +
        0.6215 * temperature -
        11.37 * windKmh ** 0.16 +
        0.3965 * temperature * windKmh ** 0.16,
    );
  }
  if (temperature >= 27 && humidity !== undefined) {
    const fahrenheit = (temperature * 9) / 5 + 32;
    const heatIndexF =
      -42.379 +
      2.04901523 * fahrenheit +
      10.14333127 * humidity -
      0.22475541 * fahrenheit * humidity -
      0.00683783 * fahrenheit ** 2 -
      0.05481717 * humidity ** 2 +
      0.00122874 * fahrenheit ** 2 * humidity +
      0.00085282 * fahrenheit * humidity ** 2 -
      0.00000199 * fahrenheit ** 2 * humidity ** 2;
    return roundOne(((heatIndexF - 32) * 5) / 9);
  }
  return roundOne(temperature);
}

function roundOne(value: number): number {
  return Math.round(value * 10) / 10;
}
