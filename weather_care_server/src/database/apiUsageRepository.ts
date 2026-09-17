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
): Promise<boolean> {
  if (requestCount <= 0 && responseBytes <= 0) return true;
  const usageDate = koreanDate(now);
  const total = await db.prepare(
    `SELECT COALESCE(SUM(request_count), 0) AS requestCount,
            COALESCE(SUM(response_bytes), 0) AS responseBytes
     FROM api_usage_daily WHERE usage_date = ?`,
  ).bind(usageDate).first<ApiUsageDaily>();
  if (
    Number(total?.requestCount ?? 0) + requestCount > APIHUB_DAILY_CALL_LIMIT ||
    Number(total?.responseBytes ?? 0) + responseBytes > APIHUB_DAILY_BYTE_LIMIT
  ) return false;

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
     FROM api_usage_daily WHERE usage_date = ?`,
  ).bind(koreanDate(now)).first<ApiUsageDaily>();
  return {
    requestCount: Number(row?.requestCount ?? 0),
    responseBytes: Number(row?.responseBytes ?? 0),
  };
}

function koreanDate(now: Date): string {
  return new Date(now.getTime() + 9 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
}
