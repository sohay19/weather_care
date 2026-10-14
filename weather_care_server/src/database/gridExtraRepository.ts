export async function gridExtraSnapshotExists(
  db: D1Database, source: string, targetId: string, slot: string,
): Promise<boolean> {
  const row = await db.prepare(
    'SELECT 1 AS present FROM grid_extra_snapshots WHERE source=? AND target_id=? AND slot=?',
  ).bind(source, targetId, slot).first<{ present: number }>();
  return row !== null;
}

export async function getGridExtraSnapshot<T>(
  db: D1Database, source: string, targetId: string, slot: string,
): Promise<T | null> {
  const row = await db.prepare(`SELECT payload FROM grid_extra_snapshots
    WHERE source=? AND target_id=? AND slot=?`)
    .bind(source, targetId, slot).first<{ payload: string }>();
  return row ? JSON.parse(row.payload) as T : null;
}

export async function saveGridExtraSnapshot(
  db: D1Database, input: {
    source: string; targetId: string; slot: string; payload: unknown; collectedAt: Date;
  },
): Promise<void> {
  await db.prepare(`INSERT INTO grid_extra_snapshots
    (source,target_id,slot,payload,collected_at) VALUES (?,?,?,?,?)
    ON CONFLICT(source,target_id,slot) DO UPDATE SET
      payload=excluded.payload,collected_at=excluded.collected_at`)
    .bind(input.source, input.targetId, input.slot,
      JSON.stringify(input.payload), input.collectedAt.toISOString()).run();
}

export async function reserveGridExtraRequest(
  db: D1Database, provider: string, limit: number, now: Date,
): Promise<boolean> {
  const usageDate = new Date(now.getTime() + 9 * 3_600_000).toISOString().slice(0, 10);
  const result = await db.prepare(`INSERT INTO api_usage_daily
    (usage_date,provider,request_count,response_bytes,updated_at)
    SELECT ?,?,1,0,? WHERE
      COALESCE((SELECT request_count FROM api_usage_daily
        WHERE usage_date=? AND provider=?),0) < ?
    ON CONFLICT(usage_date,provider) DO UPDATE SET
      request_count=request_count+1,updated_at=excluded.updated_at`)
    .bind(usageDate, provider, now.toISOString(), usageDate, provider, limit).run();
  return (result.meta.changes ?? 0) > 0;
}
