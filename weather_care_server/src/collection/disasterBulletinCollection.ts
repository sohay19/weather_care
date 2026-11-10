import { collectedCacheKey, getCollectedCache, saveCollectedCache } from '../database/collectedWeatherRepository';
import { safeErrorName } from '../observability/providerErrorDiagnostics';
import { fetchKmaDisasterBulletin, type KmaDisasterBulletin } from '../providers/warnings/kmaDisasterBulletin';

export async function collectDisasterBulletin(db: D1Database, now = new Date()): Promise<void> {
  try {
    const key = collectedCacheKey.disasterBulletin;
    const previous = await getCollectedCache<KmaDisasterBulletin | null>(db, key);
    const bulletin = await fetchKmaDisasterBulletin(now, previous?.value ?? null);
    await saveCollectedCache(db, { key, type: key, value: bulletin, updatedAt: now });
    if (bulletin && bulletin.issuedAt !== previous?.value?.issuedAt) {
      console.log(JSON.stringify({
        event: 'kma_disaster_bulletin_collected', issuedAt: bulletin.issuedAt, regions: bulletin.regionCodes.length,
      }));
    }
  } catch (error) {
    console.warn(JSON.stringify({ event: 'kma_disaster_bulletin_collection_failed', error: safeErrorName(error) }));
  }
}
