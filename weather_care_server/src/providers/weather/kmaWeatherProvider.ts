import { z } from 'zod';
import {
  AmountRange,
  PrecipitationType,
  WeatherSnapshot,
} from '../../types';
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

interface ForecastItemsAtBase {
  base: BaseDateTime;
  items: KmaForecastItem[];
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
    this.fetcher =
      options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.now = options.now ?? (() => new Date());
    this.timeoutMs = options.timeoutMs ?? 8_000;
  }

  async getForecastByRegion(nx: number, ny: number): Promise<WeatherForecast> {
    return this.loadForecast(nx, ny, true);
  }

  async getLatestForecastByRegion(
    nx: number,
    ny: number,
  ): Promise<WeatherForecast> {
    return this.loadForecast(nx, ny, false);
  }

  private async loadForecast(
    nx: number,
    ny: number,
    includeDailyCoverage: boolean,
  ): Promise<WeatherForecast> {
    if (!this.serviceKey) {
      throw new KmaWeatherProviderError('KMA service key is not configured');
    }
    if (!Number.isInteger(nx) || !Number.isInteger(ny)) {
      throw new KmaWeatherProviderError('KMA grid coordinates must be integers');
    }

    const now = this.now();
    const requests = new Map<string, Promise<KmaForecastItem[]>>();
    const fetchItems = (base: BaseDateTime) => {
      const key = `${base.baseDate}${base.baseTime}`;
      const existing = requests.get(key);
      if (existing) return existing;
      const pending = this.fetchForecastItems(base, nx, ny);
      requests.set(key, pending);
      return pending;
    };

    const latestPromise = firstAvailableForecastItems(
      latestBaseDateTimes(now, 4),
      fetchItems,
    );
    const coveragePromise = includeDailyCoverage
      ? firstAvailableForecastItems(
          dailyCoverageBaseDateTimes(now),
          fetchItems,
          true,
        ).catch(() => undefined)
      : Promise.resolve(undefined);
    const latest = await latestPromise;
    const coverage = await coveragePromise;
    const items = coverage
      ? mergeForecastItems(coverage.items, latest.items)
      : latest.items;
    return buildForecastFromItems(
      items,
      now,
      latest.base,
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

export function dailyCoverageBaseDateTimes(now: Date): BaseDateTime[] {
  const targetKst = new Date(now.getTime() + KST_OFFSET_MS);
  const effectiveKst = new Date(
    now.getTime() + KST_OFFSET_MS - PUBLICATION_DELAY_MS,
  );
  const targetDate = formatKmaDate(targetKst);
  const effectiveDate = formatKmaDate(effectiveKst);
  const effectiveMinutes =
    effectiveKst.getUTCHours() * 60 + effectiveKst.getUTCMinutes();
  const previousDate = new Date(
    Date.UTC(
      targetKst.getUTCFullYear(),
      targetKst.getUTCMonth(),
      targetKst.getUTCDate() - 1,
    ),
  );
  const candidates: BaseDateTime[] = [];

  if (effectiveDate === targetDate && effectiveMinutes >= 2 * 60) {
    candidates.push({ baseDate: targetDate, baseTime: '0200' });
  }
  candidates.push(
    { baseDate: formatKmaDate(previousDate), baseTime: '2300' },
    { baseDate: formatKmaDate(previousDate), baseTime: '2000' },
  );
  return candidates;
}

async function firstAvailableForecastItems(
  bases: BaseDateTime[],
  fetchItems: (base: BaseDateTime) => Promise<KmaForecastItem[]>,
  retryAllErrors = false,
): Promise<ForecastItemsAtBase> {
  let lastError: unknown;
  for (const base of bases) {
    try {
      return { base, items: await fetchItems(base) };
    } catch (error) {
      lastError = error;
      if (
        !retryAllErrors &&
        (!(error instanceof KmaWeatherProviderError) || !error.retryable)
      ) {
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

function mergeForecastItems(
  older: KmaForecastItem[],
  newer: KmaForecastItem[],
): KmaForecastItem[] {
  const merged = new Map<string, KmaForecastItem>();
  for (const item of [...older, ...newer]) {
    merged.set(
      `${item.fcstDate}${item.fcstTime.padStart(4, '0')}:${item.category}`,
      item,
    );
  }
  return [...merged.values()];
}

export function buildForecastFromItems(
  items: KmaForecastItem[],
  now: Date,
  base: BaseDateTime,
): WeatherForecast {
  const slots = new Map<
    string,
    { categories: Map<string, string>; base: BaseDateTime }
  >();
  for (const item of items) {
    const slotKey = `${item.fcstDate}${item.fcstTime.padStart(4, '0')}`;
    const itemBase = {
      baseDate: item.baseDate,
      baseTime: item.baseTime.padStart(4, '0'),
    };
    const slot = slots.get(slotKey) ?? {
      categories: new Map<string, string>(),
      base: itemBase,
    };
    slot.categories.set(item.category, item.fcstValue);
    if (
      `${itemBase.baseDate}${itemBase.baseTime}` >=
      `${slot.base.baseDate}${slot.base.baseTime}`
    ) {
      slot.base = itemBase;
    }
    slots.set(slotKey, slot);
  }

  const allHourly = [...slots.entries()]
    .map(([slotKey, slot]) =>
      snapshotFromSlot(slotKey, slot.categories, slot.base, now),
    )
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
  const tomorrow = formatKmaDate(
    new Date(now.getTime() + KST_OFFSET_MS + 86_400_000),
  );
  const timelineHourly = allHourly.filter((snapshot) => {
    const date = compactDate(snapshot.observedAt);
    return date === today ||
      (date === tomorrow && snapshot.observedAt.slice(11, 16) === '00:00');
  });
  const daily = buildDailyForecast(items, allHourly, base)
    .filter((item) => item.date >= today)
    // 17·20·23시 발표분은 오늘부터 그글피까지 최대 5개 날짜다.
    .slice(0, 5);
  const todaySummary = daily.find((item) => item.date === today);
  const current: WeatherSnapshot = {
    ...hourly[0],
    minTemperature: todaySummary?.minTemperature,
    maxTemperature: todaySummary?.maxTemperature,
  };

  return {
    current,
    hourly,
    timelineHourly,
    daily,
    baseDate: base.baseDate,
    baseTime: base.baseTime,
    dataSource: KMA_DATA_SOURCE,
  };
}

function snapshotFromSlot(
  slotKey: string,
  categories: Map<string, string>,
  base: BaseDateTime,
  fetchedAt: Date,
): WeatherSnapshot | null {
  // Retain a weather slot when TMP alone is missing; omit TMN/TMX-only slots.
  const hourlyCategories = ['TMP', 'REH', 'WSD', 'POP', 'PTY', 'PCP', 'SNO', 'SKY'];
  if (!hourlyCategories.some((category) => categories.has(category))) return null;
  const temperature = numericValue(categories.get('TMP'));

  const humidity = numericValue(categories.get('REH'));
  const windSpeed = numericValue(categories.get('WSD'));
  const precipitationProbability = numericValue(categories.get('POP'));
  const rawPrecipitationCode = numericValue(categories.get('PTY'));
  const precipitationCode = rawPrecipitationCode !== undefined &&
    Number.isInteger(rawPrecipitationCode) && rawPrecipitationCode >= 0 && rawPrecipitationCode <= 7
    ? rawPrecipitationCode : undefined;
  const precipitationType = precipitationCode === undefined
    ? undefined : normalizePrecipitationType(precipitationCode);
  const precipitationAmountRange = parseAmountRange(
    categories.get('PCP'),
    'MM',
  );
  const snowfallAmountRange = parseAmountRange(categories.get('SNO'), 'CM');
  const snowExpected = (precipitationCode !== undefined && isSnowType(precipitationCode)) ||
    (snowfallAmountRange?.min ?? 0) > 0
    ? true : precipitationCode === undefined ? undefined : false;
  const forecastAt = kmaSlotToIso(slotKey);
  const calculatedApparentTemperature = temperature === undefined ? undefined : apparentTemperature(
    temperature,
    humidity,
    windSpeed,
    forecastAt,
  );
  const qualityFlags = [
    ifUndefined(categories.get('PCP'), 'MISSING_PCP'),
    ifUndefined(categories.get('SNO'), 'MISSING_SNO'),
  ].filter((flag): flag is string => flag !== undefined);

  return {
    observedAt: forecastAt,
    dataRole: 'FORECAST',
    forecastAt,
    validFrom: forecastAt,
    precipitationPeriod: hourlyPrecipitationPeriod(forecastAt, base),
    validTo: endOfKmaSlot(forecastAt),
    issuedAt: kmaBaseToIso(base),
    fetchedAt: fetchedAt.toISOString(),
    temperature,
    apparentTemperature: calculatedApparentTemperature,
    apparentTemperatureSource:
      calculatedApparentTemperature === undefined
        ? undefined
        : 'APP_KMA_METHOD_FROM_FORECAST',
    apparentTemperatureFormulaVersion:
      calculatedApparentTemperature === undefined
        ? undefined
        : 'KMA_APPARENT_TEMPERATURE_2026.1',
    humidity,
    windSpeed,
    windDirection: numericValue(categories.get('VEC')),
    precipitationType,
    precipitationProbability,
    precipitationAmount: precipitationAmountRange?.min,
    precipitationAmountRange,
    snowProbability: snowExpected === undefined ? undefined
      : snowExpected ? precipitationProbability : 0,
    snowExpected,
    snowfallAmount: snowfallAmountRange?.min,
    snowfallAmountRange,
    skyCondition: weatherLabel(
      precipitationCode,
      numericValue(categories.get('SKY')),
    ),
    provider: 'KMA',
    providerField: 'TMP,REH,WSD,VEC,POP,PTY,PCP,SNO,SKY',
    rawValue: {
      precipitationAmount: categories.get('PCP') ?? '',
      snowfallAmount: categories.get('SNO') ?? '',
      precipitationType: categories.get('PTY') ?? '',
    },
    qualityFlags,
  };
}

function buildDailyForecast(
  items: KmaForecastItem[],
  hourly: WeatherSnapshot[],
  base: BaseDateTime,
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
      const humidities = snapshots
        .map((snapshot) => snapshot.humidity)
        .filter((value): value is number => value !== undefined);
      const windSpeeds = snapshots
        .map((snapshot) => snapshot.windSpeed)
        .filter((value): value is number => value !== undefined);
      const snowfallDataAvailable = snapshots.some(
        (snapshot) => snapshot.snowfallAmountRange !== undefined,
      );

      return {
        date,
        forecastSource: 'KMA_SHORT_TERM',
        issuedAt: kmaBaseToIso(base),
        precipitationDetail: dailyPrecipitationDetail(date, hourly, base),
        minTemperature,
        maxTemperature,
        minTemperatureSource: minTemperature === undefined ? undefined
          : firstNumeric(categories.get('TMN')) === undefined ? 'HOURLY' : 'DAILY',
        maxTemperatureSource: maxTemperature === undefined ? undefined
          : firstNumeric(categories.get('TMX')) === undefined ? 'HOURLY' : 'DAILY',
        averageHumidity: average(humidities),
        maximumWindSpeed: maximum(windSpeeds),
        snowfallDataAvailable,
        weatherDataComplete: snapshots.length > 0 &&
          snapshots.every((snapshot) => snapshot.skyCondition !== undefined) &&
          (Date.parse(snapshots[snapshots.length - 1].observedAt) - Date.parse(snapshots[0].observedAt)) / 3_600_000 + 1 === snapshots.length,
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

function dailyPrecipitationDetail(
  date: string,
  hourly: WeatherSnapshot[],
  base: BaseDateTime,
): NonNullable<DailyWeatherForecast['precipitationDetail']> {
  const extendedStart = new Date(kmaBaseToIso({ ...base, baseTime: '0000' }));
  extendedStart.setUTCDate(extendedStart.getUTCDate() + (Number(base.baseTime) < 1700 ? 3 : 4));
  const isExtended = date >= formatKmaDate(new Date(extendedStart.getTime() + KST_OFFSET_MS));
  const validProbability = (value: number | undefined) =>
    value !== undefined && Number.isFinite(value) && value >= 0 && value <= 100 ? value : undefined;
  if (isExtended) {
    const probabilities = hourly.filter((snapshot) =>
      formatKmaDate(new Date(Date.parse(snapshot.observedAt) + KST_OFFSET_MS - 3_600_000)) === date)
      .map((snapshot) => validProbability(snapshot.precipitationProbability))
      .filter((value): value is number => value !== undefined);
    return { kind: 'EXTENDED', hours: [], extendedMaxProbability: maximum(probabilities) };
  }
  return {
    kind: 'HOURLY',
    hours: hourly.filter((snapshot) => {
      // KMA PCP/POP at 00:00 cover 23:00–24:00 on the previous Korean date.
      const startKst = new Date(Date.parse(snapshot.observedAt) + KST_OFFSET_MS - 3_600_000);
      return formatKmaDate(startKst) === date;
    }).map((snapshot) => ({
      forecastAt: snapshot.observedAt,
      probability: validProbability(snapshot.precipitationProbability),
      amountText: typeof snapshot.rawValue === 'object' && snapshot.rawValue !== null
        && 'precipitationAmount' in snapshot.rawValue
        && typeof snapshot.rawValue.precipitationAmount === 'string'
        ? snapshot.rawValue.precipitationAmount : undefined,
    })),
  };
}

function hourlyPrecipitationPeriod(forecastAt: string, base: BaseDateTime): WeatherSnapshot['precipitationPeriod'] {
  const end = Date.parse(forecastAt);
  const start = end - 3_600_000;
  const extendedStart = Date.parse(kmaBaseToIso({ ...base, baseTime: '0000' })) +
    (Number(base.baseTime) < 1700 ? 3 : 4) * 86_400_000;
  if (!Number.isFinite(end) || start >= extendedStart) return null;
  return { start: new Date(start).toISOString(), end: forecastAt };
}

export function parsePrecipitationAmount(value?: string): number {
  return parseAmountRange(value, 'MM')?.min ?? 0;
}

export function parseAmountRange(
  value: string | undefined,
  unit: 'MM' | 'CM',
): AmountRange | undefined {
  if (value === undefined) return undefined;
  const normalized = value.trim().replaceAll(',', '.');
  if (!normalized || /없음/.test(normalized)) {
    return { type: 'NONE', min: 0, max: 0, unit, rawValue: value };
  }

  const numbers = [...normalized.matchAll(/\d+(?:\.\d+)?/g)].map((match) =>
    Number(match[0]),
  );
  if (numbers.length === 0) return undefined;
  if (/미만/.test(normalized)) {
    return {
      type: 'LESS_THAN',
      min: 0,
      max: numbers[0],
      unit,
      rawValue: value,
    };
  }
  if (/이상/.test(normalized)) {
    return { type: 'AT_LEAST', min: numbers[0], unit, rawValue: value };
  }
  if (numbers.length >= 2 && /[~-]/.test(normalized)) {
    return {
      type: 'RANGE',
      min: Math.min(numbers[0], numbers[1]),
      max: Math.max(numbers[0], numbers[1]),
      unit,
      rawValue: value,
    };
  }
  return {
    type: 'VALUE',
    min: numbers[0],
    max: numbers[0],
    unit,
    rawValue: value,
  };
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
  if (value === undefined || value.trim() === '') return undefined;
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

function average(values: number[]): number | undefined {
  if (values.length === 0) return undefined;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function formatKmaDate(date: Date): string {
  return `${date.getUTCFullYear()}${String(date.getUTCMonth() + 1).padStart(2, '0')}${String(date.getUTCDate()).padStart(2, '0')}`;
}

function kmaSlotToIso(slotKey: string): string {
  const date = slotKey.slice(0, 8);
  const time = slotKey.slice(8, 12);
  return `${date.slice(0, 4)}-${date.slice(4, 6)}-${date.slice(6, 8)}T${time.slice(0, 2)}:${time.slice(2, 4)}:00+09:00`;
}

function endOfKmaSlot(forecastAt: string): string {
  return `${forecastAt.slice(0, 14)}59:59+09:00`;
}

function kmaBaseToIso(base: BaseDateTime): string {
  return `${base.baseDate.slice(0, 4)}-${base.baseDate.slice(4, 6)}-${base.baseDate.slice(6, 8)}T${base.baseTime.slice(0, 2)}:${base.baseTime.slice(2, 4)}:00+09:00`;
}

function compactDate(iso: string): string {
  return `${iso.slice(0, 4)}${iso.slice(5, 7)}${iso.slice(8, 10)}`;
}

function isSnowType(precipitationType: number): boolean {
  return [2, 3, 6, 7].includes(precipitationType);
}

function normalizePrecipitationType(code: number): PrecipitationType {
  if ([2, 6].includes(code)) return 'RAIN_SNOW';
  if ([3, 7].includes(code)) return 'SNOW';
  if (code === 4) return 'SHOWER';
  if ([1, 5].includes(code)) return 'RAIN';
  return 'NONE';
}

function ifUndefined(
  value: string | undefined,
  flag: string,
): string | undefined {
  return value === undefined ? flag : undefined;
}

function weatherLabel(
  precipitationType: number | undefined,
  skyCode?: number,
): string | undefined {
  const precipitationLabels: Record<number, string> = {
    1: '비',
    2: '비/눈',
    3: '눈',
    4: '소나기',
    5: '빗방울',
    6: '빗방울/눈날림',
    7: '눈날림',
  };
  if (precipitationType === undefined) return undefined;
  if (precipitationLabels[precipitationType]) {
    return precipitationLabels[precipitationType];
  }
  return precipitationType === 0 && skyCode !== undefined
    ? { 1: '맑음', 3: '구름 많음', 4: '흐림' }[skyCode] : undefined;
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

export function calculateKmaApparentTemperature(
  temperature: number,
  humidity?: number,
  windSpeed?: number,
  forecastAt?: string,
): number {
  const month = forecastAt === undefined
    ? undefined
    : Number(forecastAt.slice(5, 7));
  const isSummer = month !== undefined && month >= 5 && month <= 9;
  const isWinter = month !== undefined && (month >= 10 || month <= 4);

  if (isWinter && temperature <= 10 && (windSpeed ?? 0) >= 1.3) {
    const windKmh = (windSpeed ?? 0) * 3.6;
    return roundOne(
      13.12 +
        0.6215 * temperature -
        11.37 * windKmh ** 0.16 +
        0.3965 * temperature * windKmh ** 0.16,
    );
  }
  if (isSummer && humidity !== undefined) {
    const relativeHumidity = Math.min(100, Math.max(0, humidity));
    const wetBulbTemperature =
      temperature *
        Math.atan(0.151977 * Math.sqrt(relativeHumidity + 8.313659)) +
      Math.atan(temperature + relativeHumidity) -
      Math.atan(relativeHumidity - 1.67633) +
      0.00391838 * relativeHumidity ** 1.5 *
        Math.atan(0.023101 * relativeHumidity) -
      4.686035;
    return roundOne(
      -0.2442 +
        0.55399 * wetBulbTemperature +
        0.45535 * temperature -
        0.0022 * wetBulbTemperature ** 2 +
        0.00278 * wetBulbTemperature * temperature +
        3.0,
    );
  }
  return roundOne(temperature);
}

function apparentTemperature(
  temperature: number,
  humidity?: number,
  windSpeed?: number,
  forecastAt?: string,
): number | undefined {
  const month = forecastAt === undefined
    ? undefined
    : Number(forecastAt.slice(5, 7));
  const summerInputsAvailable =
    month !== undefined &&
    month >= 5 &&
    month <= 9 &&
    humidity !== undefined;
  const winterInputsAvailable =
    month !== undefined &&
    (month >= 10 || month <= 4) &&
    temperature <= 10 &&
    windSpeed !== undefined &&
    windSpeed >= 1.3;
  if (!summerInputsAvailable && !winterInputsAvailable) return undefined;
  return calculateKmaApparentTemperature(
    temperature,
    humidity,
    windSpeed,
    forecastAt,
  );
}

function roundOne(value: number): number {
  return Math.round(value * 10) / 10;
}
