const APIHUB_DAILY_CALL_LIMIT = 18_000;
const APIHUB_DAILY_BYTE_LIMIT = 4_500_000_000;

export interface ApiUsageDaily {
  requestCount: number;
  responseBytes: number;
}

export async function reserveApiHubBudget(
  db: D1Database,
  provider: string,
  requestCount: number,
  responseBytes: number,
  now = new Date(),
  options: {
    providerDailyByteLimit?: number;
    dailyByteLimit?: number;
  } = {},
): Promise<boolean> {
  if (requestCount <= 0 && responseBytes <= 0) return true;
  const usageDate = koreanDate(now);
  const total = await db.prepare(
    `SELECT COALESCE(SUM(request_count), 0) AS requestCount,
            COALESCE(SUM(response_bytes), 0) AS responseBytes
     FROM api_usage_daily
     WHERE usage_date = ? AND provider NOT LIKE 'ITS_%'`,
  ).bind(usageDate).first<ApiUsageDaily>();
  if (
    Number(total?.requestCount ?? 0) + requestCount > APIHUB_DAILY_CALL_LIMIT ||
    Number(total?.responseBytes ?? 0) + responseBytes >
      (options.dailyByteLimit ?? APIHUB_DAILY_BYTE_LIMIT)
  ) return false;
  if (options.providerDailyByteLimit !== undefined) {
    const providerUsage = await db.prepare(
      `SELECT COALESCE(SUM(response_bytes), 0) AS responseBytes
       FROM api_usage_daily WHERE usage_date = ? AND provider = ?`,
    ).bind(usageDate, provider).first<{ responseBytes: number }>();
    if (Number(providerUsage?.responseBytes ?? 0) + responseBytes >
        options.providerDailyByteLimit) return false;
  }

  await db.prepare(
    `INSERT INTO api_usage_daily
       (usage_date, provider, request_count, response_bytes, updated_at)
     VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(usage_date, provider) DO UPDATE SET
       request_count=request_count + excluded.request_count,
       response_bytes=response_bytes + excluded.response_bytes,
       updated_at=excluded.updated_at`,
  ).bind(
    usageDate,
    provider,
    requestCount,
    responseBytes,
    now.toISOString(),
  ).run();
  return true;
}

export async function getApiHubUsage(
  db: D1Database,
  now = new Date(),
): Promise<ApiUsageDaily> {
  const row = await db.prepare(
    `SELECT COALESCE(SUM(request_count), 0) AS requestCount,
            COALESCE(SUM(response_bytes), 0) AS responseBytes
     FROM api_usage_daily
     WHERE usage_date = ? AND provider NOT LIKE 'ITS_%'`,
  ).bind(koreanDate(now)).first<ApiUsageDaily>();
  return {
    requestCount: Number(row?.requestCount ?? 0),
    responseBytes: Number(row?.responseBytes ?? 0),
  };
}

export async function reserveMonthlyRequestBudget(
  db: D1Database,
  provider: string,
  requestCount: number,
  monthlyLimit: number,
  now = new Date(),
): Promise<boolean> {
  if (requestCount <= 0) return true;
  const usageDate = koreanDate(now);
  const monthPrefix = `${usageDate.slice(0, 7)}-%`;
  const total = await db.prepare(
    `SELECT COALESCE(SUM(request_count), 0) AS requestCount
     FROM api_usage_daily
     WHERE provider = ? AND usage_date LIKE ?`,
  ).bind(provider, monthPrefix).first<{ requestCount: number }>();
  if (Number(total?.requestCount ?? 0) + requestCount > monthlyLimit) return false;

  await db.prepare(
    `INSERT INTO api_usage_daily
       (usage_date, provider, request_count, response_bytes, updated_at)
     VALUES (?, ?, ?, 0, ?)
     ON CONFLICT(usage_date, provider) DO UPDATE SET
       request_count=request_count + excluded.request_count,
       updated_at=excluded.updated_at`,
  ).bind(usageDate, provider, requestCount, now.toISOString()).run();
  return true;
}

function koreanDate(now: Date): string {
  return new Date(now.getTime() + 9 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
}
