import { Recommendation } from '../types';
import { buildNotification } from './notificationBuilder';
import { sendBatch } from './fcmClient';

export async function runRecommendationNotificationJob(env: any): Promise<void> {
  const db = env.DB;
  if (!db) {
    return;
  }
  const today = new Date().toISOString().slice(0, 10);
  const installations = await db
    .prepare(
      `SELECT installation_id AS installationId, fcm_token AS token
       FROM installations
       WHERE notification_enabled = 1`,
    )
    .all();

  const rows = installations.results ?? [];
  for (const row of rows) {
    const recommendations = await getRecommendationsForInstallation(db, row.installationId);
    const built = buildNotification(recommendations);
    await sendBatch(
      built.map((b) => ({
        token: row.token as string,
        title: b.title,
        body: b.body,
      })),
    );
    for (const b of built) {
      await db
        .prepare(
          `INSERT OR REPLACE INTO notification_history
           (installation_id, target_date, notification_key, sent_at, payload_hash)
           VALUES (?, ?, ?, ?, ?)`,
        )
        .bind(
          row.installationId,
          today,
          b.notification_key,
          new Date().toISOString(),
          String(b.title + b.body).slice(0, 80),
        )
        .run();
    }
  }
}

async function getRecommendationsForInstallation(_db: any, _installationId: string): Promise<Recommendation[]> {
  // In MVP, this is placeholder logic.
  return [];
}

