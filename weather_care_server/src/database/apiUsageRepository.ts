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
    retryDailyByteLimit?: number;
  } = {},
): Promise<boolean> {
  if (![requestCount, responseBytes].every((value) => Number.isSafeInteger(value) && value >= 0)) {
    throw new RangeError('INVALID_APIHUB_BUDGET_RESERVATION');
  }
  if (requestCount === 0 && responseBytes === 0) return true;
  const usageDate = koreanDate(now);
  // 검사와 예약을 한 SQL로 처리해 서로 다른 수집 프로세스가 한도를 넘기지 않게 한다.
  const result = await db.prepare(
    `INSERT INTO api_usage_daily
       (usage_date, provider, request_count, response_bytes, updated_at)
     SELECT ?, ?, ?, ?, ? WHERE
       (SELECT COALESCE(SUM(request_count), 0) FROM api_usage_daily
        WHERE usage_date = ? AND provider NOT LIKE 'ITS_%' AND provider NOT LIKE 'DATA_GO_%') + ? <= ?
       AND (SELECT COALESCE(SUM(response_bytes), 0) FROM api_usage_daily
        WHERE usage_date = ? AND provider NOT LIKE 'ITS_%' AND provider NOT LIKE 'DATA_GO_%') + ? <= ?
       AND (? IS NULL OR (SELECT COALESCE(SUM(response_bytes), 0) FROM api_usage_daily
        WHERE usage_date = ? AND provider = ?) + ? <= ?)
       AND (? IS NULL OR (SELECT COALESCE(SUM(response_bytes), 0) FROM api_usage_daily
        WHERE usage_date = ? AND (provider = 'APIHUB_RETRY' OR provider GLOB 'APIHUB_RETRY_*')) + ? <= ?)
     ON CONFLICT(usage_date, provider) DO UPDATE SET
       request_count=request_count + excluded.request_count,
       response_bytes=response_bytes + excluded.response_bytes,
       updated_at=excluded.updated_at`,
  ).bind(usageDate, provider, requestCount, responseBytes, now.toISOString(),
    usageDate, requestCount, APIHUB_DAILY_CALL_LIMIT,
    usageDate, responseBytes, options.dailyByteLimit ?? APIHUB_DAILY_BYTE_LIMIT,
    options.providerDailyByteLimit ?? null, usageDate, provider, responseBytes,
    options.providerDailyByteLimit ?? null,
    options.retryDailyByteLimit ?? null, usageDate, responseBytes, options.retryDailyByteLimit ?? null).run();
  return (result.meta.changes ?? 0) > 0;
}

export async function getApiHubUsage(
  db: D1Database,
  now = new Date(),
): Promise<ApiUsageDaily> {
  const row = await db.prepare(
    `SELECT COALESCE(SUM(request_count), 0) AS requestCount,
            COALESCE(SUM(response_bytes), 0) AS responseBytes
     FROM api_usage_daily
     WHERE usage_date = ? AND provider NOT LIKE 'ITS_%' AND provider NOT LIKE 'DATA_GO_%'`,
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

// 공공데이터포털 단기예보는 APIHub와 별도 계정·별도 한도로 예약한다.
export async function reservePointForecastRequest(db: D1Database, limit: number, now: Date): Promise<boolean> {
  if (!Number.isSafeInteger(limit) || limit < 1) throw new RangeError('INVALID_POINT_FORECAST_DAILY_LIMIT');
  const result = await db.prepare(`INSERT INTO api_usage_daily(usage_date,provider,request_count,response_bytes,updated_at)
    SELECT ?,'DATA_GO_POINT_FORECAST',1,0,? WHERE
      COALESCE((SELECT request_count FROM api_usage_daily WHERE usage_date=? AND provider='DATA_GO_POINT_FORECAST'),0) < ?
    ON CONFLICT(usage_date,provider) DO UPDATE SET request_count=request_count+1,updated_at=excluded.updated_at`)
    .bind(koreanDate(now), now.toISOString(), koreanDate(now), limit).run();
  return (result.meta.changes ?? 0) > 0;
}

// 중기예보 서비스는 단기예보·APIHub와 별도 일 한도로 관리한다.
export async function reserveMidTermRequest(db: D1Database, limit: number, now: Date): Promise<boolean> {
  if (!Number.isSafeInteger(limit) || limit < 1) throw new RangeError('INVALID_MID_TERM_DAILY_LIMIT');
  const result = await db.prepare(`INSERT INTO api_usage_daily(usage_date,provider,request_count,response_bytes,updated_at)
    SELECT ?,'DATA_GO_MID_TERM',1,0,? WHERE
      COALESCE((SELECT request_count FROM api_usage_daily WHERE usage_date=? AND provider='DATA_GO_MID_TERM'),0) < ?
    ON CONFLICT(usage_date,provider) DO UPDATE SET request_count=request_count+1,updated_at=excluded.updated_at`)
    .bind(koreanDate(now), now.toISOString(), koreanDate(now), limit).run();
  return (result.meta.changes ?? 0) > 0;
}
