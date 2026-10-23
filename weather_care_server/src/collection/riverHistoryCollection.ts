import { getGridExtraSnapshot } from '../database/gridExtraRepository';
import { collectGridRiverFlow, collectGridRiverHistory } from './gridExtraCollection';

/** 전국 최신 자료는 매시간, 지점별 당일 전체 이력은 하루 한 번 보완한다. */
export async function collectDailyRiverHistory(input: {
  db: D1Database; key: string; now: Date; fetcher?: typeof fetch;
  requestIntervalMs?: number;
}): Promise<{ targets: number; succeeded: number; failed: number; budgetExhausted: boolean }> {
  await collectGridRiverFlow(input);
  const slot = `${input.now.toISOString().slice(0, 13)}:00:00.000Z`;
  const latest = await getGridExtraSnapshot<{ stations: Array<{ stationCode: string }> }>(
    input.db, 'HRFCO_RIVER_FLOW', 'ALL', slot);
  if (!latest) throw new Error('GRID_EXTRA_LATEST_RIVER_DATA_MISSING');
  const codes = [...new Set(latest.stations.map(row => row.stationCode))].sort();
  const date = new Date(input.now.getTime() + 9 * 3_600_000).toISOString().slice(0, 10);
  let succeeded = 0; let failed = 0; let budgetExhausted = false;
  for (const stationCode of codes) {
    const saved = await input.db.prepare(`SELECT 1 AS present FROM grid_extra_snapshots
      WHERE source='HRFCO_RIVER_FLOW' AND target_id=?
        AND date(collected_at,'+9 hours')=? LIMIT 1`).bind(stationCode, date).first();
    if (saved) { succeeded += 1; continue; }
    const usage = await input.db.prepare(`SELECT request_count AS count FROM api_usage_daily
      WHERE usage_date=? AND provider='HRFCO_RIVER_HISTORY'`).bind(date).first<{ count: number }>();
    if ((usage?.count ?? 0) >= 1_200) { budgetExhausted = true; break; }
    if (input.requestIntervalMs) await new Promise(resolve => setTimeout(resolve, input.requestIntervalMs));
    if (await collectGridRiverHistory({ ...input, stationCode })) succeeded += 1;
    else failed += 1;
    if (failed >= 10) break;
  }
  return { targets: codes.length, succeeded, failed, budgetExhausted };
}
