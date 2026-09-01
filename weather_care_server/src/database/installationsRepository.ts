import { Installation } from '../types';

export async function upsertInstallation(
  db: D1Database,
  payload: Installation,
): Promise<void> {
  const now = new Date().toISOString();
  await db
    .prepare(
      `INSERT INTO installations
       (installation_id, fcm_token, nx, ny, region_topic, location_mode, platform, app_version, timezone, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(installation_id) DO UPDATE SET
         fcm_token=excluded.fcm_token,
         nx=excluded.nx,
         ny=excluded.ny,
         region_topic=excluded.region_topic,
         location_mode=excluded.location_mode,
         platform=excluded.platform,
         app_version=excluded.app_version,
         timezone=excluded.timezone,
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
      now,
      now,
    )
    .run();
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
