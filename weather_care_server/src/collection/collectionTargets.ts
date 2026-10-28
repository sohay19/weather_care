import type { ServerEnv } from '../types';
import type { CollectionTarget } from './collectionTypes';

export async function loadCollectionTargets(env: ServerEnv): Promise<CollectionTarget[]> {
  const targets = new Map<string, CollectionTarget>();
  for (const db of env.COLLECTION_USER_DATABASES ?? [env.DB]) {
    // 공용 수집기는 아직 구버전인 시험 사용자 DB도 함께 읽는다.
    const subscriptionsSupported = await db.prepare("SELECT 1 FROM sqlite_master WHERE type='table' AND name='notification_regions'").first();
    const rows = await db.prepare(`SELECT nx, ny, latitude, longitude FROM installations
      ${subscriptionsSupported ? `UNION SELECT r.nx,r.ny,r.latitude,r.longitude FROM notification_regions r
      JOIN installations i ON i.installation_id=r.installation_id
      JOIN notification_settings s ON s.installation_id=r.installation_id
      WHERE r.enabled=1 AND s.notification_enabled=1 AND r.nx IS NOT NULL AND r.ny IS NOT NULL` : ''}`).all<{
        nx: number; ny: number; latitude: number | null; longitude: number | null;
      }>();
    for (const row of rows.results) {
      const target = { nx: Number(row.nx), ny: Number(row.ny),
        latitude: row.latitude ?? undefined, longitude: row.longitude ?? undefined };
      targets.set(JSON.stringify(target), target);
    }
  }
  return [...targets.values()];
}
