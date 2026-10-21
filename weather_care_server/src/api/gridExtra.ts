import { Hono } from 'hono';
import type { ServerEnv } from '../types';
import { kmaGridFromCoordinates } from '../regions/kmaGridFromCoordinates';
import { kmaGridCoordinates } from '../regions/kmaGridCoordinates';
import { coordinatesFromQuery, regionFromQuery } from '../utils';
import { KHOA_BUOY_STATIONS, KHOA_TIDE_STATIONS } from '../collection/khoaStationCatalog';
import { lightningForGrid, lightningPositionMatchesGrid, readLightningFeed } from '../services/lightning';

type Row = Record<string, unknown>;
type Snapshot = { source: string; target_id: string; slot: string; payload: string };

const groups = [
  { source: 'KMA_LIGHTNING', title: '낙뢰', scope: 'grid', period: 'hourly' },
  { source: 'KHOA_TIDE_OBS', title: '관측 조위', scope: 'station', period: 'hourly' },
  { source: 'KHOA_TIDE_HOURLY', title: '예측 조위', scope: 'station', period: 'hourly' },
  { source: 'KHOA_TIDE_EXTREME', title: '만조·간조', scope: 'station', period: 'daily' },
  { source: 'KHOA_BUOY_OBS', title: '해양관측부이', scope: 'station', period: 'hourly' },
  { source: 'KHOA_RIP_CURRENT', title: '이안류 위험', scope: 'beach', period: 'hourly' },
  { source: 'KHOA_ROMS', title: '해역 예측', scope: 'area', period: 'hourly' },
  { source: 'KWATER_DAM', title: '댐·보 운영', scope: 'dam', period: 'hourly' },
  { source: 'KWATER_RIVER_LEVEL', title: 'K-water 하천 수위', scope: 'station', period: 'hourly' },
  { source: 'HRFCO_RIVER_FLOW', title: '하천 수위·유량', scope: 'station', period: 'hourly' },
  { source: 'NIFS_JELLYFISH_DETAIL', title: '해파리 보고서', scope: 'report', period: 'daily' },
] as const;

function record(value: unknown): Row {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Row : {};
}

function rows(value: unknown): Row[] {
  return Array.isArray(value) ? value.map(record) : [];
}

function payload(snapshot: Snapshot): unknown {
  try { return JSON.parse(snapshot.payload) as unknown; } catch { return null; }
}

function nameFor(snapshot: Snapshot): string {
  const data = payload(snapshot);
  const first = rows(data)[0] ?? record(data);
  return String(first.name ?? first.obsvtrNm ?? first.damnm ?? snapshot.target_id);
}

function pointFor(row: Row): { latitude: number; longitude: number } | undefined {
  if (row.latitude == null || row.longitude == null) return;
  const latitude = Number(row.latitude);
  const longitude = Number(row.longitude);
  if (Number.isFinite(latitude) && Number.isFinite(longitude) &&
      Math.abs(latitude) <= 90 && Math.abs(longitude) <= 180) return { latitude, longitude };
}

function distanceKm(a: { latitude: number; longitude: number },
  b: { latitude: number; longitude: number }): number {
  const r = Math.PI / 180;
  const h = Math.sin((a.latitude - b.latitude) * r / 2) ** 2 +
    Math.cos(a.latitude * r) * Math.cos(b.latitude * r) *
    Math.sin((a.longitude - b.longitude) * r / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(Math.min(1, h)));
}

function dateFor(row: Row, slot: string): string {
  const value = String(row.observedAt ?? row.forecastAt ?? row.inpt_date ?? slot);
  if (/^\d{12}$/.test(value)) return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}T${value.slice(8, 10)}:${value.slice(10)}:00+09:00`;
  if (/^\d{8}$/.test(value)) return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`;
  return value;
}

function summary(row: Row, source: string): Row {
  const fields: Record<string, string[]> = {
    KHOA_TIDE_OBS: ['tideCm', 'waterTempC', 'currentSpeedMs', 'currentDirectionDeg'],
    KHOA_TIDE_HOURLY: ['tideCm'],
    KHOA_TIDE_EXTREME: ['extremeType', 'tideCm'],
    KHOA_BUOY_OBS: ['waterTempC', 'currentSpeedCmPerSec', 'currentDirectionDeg'],
    KHOA_RIP_CURRENT: ['riskIndex', 'riskMessage'],
    KHOA_ROMS: ['waterTempC', 'currentSpeed', 'currentDirectionDeg', 'latitude', 'longitude'],
    KWATER_DAM: ['levelM', 'inflowM3PerSec', 'dischargeM3PerSec'],
    KWATER_RIVER_LEVEL: ['levelM', 'rainfallMm'],
    HRFCO_RIVER_FLOW: ['levelM', 'flowM3PerSec'],
  };
  if (source === 'NIFS_JELLYFISH_DETAIL') {
    const result: Row = {};
    for (const [key, value] of Object.entries(row)) {
      if (typeof value === 'string' || typeof value === 'number') {
        const plain = String(value).replace(/<[^>]*>/g, ' ').trim();
        if (plain && Object.keys(result).length < 8) result[key] = plain.slice(0, 2000);
      }
    }
    return result;
  }
  return Object.fromEntries((fields[source] ?? []).filter((key) => row[key] !== null && row[key] !== undefined)
    .map((key) => [key, row[key]]));
}

function relevantRows(snapshot: Snapshot, targetId: string): Row[] {
  const data = payload(snapshot);
  if (snapshot.source === 'HRFCO_RIVER_FLOW') return rows(record(data).stations)
    .filter((row) => String(row.stationCode) === targetId);
  if (snapshot.source === 'NIFS_JELLYFISH_DETAIL') {
    const root = record(data);
    const body = record(root.body ?? root.Body ?? record(root.response).body);
    const items = rows(body.item ?? root.Item ?? root.item);
    return items.length ? items : [root];
  }
  return rows(data);
}

function lightningRecords(snapshots: Snapshot[], nx: number, ny: number) {
  const hours = new Map<string, number>();
  for (const snapshot of snapshots) {
    for (const event of rows(record(payload(snapshot)).events)) {
      const latitude = Number(event.latitude);
      const longitude = Number(event.longitude);
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) continue;
      const grid = kmaGridFromCoordinates(latitude, longitude);
      if (grid.nx !== nx || grid.ny !== ny) continue;
      const time = dateFor(event, snapshot.slot).slice(0, 13) + ':00:00';
      hours.set(time, (hours.get(time) ?? 0) + 1);
    }
  }
  return [...hours].sort(([a], [b]) => b.localeCompare(a))
    .map(([time, count]) => ({ time, values: { count } }));
}

const app = new Hono<{ Bindings: ServerEnv }>();

app.get('/lightning', async (c) => {
  const grid = requestedGrid(c.req.query('nx'), c.req.query('ny'));
  if (!grid) return c.json({ error: 'INVALID_GRID' }, 400);
  const latitude = c.req.query('latitude');
  const longitude = c.req.query('longitude');
  const position = coordinatesFromQuery(latitude, longitude);
  if ((latitude !== undefined || longitude !== undefined) &&
      (!position || !lightningPositionMatchesGrid(position, grid.nx, grid.ny)))
    return c.json({ error: 'INVALID_COORDINATES' }, 400);
  c.header('Cache-Control', 'no-store');
  const now = new Date();
  try {
    return c.json(lightningForGrid(await readLightningFeed(c.env.DB, now,
      { includeTestSamples: c.env.TEST_DATA_ENABLED === true }), grid.nx, grid.ny, now, position));
  } catch {
    return c.json({ status: 'FAILED', nx: grid.nx, ny: grid.ny, count: 0 }, 503);
  }
});

function requestedGrid(nx: string | undefined, ny: string | undefined) {
  const grid = regionFromQuery(nx ?? null, ny ?? null);
  return Number.isInteger(grid.nx) && Number.isInteger(grid.ny) &&
    grid.nx >= 1 && grid.nx <= 149 && grid.ny >= 1 && grid.ny <= 253
    ? grid : null;
}

app.get('/catalog', async (c) => {
  const query = c.req.query();
  const grid = requestedGrid(query.nx, query.ny);
  if (!grid) return c.json({ error: 'INVALID_GRID' }, 400);
  const snapshots = await c.env.DB.prepare(`SELECT s.source,s.target_id,s.slot,s.payload
    FROM grid_extra_snapshots s JOIN (
      SELECT source,target_id,MAX(slot) AS slot FROM grid_extra_snapshots
      GROUP BY source,target_id
    ) latest ON latest.source=s.source AND latest.target_id=s.target_id AND latest.slot=s.slot`).all<Snapshot>();
  const codeSnapshot = snapshots.results.find((row) => row.source === 'KWATER_DAM_CODES');
  const damNames = new Map(rows(codeSnapshot ? payload(codeSnapshot) : null)
    .filter((row) => row.damcode != null)
    .map((row) => [String(row.damcode), String(row.damnm ?? row.damcode)]));
  const latestFlow = snapshots.results.find((row) => row.source === 'HRFCO_RIVER_FLOW');
  const flowTargets = rows(record(latestFlow ? payload(latestFlow) : null).stations)
    .map((row) => ({ id: String(row.stationCode), name: String(row.stationCode) }));
  const jellyList = snapshots.results.find((row) => row.source === 'NIFS_JELLYFISH');
  const jellyNames = new Map(rows(record(jellyList ? payload(jellyList) : null).items)
    .filter((row) => row.board_idx != null)
    .map((row) => [String(row.board_idx),
      String(row.title ?? row.subject ?? row.board_title ?? row.board_idx)]));
  const suppliedPosition = pointFor(query);
  const suppliedGrid = suppliedPosition && kmaGridFromCoordinates(
    suppliedPosition.latitude, suppliedPosition.longitude);
  const position = suppliedGrid?.nx === grid.nx && suppliedGrid.ny === grid.ny
    ? suppliedPosition! : kmaGridCoordinates(grid.nx, grid.ny)!;
  const namedStations = snapshots.results
    .filter((s) => ['KHOA_BUOY_OBS', 'KHOA_TIDE_OBS'].includes(s.source))
    .flatMap((s) => {
      const point = rows(payload(s)).map(pointFor).find(Boolean);
      const name = nameFor(s);
      return point && name !== s.target_id ? [{ ...point, name, id: s.target_id }] : [];
    });
  const marineTarget = (snapshot: Snapshot) => {
    const data = rows(payload(snapshot));
    const points = data.map(pointFor).filter((p) => p !== undefined);
    const buoy = [...KHOA_BUOY_STATIONS, ...KHOA_TIDE_STATIONS]
      .find(([code]) => code === snapshot.target_id);
    const point = points.sort((a, b) => distanceKm(a, position) - distanceKm(b, position))[0] ??
      (buoy ? { latitude: buoy[1], longitude: buoy[2] } : undefined);
    let name = nameFor(snapshot);
    if (snapshot.source === 'KHOA_ROMS' && point) {
      const linked = namedStations.find((s) => snapshot.target_id === `BUOY_${s.id}`);
      const nearest = linked ?? [...namedStations].sort((a, b) =>
        distanceKm(a, point) - distanceKm(b, point))[0];
      name = nearest && distanceKm(nearest, point) <= 30
        ? `${nearest.name} 인근 해역`
        : `해양 예측 지점 (북위 ${point.latitude.toFixed(2)}°, 동경 ${point.longitude.toFixed(2)}°)`;
    }
    return { id: snapshot.target_id, name, hasData: data.length > 0,
      ...(point ? { ...point, distanceKm: distanceKm(position, point) } : {}) };
  };
  return c.json({ grid: { nx: grid.nx, ny: grid.ny }, groups: groups.map((group) => ({
    ...group,
    targets: group.scope === 'grid' ? [{ id: `${grid.nx}_${grid.ny}`, name: `현재 격자 ${grid.nx}, ${grid.ny}` }]
      : group.source === 'HRFCO_RIVER_FLOW' ? flowTargets
      : [...(group.source === 'KHOA_ROMS' && snapshots.results.some((row) => row.source === group.source)
        ? [{ id: 'GRID', name: `현재 해양 격자 ${grid.nx}, ${grid.ny}` }] : []),
      ...snapshots.results.filter((row) => row.source === group.source)
        .map((row) => ['KHOA_ROMS', 'KHOA_BUOY_OBS', 'KHOA_TIDE_OBS', 'KHOA_TIDE_HOURLY'].includes(group.source)
          ? marineTarget(row) : ({ id: row.target_id,
          name: group.source === 'KWATER_DAM' ? damNames.get(row.target_id) ?? row.target_id
            : group.source === 'NIFS_JELLYFISH_DETAIL'
              ? jellyNames.get(row.target_id) ?? row.target_id : nameFor(row) }))
        .sort((a, b) => a.name.localeCompare(b.name, 'ko'))],
  })) });
});

app.get('/records', async (c) => {
  const query = c.req.query();
  const group = groups.find((item) => item.source === query.source);
  if (!group) return c.json({ error: 'INVALID_SOURCE' }, 400);
  const grid = requestedGrid(query.nx, query.ny);
  if (!grid) return c.json({ error: 'INVALID_GRID' }, 400);
  const requestedTarget = group.scope === 'grid' ? `${grid.nx}_${grid.ny}` : query.targetId;
  if (!requestedTarget || requestedTarget.length > 80 || !/^[\w:.-]+$/.test(requestedTarget))
    return c.json({ error: 'INVALID_TARGET' }, 400);
  const romsGrid = group.source === 'KHOA_ROMS' && requestedTarget === 'GRID';
  const targetId = group.scope === 'grid' || group.source === 'HRFCO_RIVER_FLOW'
    ? 'ALL' : requestedTarget;
  const snapshots = romsGrid
    ? await c.env.DB.prepare(`SELECT source,target_id,slot,payload FROM grid_extra_snapshots
      WHERE source=? ORDER BY slot DESC LIMIT 96`).bind(group.source).all<Snapshot>()
    : await c.env.DB.prepare(`SELECT source,target_id,slot,payload
      FROM grid_extra_snapshots WHERE source=? AND target_id=?
      ORDER BY slot DESC LIMIT ?`).bind(group.source, targetId,
      group.period === 'daily' ? 8 : 96).all<Snapshot>();
  if (group.source === 'KMA_LIGHTNING') return c.json({ source: group.source, targetId: `${grid.nx}_${grid.ny}`,
    period: group.period, records: lightningRecords(snapshots.results, grid.nx, grid.ny) });
  const seen = new Set<string>();
  const center = kmaGridCoordinates(grid.nx, grid.ny);
  const records = snapshots.results.flatMap((snapshot) => relevantRows(snapshot, requestedTarget)
    .filter((row) => {
      if (!romsGrid) return true;
      const latitude = Number(row.latitude);
      const longitude = Number(row.longitude);
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return false;
      const point = kmaGridFromCoordinates(latitude, longitude);
      return point.nx === grid.nx && point.ny === grid.ny;
    })
    .map((row) => ({ time: dateFor(row, snapshot.slot), values: summary(row, group.source),
      distance: center ? (Number(row.latitude) - center.latitude) ** 2 +
        (Number(row.longitude) - center.longitude) ** 2 : 0 })))
    .sort((a, b) => b.time.localeCompare(a.time) || a.distance - b.distance)
    .filter((item) => {
      const key = romsGrid ? item.time : `${item.time}:${JSON.stringify(item.values)}`;
      if (seen.has(key) || Object.keys(item.values).length === 0) return false;
      seen.add(key);
      return true;
    }).slice(0, 120).map(({ time, values }) => ({ time, values }));
  return c.json({ source: group.source, targetId: requestedTarget, period: group.period, records });
});

export default app;
