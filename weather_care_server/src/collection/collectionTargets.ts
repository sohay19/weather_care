import type { ServerEnv } from '../types';
import type { CollectionTarget } from './collectionTypes';

export async function loadCollectionTargets(env: ServerEnv): Promise<CollectionTarget[]> {
  const targets = new Map<string, CollectionTarget>();
  for (const db of env.COLLECTION_USER_DATABASES ?? [env.DB]) {
    const rows = await db.prepare(`SELECT nx, ny, latitude, longitude FROM installations
      GROUP BY nx, ny, latitude, longitude`).all<{
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
