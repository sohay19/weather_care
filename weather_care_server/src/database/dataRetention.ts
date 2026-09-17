// Must match the expression indexes in 0008_data_retention.sql.
export const installationExpirySql = "julianday(last_active_at, '+9 hours', '+1 year', 'floor', '-9 hours')";
export const historyExpirySql = "julianday(sent_at, '+9 hours', '+1 year', 'floor', '-9 hours')";

export async function recordInstallationActivity(
  db: D1Database, id: string, hash: string, now = new Date(),
): Promise<void> {
  // Only an authenticated app request can extend retention. Never call this
  // from notification jobs. The SQL guard prevents a late request resurrecting
  // an activity marker after a concurrent deletion.
  await db.prepare(`INSERT INTO installation_activity (installation_id, last_active_at)
    SELECT ?, ? WHERE EXISTS (SELECT 1 FROM installation_credentials
      WHERE installation_id = ? AND secret_hash = ?)
    ON CONFLICT(installation_id) DO UPDATE SET last_active_at = excluded.last_active_at
    WHERE julianday(excluded.last_active_at) > julianday(installation_activity.last_active_at)`)
    .bind(id, now.toISOString(), id, hash).run();
}

export async function runDataRetentionJob(db: D1Database, now = new Date()) {
  const timestamp = now.toISOString(); // Reject invalid time before any writes.
  // Candidate selection and the trigger's deletes share one transaction. An app
  // request either renews before it or sees its credential has been removed.
  const candidates = `SELECT installation_id FROM installation_activity
    WHERE ${installationExpirySql} <= julianday(?)
    ORDER BY ${installationExpirySql}, installation_id LIMIT 100`;
  const results = await db.batch<{ count: number }>([
    db.prepare(`SELECT COUNT(*) AS count FROM installations
      WHERE installation_id IN (${candidates})`).bind(timestamp),
    db.prepare(`SELECT COUNT(*) AS count FROM notification_history
      WHERE installation_id IN (${candidates})`).bind(timestamp),
    db.prepare(`DELETE FROM installation_activity
      WHERE installation_id IN (${candidates})`).bind(timestamp),
    db.prepare(`DELETE FROM notification_history WHERE rowid IN (
      SELECT rowid FROM notification_history WHERE ${historyExpirySql} <= julianday(?)
      ORDER BY ${historyExpirySql}, rowid LIMIT 1000)`).bind(timestamp),
    db.prepare(`DELETE FROM api_usage_daily
      WHERE usage_date < date(?, '-31 days')`).bind(timestamp),
    db.prepare(`DELETE FROM weather_cache
      WHERE cache_type IN ('COLLECTED_PRECIPITATION', 'COLLECTED_ROAD_ICE', 'COLLECTED_ROAD_CONTROL', 'COLLECTED_HOURLY_OBSERVATION')
        AND julianday(updated_at) < julianday(?, '-2 days')`).bind(timestamp),
  ]);
  return {
    installations: results[0].results[0].count,
    notificationHistory: results[1].results[0].count + results[3].meta.changes,
  };
}
