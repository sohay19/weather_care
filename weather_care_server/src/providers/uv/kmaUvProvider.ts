import { z } from 'zod';
import { UvForecast, UvForecastPoint, UvProvider } from './uvProvider';

const KMA_UV_URL =
  'https://apis.data.go.kr/1360000/LivingWthrIdxServiceV5/getUVIdxV5';
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const PUBLICATION_DELAY_MS = 30 * 60 * 1000;
const PUBLICATION_INTERVAL_HOURS = 3;
const UV_OFFSETS = Array.from({ length: 26 }, (_, index) => index * 3);

const uvItemSchema = z
  .object({
    areaNo: z.coerce.string(),
    date: z.coerce.string(),
  })
  .catchall(z.union([z.string(), z.number(), z.null()]));

const uvResponseSchema = z.object({
  response: z.object({
    header: z.object({
      resultCode: z.coerce.string(),
      resultMsg: z.coerce.string(),
    }),
    body: z
      .object({
        items: z.object({
          item: z.union([uvItemSchema, z.array(uvItemSchema)]),
        }),
      })
      .optional(),
  }),
});

const portalErrorSchema = z.object({
  OpenAPI_ServiceResponse: z.object({
    cmmMsgHeader: z.object({
      errMsg: z.coerce.string(),
      returnAuthMsg: z.coerce.string(),
      returnReasonCode: z.coerce.string(),
    }),
  }),
});

interface KmaUvProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  now?: () => Date;
  timeoutMs?: number;
}

export class KmaUvProviderError extends Error {
  constructor(
    message: string,
    readonly retryable = false,
  ) {
    super(message);
    this.name = 'KmaUvProviderError';
  }
}

export class KmaUvProvider implements UvProvider {
  private readonly serviceKey: string;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;
  private readonly timeoutMs: number;

  constructor(options: KmaUvProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher =
      options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.now = options.now ?? (() => new Date());
    this.timeoutMs = options.timeoutMs ?? 6_000;
  }

  async getNationwide(): Promise<Record<string, UvForecast>> {
    if (!this.serviceKey) throw new KmaUvProviderError('KMA living-index key is not configured');
    const time = latestUvPublicationTimes(this.now(), 1)[0];
    const forecasts: Record<string, UvForecast> = {};
    let expectedTotal: number | undefined;
    for (let page = 1; page <= (expectedTotal === undefined ? 1 : Math.ceil(expectedTotal / 1000)); page++) {
      const query = new URLSearchParams({ ServiceKey: this.serviceKey, pageNo: String(page),
        numOfRows: '1000', dataType: 'JSON', areaNo: '', time });
      const response = await this.fetcher(`${KMA_UV_URL}?${query}`, { signal: AbortSignal.timeout(30_000) });
      if (!response.ok) throw new KmaUvProviderError(`KMA nationwide UV HTTP ${response.status}`);
      const payload: unknown = await response.json();
      const parsed = uvResponseSchema.safeParse(payload);
      const total = Number((payload as { response?: { body?: { totalCount?: unknown } } })?.response?.body?.totalCount);
      if (!parsed.success || parsed.data.response.header.resultCode !== '00' || !parsed.data.response.body ||
          !Number.isInteger(total) || total <= 0 || total > 10_000 || (expectedTotal !== undefined && expectedTotal !== total)) {
        throw new KmaUvProviderError('KMA nationwide UV pagination is invalid');
      }
      expectedTotal = total;
      const raw = parsed.data.response.body.items.item;
      for (const item of Array.isArray(raw) ? raw : [raw]) {
        if (!/^\d{10}$/.test(item.areaNo) || item.date !== time || item.areaNo in forecasts) {
          throw new KmaUvProviderError('KMA nationwide UV area/time is invalid');
        }
        const issuedAt = kmaUvDateToIso(item.date);
        forecasts[item.areaNo] = { areaNo: item.areaNo, issuedAt,
          points: uvPointsFromItem(item, issuedAt), provider: 'KMA_LIVING_INDEX_V5' };
      }
    }
    if (Object.keys(forecasts).length !== expectedTotal) throw new KmaUvProviderError('KMA nationwide UV pages are incomplete');
    return forecasts;
  }

  async getForecast(areaNo: string): Promise<UvForecast> {
    if (!this.serviceKey) {
      throw new KmaUvProviderError('KMA living-index key is not configured');
    }
    if (!/^\d{10}$/.test(areaNo)) {
      throw new KmaUvProviderError('KMA UV area number must be 10 digits');
    }

    let lastError: unknown;
    for (const time of latestUvPublicationTimes(this.now(), 4)) {
      try {
        return await this.fetchForecast(areaNo, time);
      } catch (error) {
        lastError = error;
        if (!(error instanceof KmaUvProviderError) || !error.retryable) {
          throw error;
        }
      }
    }

    throw new KmaUvProviderError(
      lastError instanceof Error
        ? lastError.message
        : 'KMA UV forecast is not available',
    );
  }

  private async fetchForecast(
    areaNo: string,
    time: string,
  ): Promise<UvForecast> {
    const query = new URLSearchParams({
      ServiceKey: this.serviceKey,
      pageNo: '1',
      numOfRows: '10',
      dataType: 'JSON',
      areaNo,
      time,
    });
    const response = await this.fetcher(`${KMA_UV_URL}?${query}`, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    const payload: unknown = await response.json();
    const portalError = portalErrorSchema.safeParse(payload);
    if (portalError.success) {
      const header = portalError.data.OpenAPI_ServiceResponse.cmmMsgHeader;
      throw new KmaUvProviderError(
        `KMA UV authorization failed ${header.returnReasonCode}: ${header.errMsg}`,
      );
    }
    if (!response.ok) {
      throw new KmaUvProviderError(
        `KMA UV request failed with status ${response.status}`,
        response.status >= 500,
      );
    }

    const parsed = uvResponseSchema.safeParse(payload);
    if (!parsed.success) {
      throw new KmaUvProviderError('KMA UV response schema is invalid');
    }

    const { header, body } = parsed.data.response;
    if (header.resultCode !== '00') {
      const retryable =
        header.resultCode === '03' || /NO_DATA|NODATA/i.test(header.resultMsg);
      throw new KmaUvProviderError(
        `KMA UV returned ${header.resultCode}: ${header.resultMsg}`,
        retryable,
      );
    }
    if (!body) {
      throw new KmaUvProviderError('KMA UV returned no body', true);
    }

    const items = Array.isArray(body.items.item)
      ? body.items.item
      : [body.items.item];
    if (items.length === 0) {
      throw new KmaUvProviderError('KMA UV returned no items', true);
    }
    const item = items.find((candidate) => candidate.areaNo === areaNo) ?? items[0];
    const issuedAt = kmaUvDateToIso(item.date);
    const points = uvPointsFromItem(item, issuedAt);
    if (points.length === 0) {
      throw new KmaUvProviderError('KMA UV returned no numeric values', true);
    }

    return {
      areaNo: item.areaNo,
      issuedAt,
      points,
      provider: 'KMA_LIVING_INDEX_V5',
    };
  }
}

export function latestUvPublicationTimes(
  now: Date,
  limit: number,
): string[] {
  const effectiveKst = new Date(
    now.getTime() + KST_OFFSET_MS - PUBLICATION_DELAY_MS,
  );
  const flooredHour =
    Math.floor(effectiveKst.getUTCHours() / PUBLICATION_INTERVAL_HOURS) *
    PUBLICATION_INTERVAL_HOURS;
  const base = Date.UTC(
    effectiveKst.getUTCFullYear(),
    effectiveKst.getUTCMonth(),
    effectiveKst.getUTCDate(),
    flooredHour,
  );
  return Array.from({ length: limit }, (_, index) =>
    formatCompactKst(new Date(base - index * 3 * 60 * 60 * 1000)),
  );
}

function uvPointsFromItem(
  item: z.infer<typeof uvItemSchema>,
  issuedAt: string,
): UvForecastPoint[] {
  const base = Date.parse(issuedAt);
  return UV_OFFSETS.flatMap((offset) => {
    const uvIndex = numericValue(item[`h${offset}`]);
    if (uvIndex === undefined) return [];
    return [
      {
        forecastAt: formatKstIso(new Date(base + offset * 60 * 60 * 1000)),
        uvIndex,
      },
    ];
  });
}

function kmaUvDateToIso(value: string): string {
  if (!/^\d{10}$/.test(value)) {
    throw new KmaUvProviderError('KMA UV issue time is invalid');
  }
  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}T${value.slice(8, 10)}:00:00+09:00`;
}

function numericValue(value: unknown): number | undefined {
  if (value === undefined || value === null || (typeof value === 'string' && (!value.trim() || value === '-'))) return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 && parsed <= 30 ? parsed : undefined;
}

function normalizeServiceKey(value: string): string {
  const trimmed = value.trim();
  try {
    return decodeURIComponent(trimmed);
  } catch {
    return trimmed;
  }
}

function formatCompactKst(date: Date): string {
  return `${date.getUTCFullYear()}${String(date.getUTCMonth() + 1).padStart(2, '0')}${String(date.getUTCDate()).padStart(2, '0')}${String(date.getUTCHours()).padStart(2, '0')}`;
}

function formatKstIso(date: Date): string {
  const kst = new Date(date.getTime() + KST_OFFSET_MS);
  return `${kst.getUTCFullYear()}-${String(kst.getUTCMonth() + 1).padStart(2, '0')}-${String(kst.getUTCDate()).padStart(2, '0')}T${String(kst.getUTCHours()).padStart(2, '0')}:${String(kst.getUTCMinutes()).padStart(2, '0')}:00+09:00`;
}
