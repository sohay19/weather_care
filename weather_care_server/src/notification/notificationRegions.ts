import { z } from 'zod';
import { KMA_ADMINISTRATIVE_AREAS } from '../regions/kmaAdministrativeAreas';
import { displayAdministrativeName } from '../regions/nationwideLocation';
import { resolveSavedLocation } from '../regions/resolvedLocation';
import { weatherDatabase } from '../database/weatherDatabase';
import { kmaGridCoordinates } from '../regions/kmaGridCoordinates';
import type { ServerEnv } from '../types';

export const notificationRegionsSchema = z.object({
  regions: z.array(z.object({ key: z.string().min(1).max(200), enabled: z.boolean() }).strict()).max(50),
}).strict().refine(({ regions }) => new Set(regions.map(r => r.key)).size === regions.length);

export interface RegionTarget {
  regionKey?: string; scopeId?: string; regionName?: string;
  nx: number; ny: number; latitude: number | null; longitude: number | null;
  currentRainState?: number; roadIceLevel?: number; roadIceLinkId?: string | null;
  roadControlEventKey?: string | null; roadControlKind?: 'FULL' | 'PARTIAL' | null;
}

export function catalogNotificationRegion(key: string) {
  const [code, name, x, y, ...rest] = key.split('|');
  if (rest.length) return undefined;
  // 원본 기상청 카탈로그가 재사용한 코드도 동 이름과 격자로 구분한다.
  const areas = [...KMA_ADMINISTRATIVE_AREAS,
    ['2815555000', '인천광역시 영종구 용유동', 50, 124] as const,
    ['2815555000', '인천광역시 영종구 운서2동', 52, 125] as const];
  if (!/^[1-9]\d{0,2}$/.test(x ?? '') || !/^[1-9]\d{0,2}$/.test(y ?? '')) return undefined;
  const area = areas.find(r => r[0] === code && r[2] === Number(x) && r[3] === Number(y)
    && (r[1].split(' ').at(-1) === name || r[1].endsWith(' ' + name)));
  return area ? { nx: area[2], ny: area[3], name: displayAdministrativeName(area[1]) } : undefined;
}

export async function saveNotificationRegions(db: D1Database, id: string, hash: string,
  regions: Array<{ key: string; enabled: boolean }>): Promise<boolean> {
  const firstSubscription = !await db.prepare('SELECT 1 FROM notification_region_preferences WHERE installation_id=?').bind(id).first();
  const guard = 'EXISTS (SELECT 1 FROM installation_credentials WHERE installation_id=? AND secret_hash=?)';
  const statements = [db.prepare(`INSERT INTO notification_region_preferences SELECT ?,? WHERE ${guard}
    ON CONFLICT(installation_id) DO UPDATE SET updated_at=excluded.updated_at`)
    .bind(id, new Date().toISOString(), id, hash)];
  const keys = regions.map(r => r.key);
  statements.push(db.prepare(`DELETE FROM notification_regions WHERE installation_id=?
    AND region_key NOT IN (SELECT value FROM json_each(?)) AND ${guard}`).bind(id, JSON.stringify(keys), id, hash));
  for (const region of regions) {
    const area = region.key === 'GPS' || region.key === 'LEGACY' ? undefined : catalogNotificationRegion(region.key)!;
    statements.push(db.prepare(`INSERT INTO notification_regions
      (installation_id,region_key,scope_id,enabled,nx,ny,region_name,latitude,longitude)
      SELECT ?,?,?,?,COALESCE(?,CASE WHEN ?='LEGACY' OR i.location_mode='GPS' THEN i.nx END),
        COALESCE(?,CASE WHEN ?='LEGACY' OR i.location_mode='GPS' THEN i.ny END),?,
        CASE WHEN ?='GPS' AND i.location_mode='GPS' THEN i.latitude END,
        CASE WHEN ?='GPS' AND i.location_mode='GPS' THEN i.longitude END
      FROM (SELECT 1) LEFT JOIN installations i ON i.installation_id=? WHERE ${guard}
      ON CONFLICT(installation_id,region_key) DO UPDATE SET enabled=excluded.enabled`)
      .bind(id, region.key, crypto.randomUUID(), region.enabled ? 1 : 0,
        area?.nx ?? null, region.key, area?.ny ?? null, region.key, area?.name ?? null, region.key, region.key, id, id, hash));
  }
  // 업데이트 직전까지 같은 위치에서 받은 알림과 상태를 이어 받아 재발송을 막는다.
  if (firstSubscription && regions.filter(r => r.enabled).length === 1) {
    const match = `r.installation_id=i.installation_id AND r.enabled=1 AND r.nx=i.nx AND r.ny=i.ny`;
    statements.push(db.prepare(`INSERT OR IGNORE INTO notification_region_state
      (installation_id,scope_id,current_rain_state,road_ice_level,road_ice_link_id,road_control_event_key,road_control_kind)
      SELECT i.installation_id,r.scope_id,i.current_rain_state,i.road_ice_level,i.road_ice_link_id,i.road_control_event_key,i.road_control_kind
      FROM installations i JOIN notification_regions r ON ${match} WHERE i.installation_id=? AND ${guard}`).bind(id,id,hash));
    statements.push(db.prepare(`INSERT OR IGNORE INTO notification_region_warning_state
      SELECT w.installation_id,r.scope_id,w.warning_type,w.warning_name,w.level_code,w.level_name,w.region_name,w.effective_at,w.updated_at
      FROM installation_warning_state w JOIN installations i ON i.installation_id=w.installation_id
      JOIN notification_regions r ON ${match} WHERE i.installation_id=? AND ${guard}`).bind(id,id,hash));
    statements.push(db.prepare(`INSERT OR IGNORE INTO notification_history
      SELECT h.installation_id,h.target_date,h.notification_key || '@' || r.scope_id,h.sent_at,h.payload_hash
      FROM notification_history h JOIN installations i ON i.installation_id=h.installation_id
      JOIN notification_regions r ON ${match} WHERE i.installation_id=? AND instr(h.notification_key,'@')=0 AND ${guard}`).bind(id,id,hash));
  }
  for (const table of ['notification_region_state', 'notification_region_warning_state']) {
    statements.push(db.prepare(`DELETE FROM ${table} WHERE installation_id=? AND scope_id NOT IN
      (SELECT scope_id FROM notification_regions WHERE installation_id=?) AND ${guard}`).bind(id, id, id, hash));
  }
  const result = await db.batch(statements);
  return result[0].meta.changes > 0;
}

// 기존 설치에는 원래 행을 반환하며, 구독 등록 후에는 켜 둔 지역만 반환한다.
export async function expandNotificationRegions<T extends RegionTarget & { installationId: string }>(
  env: ServerEnv, rows: T[], now: Date): Promise<T[]> {
  if (!rows.length) return [];
  const preferences = await env.DB.prepare('SELECT installation_id AS id FROM notification_region_preferences').all<{id:string}>();
  const opted = new Set(preferences.results.map(p => p.id));
  const subscriptions = await env.DB.prepare(`SELECT r.installation_id AS installationId,r.region_key AS regionKey,
    r.scope_id AS scopeId,r.nx,r.ny,r.region_name AS regionName,r.latitude,r.longitude,
    COALESCE(s.current_rain_state,0) AS currentRainState,COALESCE(s.road_ice_level,0) AS roadIceLevel,
    s.road_ice_link_id AS roadIceLinkId,s.road_control_event_key AS roadControlEventKey,s.road_control_kind AS roadControlKind
    FROM notification_regions r LEFT JOIN notification_region_state s
      ON s.installation_id=r.installation_id AND s.scope_id=r.scope_id
    WHERE r.enabled=1 AND r.nx IS NOT NULL AND r.ny IS NOT NULL`).all<RegionTarget & {installationId:string}>();
  const grouped = new Map<string, Array<RegionTarget & {installationId:string}>>();
  for (const region of subscriptions.results) {
    const list = grouped.get(region.installationId) ?? [];
    list.push(region); grouped.set(region.installationId, list);
  }
  const targets: T[] = [];
  for (const row of rows) {
    const regions = opted.has(row.installationId) ? grouped.get(row.installationId) ?? [] : [row];
    for (const region of regions) {
      const target = { ...row, ...region };
      // 수동 구역도 강수·도로 알림 조회에 해당 격자의 기준 좌표를 사용한다.
      if (target.latitude === null || target.longitude === null) {
        const point = kmaGridCoordinates(target.nx, target.ny);
        if (target.scopeId && point) { target.latitude = point.latitude; target.longitude = point.longitude; }
      }
      if (!target.regionName) {
        try {
          const resolved = await resolveSavedLocation(weatherDatabase(env), { nx: target.nx, ny: target.ny,
            coordinates: region.latitude !== null && region.longitude !== null
              ? { latitude: region.latitude, longitude: region.longitude } : undefined }, now);
          target.regionName = resolved.regionName;
        } catch { /* 지역명을 추측해서 동을 배정하지 않는다. */ }
      }
      targets.push(target);
    }
  }
  return targets;
}

export function regionHistoryKey(key: string, scopeId?: string): string {
  return scopeId ? `${key}@${scopeId}` : key;
}

export async function regionStillEnabled(db: D1Database, id: string, target: RegionTarget): Promise<boolean> {
  if (!target.scopeId) return !(await db.prepare('SELECT 1 FROM notification_region_preferences WHERE installation_id=?').bind(id).first());
  return Boolean(await db.prepare(`SELECT 1 FROM notification_regions WHERE installation_id=?
    AND region_key=? AND scope_id=? AND enabled=1`).bind(id, target.regionKey, target.scopeId).first());
}

export function regionPushData(target: RegionTarget) {
  return target.scopeId ? { notificationRegionKey: target.regionKey, notificationRegionId: target.scopeId,
    notificationRegionName: target.regionName, notificationRegionNx: String(target.nx), notificationRegionNy: String(target.ny) } : {};
}

export function regionTitle(title: string, target: RegionTarget): string {
  return target.regionName ? `[${displayAdministrativeName(target.regionName)}] ${title}` : title;
}

export function regionStateStatement(db: D1Database, id: string, scope: string, fields: Record<string, string | number | null>) {
  const names = Object.keys(fields);
  return db.prepare(`INSERT INTO notification_region_state (installation_id,scope_id,${names.join(',')})
    SELECT ?,?,${names.map(() => '?').join(',')} WHERE EXISTS (SELECT 1 FROM notification_regions WHERE installation_id=? AND scope_id=?)
    ON CONFLICT(installation_id,scope_id) DO UPDATE SET ${names.map(n => `${n}=excluded.${n}`).join(',')}`)
    .bind(id, scope, ...Object.values(fields), id, scope);
}
