import Database from 'better-sqlite3';
import { createHash } from 'node:crypto';
import type { FcmPayload, FcmSendResult } from '../notification/fcmClient';
import { needsStoreUpdate, newerRelease, releaseKey, type StoreRelease } from './storeRelease';

export const UPDATE_PUSH_TITLE = '날씨챙겨 새 버전이 나왔어요';
export const UPDATE_PUSH_BODY = '최신버전 업데이트가 준비됐어요. 새로운 버전을 다운받아보세요.';

export function initializeStoreUpdateState(db: Database.Database): void {
  db.exec(`CREATE TABLE IF NOT EXISTS store_releases (
    platform TEXT PRIMARY KEY, release_json TEXT NOT NULL, notify INTEGER NOT NULL,
    checked_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS store_update_deliveries (
      platform TEXT NOT NULL, release_key TEXT NOT NULL, installation_id TEXT NOT NULL,
      token_hash TEXT NOT NULL, status TEXT NOT NULL, updated_at TEXT NOT NULL,
      PRIMARY KEY(platform, release_key, installation_id), UNIQUE(platform, release_key, token_hash));`);
}

interface Candidate { installation_id: string; fcm_token: string; app_version: string | null }
export function storeUpdateCandidates(db: Database.Database, release: StoreRelease): Candidate[] {
  const rows = db.prepare(`SELECT i.installation_id, i.fcm_token, i.app_version FROM installations i
    JOIN notification_settings s ON s.installation_id=i.installation_id
    WHERE LOWER(i.platform)=? AND i.fcm_token IS NOT NULL AND LENGTH(TRIM(i.fcm_token))>0
      AND s.notification_enabled=1 ORDER BY i.updated_at DESC, i.installation_id`).all(release.platform) as Candidate[];
  const byToken = new Map<string, Candidate>();
  for (const row of rows) if (!byToken.has(row.fcm_token)) byToken.set(row.fcm_token, row);
  return [...byToken.values()].filter((row) => needsStoreUpdate(row.app_version, release));
}

export async function notifyStoreRelease(options: {
  state: Database.Database; installations: Database.Database; release: StoreRelease;
  send: (payload: FcmPayload) => Promise<FcmSendResult>; now?: Date;
}): Promise<{ baseline: boolean; candidates: number; sent: number; failed: number; uncertain: number }> {
  const { state, installations, release, send } = options;
  const at = (options.now ?? new Date()).toISOString();
  const previous = state.prepare('SELECT release_json,notify FROM store_releases WHERE platform=?')
    .get(release.platform) as { release_json: string; notify: number } | undefined;
  const baseline = !previous;
  const previousRelease: StoreRelease | undefined = previous && JSON.parse(previous.release_json);
  const changed = previousRelease && newerRelease(release, previousRelease);
  if (previousRelease && releaseKey(release) !== releaseKey(previousRelease) && !changed) {
    return { baseline: false, candidates: 0, sent: 0, failed: 0, uncertain: 0 };
  }
  state.prepare(`INSERT INTO store_releases VALUES (?,?,?,?) ON CONFLICT(platform) DO UPDATE SET
    release_json=excluded.release_json, notify=excluded.notify, checked_at=excluded.checked_at`)
    .run(release.platform, JSON.stringify(release), changed ? 1 : previous?.notify ?? 0, at);
  // 최초 성공 조회는 현재 공개 버전을 기준으로만 저장한다. 기존 버전의 일괄 발송을 막는다.
  if (baseline || (!changed && !previous?.notify)) {
    return { baseline, candidates: 0, sent: 0, failed: 0, uncertain: 0 };
  }
  const candidates = storeUpdateCandidates(installations, release);
  const summary = { baseline, candidates: candidates.length, sent: 0, failed: 0, uncertain: 0 };
  const seenTokens = new Set<string>();
  for (const candidate of candidates) {
    // 오래된 소유권/토큰 변경 이력이 있어도 같은 토큰으로 중복 발송하지 않는다.
    if (seenTokens.has(candidate.fcm_token)) continue;
    seenTokens.add(candidate.fcm_token);
    const key = [release.platform, releaseKey(release), candidate.installation_id];
    const tokenHash = createHash('sha256').update(candidate.fcm_token).digest('hex');
    const claimed = state.transaction(() => {
      const inserted = state.prepare(`INSERT OR IGNORE INTO store_update_deliveries VALUES (?,?,?,?,'pending',?)`)
        .run(...key, tokenHash, at);
      if (inserted.changes) return inserted;
      return state.prepare(`UPDATE store_update_deliveries SET status='pending',updated_at=?
        WHERE platform=? AND release_key=? AND installation_id=? AND token_hash=? AND status='failed'`)
        .run(at, ...key, tokenHash);
    })();
    if (!claimed.changes) continue;
    // 발송 직전에 설치 버전·권한·토큰을 다시 확인한다.
    const current = installations.prepare(`SELECT i.app_version FROM installations i
      JOIN notification_settings s ON s.installation_id=i.installation_id
      WHERE i.installation_id=? AND i.fcm_token=? AND LOWER(i.platform)=? AND s.notification_enabled=1`)
      .get(candidate.installation_id, candidate.fcm_token, release.platform) as { app_version: string | null } | undefined;
    let status = 'skipped';
    if (current && needsStoreUpdate(current.app_version, release)) {
      try {
        const result = await send({ token: candidate.fcm_token, title: UPDATE_PUSH_TITLE, body: UPDATE_PUSH_BODY,
          notificationKey: `APP_UPDATE_${release.platform}_${releaseKey(release)}`,
          notificationTarget: 'STORE_UPDATE', notificationTopic: 'APP_UPDATE', storeUrl: release.url,
          expiresAt: new Date(Date.parse(at) + 24 * 60 * 60 * 1000).toISOString() });
        status = result.success ? 'sent' : result.unregistered ? 'invalid_token' : 'failed';
        if (result.success) summary.sent++; else summary.failed++;
      } catch {
        // 응답 유실/프로세스 중단은 접수 여부가 불명확하므로 자동 재전송하지 않는다.
        status = 'uncertain'; summary.uncertain++;
      }
    }
    state.prepare('UPDATE store_update_deliveries SET status=?,updated_at=? WHERE platform=? AND release_key=? AND installation_id=?')
      .run(status, at, ...key);
  }
  return summary;
}
