import { unzlibSync, zlibSync } from 'fflate';
import {
  cacheRecordIsFresh,
  getCollectedCache,
  saveCollectedCache,
} from './collectedWeatherRepository';
import type { NationwidePrecipitationSnapshot } from '../providers/precipitation/precipitationObservationProvider';

export const NATIONWIDE_PRECIPITATION_CACHE_KEY = 'COLLECTED_NATIONWIDE_PRECIPITATION';
const CHUNK_TYPE = 'COLLECTED_NATIONWIDE_PRECIPITATION_CHUNK';
const CHUNK_LENGTH = 500_000;
const MAX_AGE_MS = 40 * 60 * 1000;

interface Manifest {
  version: string;
  observedAt: string;
  analysisChunks: number;
  radarChunks: number;
}

const loaded = new WeakMap<D1Database, {
  key: string;
  snapshot: NationwidePrecipitationSnapshot;
}>();

export async function saveNationwidePrecipitation(
  db: D1Database,
  snapshot: NationwidePrecipitationSnapshot,
  now: Date,
): Promise<void> {
  const version = String(Date.parse(snapshot.observedAt));
  if (version === 'NaN') throw new Error('Invalid nationwide precipitation time');
  const analysisChunks = await saveGrid(db, version, 'analysis', snapshot.analysis, now);
  const radarChunks = await saveGrid(db, version, 'radar', snapshot.radar, now);
  await saveCollectedCache<Manifest>(db, {
    key: NATIONWIDE_PRECIPITATION_CACHE_KEY,
    type: NATIONWIDE_PRECIPITATION_CACHE_KEY,
    value: { version, observedAt: snapshot.observedAt, analysisChunks, radarChunks },
    updatedAt: now,
  });
  loaded.set(db, { key: `${version}:${now.toISOString()}`, snapshot });
  await db.prepare(
    `DELETE FROM weather_cache
     WHERE cache_type = ? AND cache_key NOT LIKE ?`,
  ).bind(CHUNK_TYPE, `${CHUNK_TYPE}_${version}_%`).run();
}

export async function getNationwidePrecipitation(
  db: D1Database | undefined,
  now = new Date(),
): Promise<NationwidePrecipitationSnapshot | null> {
  if (!db) return null;
  const manifest = await getCollectedCache<Manifest>(db, NATIONWIDE_PRECIPITATION_CACHE_KEY);
  if (manifest?.status !== 'AVAILABLE' ||
      !cacheRecordIsFresh(manifest, MAX_AGE_MS, now)) return null;
  const key = `${manifest.value.version}:${manifest.updatedAt}`;
  const cached = loaded.get(db);
  if (cached?.key === key) return cached.snapshot;
  const [analysis, radar] = await Promise.all([
    loadGrid(db, manifest.value.version, 'analysis', manifest.value.analysisChunks),
    loadGrid(db, manifest.value.version, 'radar', manifest.value.radarChunks),
  ]);
  if (!analysis || !radar) return null;
  const snapshot = { observedAt: manifest.value.observedAt, analysis, radar };
  loaded.set(db, { key, snapshot });
  return snapshot;
}

async function saveGrid(
  db: D1Database,
  version: string,
  kind: 'analysis' | 'radar',
  grid: ArrayBuffer,
  now: Date,
): Promise<number> {
  const encoded = bytesToBase64(zlibSync(new Uint8Array(grid)));
  const count = Math.ceil(encoded.length / CHUNK_LENGTH);
  for (let index = 0; index < count; index += 1) {
    await saveCollectedCache(db, {
      key: chunkKey(version, kind, index),
      type: CHUNK_TYPE,
      value: encoded.slice(index * CHUNK_LENGTH, (index + 1) * CHUNK_LENGTH),
      updatedAt: now,
    });
  }
  return count;
}

async function loadGrid(
  db: D1Database,
  version: string,
  kind: 'analysis' | 'radar',
  count: number,
): Promise<ArrayBuffer | null> {
  if (!Number.isInteger(count) || count < 1 || count > 100) return null;
  const records = await Promise.all(Array.from({ length: count }, (_, index) =>
    getCollectedCache<string>(db, chunkKey(version, kind, index))));
  if (records.some((record) => record?.status !== 'AVAILABLE' ||
      typeof record.value !== 'string')) return null;
  try {
    const bytes = unzlibSync(base64ToBytes(records.map((record) => record!.value).join('')));
    return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
  } catch {
    return null;
  }
}

function chunkKey(version: string, kind: 'analysis' | 'radar', index: number): string {
  return `${CHUNK_TYPE}_${version}_${kind}_${index}`;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let index = 0; index < bytes.length; index += 8192) {
    binary += String.fromCharCode(...bytes.subarray(index, index + 8192));
  }
  return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}
