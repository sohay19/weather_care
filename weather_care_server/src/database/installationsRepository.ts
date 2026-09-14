import { Installation } from '../types';

export async function upsertInstallation(
  db: D1Database,
  payload: Installation,
  ownerHash?: string,
): Promise<boolean> {
  const now = new Date().toISOString();
  const result = await db
    .prepare(
      `INSERT INTO installations
       (installation_id, fcm_token, nx, ny, region_topic, location_mode, platform, app_version, timezone, latitude, longitude,
        minimum_age_confirmed_at, age_policy_version, created_at, updated_at)
       SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
       ${ownerHash === undefined ? 'WHERE 1' : `WHERE EXISTS (SELECT 1 FROM installation_credentials
         WHERE installation_id = ? AND secret_hash = ?)`}
       ON CONFLICT(installation_id) DO UPDATE SET
         fcm_token=excluded.fcm_token,
         nx=excluded.nx,
         ny=excluded.ny,
         region_topic=excluded.region_topic,
         location_mode=excluded.location_mode,
         platform=excluded.platform,
         app_version=excluded.app_version,
         timezone=excluded.timezone,
         latitude=excluded.latitude,
         longitude=excluded.longitude,
         minimum_age_confirmed_at=excluded.minimum_age_confirmed_at,
         age_policy_version=excluded.age_policy_version,
         updated_at=excluded.updated_at`,
    )
    .bind(
      payload.installationId,
      payload.fcmToken ?? null,
      payload.nx,
      payload.ny,
      payload.regionTopic,
      payload.locationMode,
      payload.platform ?? null,
      payload.appVersion ?? null,
      payload.timezone,
      payload.latitude ?? null,
      payload.longitude ?? null,
      payload.minimumAgeConfirmed ? now : null,
      payload.agePolicyVersion,
      now,
      now,
      ...(ownerHash === undefined ? [] : [payload.installationId, ownerHash]),
    )
    .run();
  return result.meta.changes > 0;
}

export async function upsertRegionSubscription(
  db: D1Database,
  topic: string,
): Promise<void> {
  const pieces = topic.split('_');
  const nx = parseInt(pieces[1] ?? '60', 10);
  const ny = parseInt(pieces[2] ?? '121', 10);
  const exists = await db.prepare('SELECT topic FROM active_regions WHERE topic = ?').bind(topic).first();
  if (!exists) {
    await db
      .prepare(
        `INSERT INTO active_regions
         (region_id, topic, nx, ny, subscriber_count, updated_at)
         VALUES (?, ?, ?, ?, 1, ?)`,
      )
      .bind(topic, topic, nx, ny, new Date().toISOString())
      .run();
  } else {
    await db
      .prepare(`UPDATE active_regions SET subscriber_count = subscriber_count + 1, updated_at = ? WHERE topic = ?`)
      .bind(new Date().toISOString(), topic)
      .run();
  }
}
