import { KmaNationwideForecastProvider, nationwideForecastPlan, type NationalForecastRequest } from '../providers/weather/kmaNationwideForecastProvider';
import { saveNationwideForecastField } from '../database/nationwideForecastRepository';
import { apiHubBudgetedFetch } from './apiHubFetch';
import { mapWithConcurrency } from '../utils/concurrencyLimiter';
import { providerErrorDiagnostic } from '../observability/providerErrorDiagnostics';

export async function collectNationwideForecast(db: D1Database, key: string, now: Date): Promise<void> {
  if (!key.trim()) throw new Error('KMA APIHub key is not configured');
  if (await db.prepare("SELECT cache_key FROM weather_cache WHERE cache_key='NATIONAL_FORECAST_AUTHORIZATION_BLOCK'").first()) return;
  const plan = nationwideForecastPlan(now);
  await db.prepare(`INSERT OR IGNORE INTO weather_cache(cache_key,region_id,nx,ny,cache_type,payload,status,updated_at)
    VALUES('NATIONAL_BOOTSTRAP','NATIONAL_BOOTSTRAP',0,0,'NATIONAL_BOOTSTRAP','{}','AVAILABLE',?)`)
    .bind(now.toISOString()).run();
  const existing = await db.prepare('SELECT issue_time AS issue,valid_time AS valid,variable FROM nationwide_forecast_fields').all<NationalForecastRequest>();
  const present = new Set(existing.results.map((r) => `${r.issue}:${r.valid}:${r.variable}`));
  const missing = plan.filter((r) => !present.has(`${r.issue}:${r.valid}:${r.variable}`))
    .sort((a,b) => b.issue.localeCompare(a.issue) || a.valid.localeCompare(b.valid));
  let stopped = false;
  await mapWithConcurrency(missing, 4, async (request) => {
    if (stopped) return;
    const lease = `NATIONAL_FORECAST_${request.issue}_${request.valid}_${request.variable}`;
    const owner = crypto.randomUUID();
    const acquired = await db.prepare(`INSERT INTO weather_cache(cache_key,region_id,nx,ny,cache_type,payload,status,updated_at)
      VALUES(?,?,0,0,'NATIONAL_SOURCE_LEASE',?,'AVAILABLE',?) ON CONFLICT(cache_key) DO UPDATE SET
      payload=excluded.payload,updated_at=excluded.updated_at WHERE weather_cache.updated_at <= ?`)
      .bind(lease, lease, owner, now.toISOString(), new Date(now.getTime() - 5 * 60_000).toISOString()).run();
    if (!acquired.meta.changes) return;
    try {
      const stored = await db.prepare('SELECT issue_time FROM nationwide_forecast_fields WHERE issue_time=? AND valid_time=? AND variable=?')
        .bind(request.issue, request.valid, request.variable).first();
      if (stored) {
        await db.prepare('DELETE FROM weather_cache WHERE cache_key = ? AND payload = ?').bind(lease, owner).run();
        return;
      }
      const provider = new KmaNationwideForecastProvider(key,
        apiHubBudgetedFetch({ clock: () => new Date(), db, provider: 'NATIONAL_SHORT_FORECAST', now, maxBytes: 1_000_000,
          sourceVersion: `${request.issue}:${request.valid}` }));
      const grid = await provider.getField(request);
      await saveNationwideForecastField(db, request, grid, now);
      await db.prepare('DELETE FROM weather_cache WHERE cache_key = ? AND payload = ?').bind(lease, owner).run();
    } catch (error) {
      const diagnostic = providerErrorDiagnostic(error);
      if (diagnostic.failureReason === 'AUTHORIZATION_FAILED') await db.prepare(`INSERT OR IGNORE INTO weather_cache
        (cache_key,region_id,nx,ny,cache_type,payload,status,updated_at)
        VALUES('NATIONAL_FORECAST_AUTHORIZATION_BLOCK','NATIONAL_FORECAST_AUTHORIZATION_BLOCK',0,0,'PROVIDER_AUTHORIZATION_BLOCK','{}','AVAILABLE',?)`)
        .bind(now.toISOString()).run();
      const nextRetryAt = (error as {nextRetryAt?:number})?.nextRetryAt;
      if (Number.isFinite(nextRetryAt)) await db.prepare('UPDATE weather_cache SET updated_at=? WHERE cache_key=? AND payload=?')
        .bind(new Date(nextRetryAt! - 5*60_000).toISOString(),lease,owner).run();
      if (diagnostic.failureReason === 'AUTHORIZATION_FAILED' || diagnostic.failureReason === 'QUOTA_EXCEEDED' || diagnostic.failureReason === 'RATE_LIMITED' ||
          error instanceof Error && error.message === 'APIHUB_BUDGET_EXHAUSTED') stopped = true;
      console.error(JSON.stringify({ event: 'national_forecast_field_failed',
      issue: request.issue, valid: request.valid, variable: request.variable, ...diagnostic })); }
  });
  const oldest = new Date(now.getTime() + 9 * 3_600_000 - 2 * 86_400_000).toISOString().replace(/[-:T]/g, '').slice(0, 10);
  await db.prepare('DELETE FROM nationwide_forecast_fields WHERE valid_time < ?')
    .bind(oldest).run();
  console.log(JSON.stringify({ event: 'national_forecast_collection_completed', plannedFields: plan.length, missingFields: missing.length, stopped }));
}
