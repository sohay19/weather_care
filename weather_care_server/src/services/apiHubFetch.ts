import { reserveApiHubBudget } from '../database/apiUsageRepository';
import { providerErrorDiagnostic } from '../observability/providerErrorDiagnostics';

// 응답을 읽기 전에 상한을 예약한다. 실제 수신량만 남기며 실패·중단은 예약을 유지한다.
// 호출별 예약이므로 T1H 준비 확인에서 중단된 나머지 요청을 사용량에 넣지 않는다.
export function apiHubBudgetedFetch(input: {
  db: D1Database; provider: string; now: Date; maxBytes: number;
  fetcher?: typeof fetch; retry?: boolean;
  sourceVersion?: string; clock?: () => Date;
}): typeof fetch {
  return async (url, init) => {
    const accountedAt = input.clock?.() ?? input.now;
    const cleanUrl = new URL(typeof url === 'string' ? url : url instanceof URL ? url.href : url.url);
    for (const key of ['authKey', 'serviceKey', 'ServiceKey']) cleanUrl.searchParams.delete(key);
    const fingerprint = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(
      `${input.sourceVersion ?? input.now.toISOString().slice(0, 13)}:${cleanUrl.href}`));
    const attemptKey = 'APIHUB_ATTEMPT_' + Array.from(new Uint8Array(fingerprint), (b) => b.toString(16).padStart(2, '0')).join('');
    const prior = await input.db.prepare('SELECT cache_key FROM weather_cache WHERE cache_key = ?').bind(attemptKey).first();
    const bootstrap = await input.db.prepare("SELECT updated_at FROM weather_cache WHERE cache_key = 'NATIONAL_BOOTSTRAP'")
      .first<{ updated_at: string }>();
    const initial = !bootstrap || accountedAt.getTime() - Date.parse(bootstrap.updated_at) < 86_400_000;
    const retry = input.retry || !!prior;
    const group = input.provider === 'GRID_OBSERVATION_HISTORY' || /DIAGNOSTIC|HISTORY/.test(input.provider)
      ? 'HISTORY' : /GRID_OBSERVATION/.test(input.provider) &&
        !['VEC','PTY','RN1'].includes(cleanUrl.searchParams.get('vars') ?? '') ? 'CORE'
      : input.provider === 'NATIONAL_SHORT_FORECAST' ? 'FORECAST' : 'OTHER';
    const provider = retry ? `APIHUB_RETRY_${group}` : input.provider;
    const retryLimit = initial ? 100_000_000 : 400_000_000;
    const share = (initial ? { CORE: 0.5, FORECAST: 0.3, OTHER: 0.15, HISTORY: 0.05 }
      : { CORE: 0.4, FORECAST: 0.3, OTHER: 0.15, HISTORY: 0.15 })[group];
    if (!await reserveApiHubBudget(input.db, provider, 1, input.maxBytes, accountedAt,
      retry ? { providerDailyByteLimit: retryLimit * share, retryDailyByteLimit: retryLimit } : undefined)) {
      const budget = await input.db.prepare(`SELECT COALESCE(SUM(response_bytes),0) AS bytes
        FROM api_usage_daily WHERE usage_date=? AND (provider='APIHUB_RETRY' OR provider GLOB 'APIHUB_RETRY_*')`)
        .bind(new Date(accountedAt.getTime() + 9 * 3_600_000).toISOString().slice(0,10)).first<{bytes:number}>();
      const nextDay = new Date(accountedAt.getTime() + 9 * 3_600_000);
      nextDay.setUTCHours(24,0,0,0);
      const resetAt = new Date(nextDay.getTime() - 9 * 3_600_000).getTime();
      const expandedAt = bootstrap ? Date.parse(bootstrap.updated_at) + 86_400_000 : resetAt;
      const nextRetryAt = initial && expandedAt > accountedAt.getTime() && expandedAt < resetAt
        ? expandedAt : resetAt;
      console.warn(JSON.stringify({ event:'apihub_budget_blocked', originalProvider:input.provider, provider,
        retry, retryBytes:budget?.bytes, retryLimit, nextRetryAt:new Date(nextRetryAt).toISOString() }));
      throw Object.assign(new Error('APIHUB_BUDGET_EXHAUSTED'), { nextRetryAt });
    }
    await input.db.prepare(`INSERT INTO weather_cache(cache_key,region_id,nx,ny,cache_type,payload,status,updated_at)
      VALUES(?,?,0,0,'NATIONAL_APIHUB_ATTEMPT','{}','AVAILABLE',?)
      ON CONFLICT(cache_key) DO UPDATE SET updated_at=excluded.updated_at`)
      .bind(attemptKey, attemptKey, accountedAt.toISOString()).run();
    const startedAt = performance.now();
    let phase = 'RESPONSE_HEADERS';
    let status: number | undefined;
    let headersElapsedMs: number | undefined;
    let bytes = 0;
    const rawMetric = cleanUrl.searchParams.get('obs') ?? cleanUrl.searchParams.get('vars');
    const metric = rawMetric && /^(TA|HM|WS|VS|T1H|REH|WSD|VEC|PTY|RN1|TMP|SKY|POP|PCP|SNO|TMN|TMX|ta_min|ta_max|rn_day|sd_day_max)$/.test(rawMetric) ? rawMetric : undefined;
    const sourceVersion = input.sourceVersion && /^(\d{8,14}(?::\d{8,14})?|\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?(?:Z|\+09:00))$/.test(input.sourceVersion)
      ? input.sourceVersion : undefined;
    try {
      const response = await (input.fetcher ?? globalThis.fetch)(url, init);
      status = response.status;
      headersElapsedMs = Math.round(performance.now() - startedAt);
      phase = 'RESPONSE_BODY';
      const reader = response.body?.getReader();
      const chunks: Uint8Array[] = [];
      if (reader) {
        try {
          while (true) {
            const part = await reader.read();
            if (part.done) break;
            bytes += part.value.byteLength;
            if (bytes > input.maxBytes) {
              await reader.cancel();
              await input.db.prepare(`UPDATE api_usage_daily SET response_bytes = response_bytes + ?
                WHERE usage_date = ? AND provider = ?`)
                .bind(bytes - input.maxBytes, new Date(accountedAt.getTime() + 9 * 3_600_000).toISOString().slice(0, 10), provider).run();
              throw new Error('APIHUB_RESPONSE_EXCEEDS_RESERVED_BYTES');
            }
            chunks.push(part.value);
          }
        } finally { reader.releaseLock(); }
      }
      phase = 'ACCOUNT_USAGE';
      await input.db.prepare(`UPDATE api_usage_daily
        SET response_bytes = MAX(0, response_bytes - ?)
        WHERE usage_date = ? AND provider = ?`)
        .bind(input.maxBytes - bytes,
          new Date(accountedAt.getTime() + 9 * 3_600_000).toISOString().slice(0, 10), provider).run();
      const body = new Uint8Array(bytes);
      let offset = 0;
      for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.byteLength; }
      console.log(JSON.stringify({ event: 'apihub_response_accounted', provider, originalProvider:input.provider,
        status: response.status, metric, sourceVersion, headersElapsedMs,
        responseBytes: bytes, elapsedMs: Math.round(performance.now() - startedAt) }));
      return new Response(response.status === 204 || response.status === 304 ? null : body,
        { status: response.status, statusText: response.statusText, headers: response.headers });
    } catch (error) {
      console.error(JSON.stringify({ event: 'apihub_request_failed', provider, originalProvider:input.provider, metric,
        sourceVersion, phase, httpStatus: status, headersElapsedMs,
        receivedBytes: bytes, reservedBytes: input.maxBytes,
        elapsedMs: Math.round(performance.now() - startedAt),
        signalAborted: init?.signal?.aborted ?? false, ...providerErrorDiagnostic(error) }));
      throw error;
    }
  };
}
