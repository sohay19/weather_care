import { installationExpirySql } from '../database/dataRetention';
import { regionName } from '../regions/regionCatalog';
import { lightningForGrid, readLightningFeed } from '../services/lightning';
import type { ServerEnv } from '../types';
import { sendBatch, type FcmPayload, type FcmSendResult } from './fcmClient';

interface LightningInstallation {
  installationId: string;
  token: string;
  nx: number;
  ny: number;
}

interface Dependencies {
  now?: () => Date;
  sender?: (env: ServerEnv, payloads: FcmPayload[]) => Promise<FcmSendResult[]>;
}

// 별도 낙뢰 수집 직후 실행한다. 일반 예보의 성공 여부에 의존하지 않는다.
export async function runLightningNotificationJob(env: ServerEnv, dependencies: Dependencies = {}): Promise<void> {
  const clock = dependencies.now ?? (() => new Date());
  const now = clock();
  await env.DB.prepare('DELETE FROM lightning_notification_claims WHERE expires_at<=?')
    .bind(now.toISOString()).run();
  const feed = await readLightningFeed(env.DB, now);
  if (feed.status !== 'AVAILABLE' || feed.events.length === 0) return;
  const eligibility = `i.fcm_token IS NOT NULL AND TRIM(i.fcm_token)<>''
    AND i.minimum_age_confirmed_at IS NOT NULL AND i.age_policy_version=1
    AND s.notification_enabled=1 AND s.lightning_enabled=1
    AND NOT EXISTS (SELECT 1 FROM installation_activity a WHERE a.installation_id=i.installation_id
      AND ${installationExpirySql}<=julianday(?))`;
  const installations = await env.DB.prepare(`SELECT i.installation_id AS installationId,
    i.fcm_token AS token,i.nx,i.ny FROM installations i JOIN notification_settings s
    ON s.installation_id=i.installation_id WHERE ${eligibility}`)
    .bind(now.toISOString()).all<LightningInstallation>();
  for (const installation of installations.results) {
    const summary = lightningForGrid(feed, installation.nx, installation.ny, clock());
    if (!summary.latestObservedAt || !summary.expiresAt || !summary.feedExpiresAt) continue;
    const notificationKey = `LIGHTNING_${installation.nx}_${installation.ny}_${summary.latestObservedAt}`;
    const expiresAt = new Date(Math.min(Date.parse(summary.expiresAt), Date.parse(summary.feedExpiresAt))).toISOString();
    const claimedAt = clock();
    if (Date.parse(expiresAt) <= claimedAt.getTime()) continue;
    // 원자적 임대: 겹친 작업은 같은 설치·관측을 동시에 전송하지 않는다.
    const claim = await env.DB.prepare(`INSERT INTO lightning_notification_claims
      (installation_id,notification_key,lease_until,expires_at)
      SELECT ?,?,?,? WHERE EXISTS (SELECT 1 FROM installations i JOIN notification_settings s
        ON s.installation_id=i.installation_id WHERE i.installation_id=? AND i.fcm_token=? AND ${eligibility})
      ON CONFLICT(installation_id,notification_key) DO UPDATE SET lease_until=excluded.lease_until
        WHERE sent_at IS NULL AND lease_until<=?`)
      .bind(installation.installationId, notificationKey,
        new Date(claimedAt.getTime() + 120_000).toISOString(), summary.expiresAt,
        installation.installationId, installation.token, claimedAt.toISOString(), claimedAt.toISOString()).run();
    if (!claim.meta.changes) continue;
    const region = regionName(installation.nx, installation.ny);
    const localTime = new Date(Date.parse(summary.latestObservedAt) + 9 * 3_600_000).toISOString().slice(11, 16);
    const payload: FcmPayload = {
      token: installation.token, notificationKey, notificationTarget: 'WEATHER_DETAILS',
      notificationTopic: 'LIGHTNING', expiresAt,
      title: `${region} 낙뢰 관측`,
      body: `${localTime} 선택 지역의 기상 격자에서 낙뢰가 관측됐어요. 안전한 건물이나 자동차 안으로 이동하세요.`,
    };
    try {
      // 전송 직전에 토큰·설정·위치와 자료 유효성을 다시 확인한다.
      const current = await env.DB.prepare(`SELECT 1 FROM installations i JOIN notification_settings s
        ON s.installation_id=i.installation_id WHERE i.installation_id=? AND i.fcm_token=?
        AND i.nx=? AND i.ny=? AND ${eligibility}`)
        .bind(installation.installationId, installation.token, installation.nx, installation.ny,
          clock().toISOString()).first();
      if (!current || clock().getTime() >= Date.parse(expiresAt)) {
        await releaseClaim(env.DB, installation.installationId, notificationKey);
        continue;
      }
      const results = await (dependencies.sender ?? defaultSender)(env, [payload]);
      const result = results[0];
      if (result?.success) {
        const sentAt = clock().toISOString();
        await env.DB.batch([
          env.DB.prepare(`UPDATE lightning_notification_claims SET sent_at=?
            WHERE installation_id=? AND notification_key=?`).bind(sentAt, installation.installationId, notificationKey),
          env.DB.prepare(`INSERT OR IGNORE INTO notification_history
            (installation_id,target_date,notification_key,sent_at,payload_hash)
            SELECT ?,?,?,?,? WHERE EXISTS (SELECT 1 FROM installations WHERE installation_id=?)`)
            .bind(installation.installationId, new Date(Date.parse(sentAt) + 9 * 3_600_000).toISOString().slice(0, 10),
              notificationKey, sentAt, payload.body.slice(0, 160), installation.installationId),
        ]);
      } else {
        await releaseClaim(env.DB, installation.installationId, notificationKey);
      }
      if (result?.unregistered) await env.DB.prepare(`UPDATE installations SET fcm_token=NULL
        WHERE installation_id=? AND fcm_token=?`).bind(installation.installationId, installation.token).run();
    } catch {
      await releaseClaim(env.DB, installation.installationId, notificationKey);
      console.error(JSON.stringify({ event: 'lightning_notification_failed' }));
    }
  }
}

async function releaseClaim(db: D1Database, id: string, key: string): Promise<void> {
  await db.prepare('DELETE FROM lightning_notification_claims WHERE installation_id=? AND notification_key=? AND sent_at IS NULL')
    .bind(id, key).run();
}

async function defaultSender(env: ServerEnv, payloads: FcmPayload[]): Promise<FcmSendResult[]> {
  return sendBatch({ projectId: env.FCM_PROJECT_ID, clientEmail: env.FCM_CLIENT_EMAIL,
    privateKey: env.FCM_PRIVATE_KEY }, payloads);
}
