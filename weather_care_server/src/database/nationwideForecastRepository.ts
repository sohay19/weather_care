import { gzipSync, gunzipSync } from 'fflate';
import { buildForecastFromItems, latestBaseDateTimes, type KmaForecastItem } from '../providers/weather/kmaWeatherProvider';
import { NATIONAL_FORECAST_VARIABLES, NATIONAL_FORECAST_REQUIRED_VARIABLES, isExtendedForecast, type NationalForecastRequest, type NationalForecastVariable } from '../providers/weather/kmaNationwideForecastProvider';
import type { ParsedGrid } from '../providers/weather/kmaGridObservationProvider';
import type { WeatherForecast } from '../providers/weather/weatherProvider';

interface FieldRow { issue: string; valid: string; variable: NationalForecastVariable; payload: string; updatedAt: string }
const decoded = new Map<string, DataView>();
// 전국 배열 전체를 매 요청에 풀지 않고 요청 셀이 속한 512개 블록만 읽는다.
const MAX_DECODED_FIELDS = 160;
const BLOCK_CELLS = 512;

export async function saveNationwideForecastField(db: D1Database, request: NationalForecastRequest, grid: ParsedGrid, now: Date) {
  if (grid.width !== 149 || grid.height !== 253 || grid.values.length !== 37_697 || !grid.values.every(Number.isFinite)) {
    throw new Error('INVALID_NATIONWIDE_FORECAST_GRID');
  }
  const blocks: string[] = [];
  for (let offset = 0; offset < grid.values.length; offset += BLOCK_CELLS) {
    const binary = new Uint8Array(Math.min(BLOCK_CELLS, grid.values.length - offset) * 8);
    const view = new DataView(binary.buffer);
    for (let i = 0; i < binary.length / 8; i++) view.setFloat64(i * 8, grid.values[offset + i], true);
    const zipped = gzipSync(binary);
    let text = ''; for (let i = 0; i < zipped.length; i += 8192) text += String.fromCharCode(...zipped.subarray(i, i + 8192));
    blocks.push(btoa(text));
  }
  await db.prepare(`INSERT INTO nationwide_forecast_fields(issue_time,valid_time,variable,payload,updated_at)
    VALUES(?,?,?,?,?) ON CONFLICT(issue_time,valid_time,variable) DO UPDATE SET
    payload=excluded.payload,updated_at=excluded.updated_at`)
    .bind(request.issue, request.valid, request.variable,
      JSON.stringify({ encoding: 'F64LE_GZIP_BLOCK512', width: 149, height: 253, blocks }), now.toISOString()).run();
}

export async function readNationwideForecast(db: D1Database | undefined, nx: number, ny: number, now: Date): Promise<WeatherForecast | null> {
  if (!db || !Number.isInteger(nx) || !Number.isInteger(ny) || nx < 1 || nx > 149 || ny < 1 || ny > 253) return null;
  const start = new Date(now.getTime() + 9 * 3_600_000); start.setUTCHours(0, 0, 0, 0);
  const latest = latestBaseDateTimes(now, 1)[0];
  const cutoff = latest.baseDate + latest.baseTime.slice(0, 2);
  const index = (ny - 1) * 149 + nx - 1;
  const blockCells = Math.min(BLOCK_CELLS, 37_697 - Math.floor(index / BLOCK_CELLS) * BLOCK_CELLS);
  const results = await db.prepare(`SELECT issue_time AS issue,valid_time AS valid,variable,
    json_extract(CASE WHEN json_valid(payload) THEN payload ELSE '{}' END, ?) AS payload,updated_at AS updatedAt
    FROM nationwide_forecast_fields WHERE valid_time BETWEEN ? AND ? AND issue_time <= ?
    ORDER BY valid_time,issue_time DESC`)
    .bind(`$.blocks[${Math.floor(index / BLOCK_CELLS)}]`, start.toISOString().replace(/[-:T]/g, '').slice(0, 10),
      new Date(start.getTime() + 5 * 86_400_000).toISOString().replace(/[-:T]/g, '').slice(0, 10), cutoff).all<FieldRow>();
  const slots = new Map<string, Map<string, FieldRow[]>>();
  for (const row of results.results) {
    const byIssue = slots.get(row.valid) ?? new Map<string, FieldRow[]>();
    const fields = byIssue.get(row.issue) ?? []; fields.push(row); byIssue.set(row.issue, fields); slots.set(row.valid, byIssue);
  }
  const items: KmaForecastItem[] = [];
  const fetchedAt = new Map<string, string>();
  const missingWindDirection = new Set<string>();
  let latestIssue = '';
  for (const [valid, issues] of slots) {
    // 필수 8개 변수는 같은 발표에서 선택한다. 풍향만 빠져도 다른 요소를 버리지 않는다.
    let complete: FieldRow[] | undefined;
    for (const rows of issues.values()) {
      if (!NATIONAL_FORECAST_REQUIRED_VARIABLES.every((variable) => rows.some((r) => r.variable === variable))) continue;
      try {
        const values = rows.filter((r) => NATIONAL_FORECAST_VARIABLES.includes(r.variable as typeof NATIONAL_FORECAST_VARIABLES[number]))
          .flatMap((row) => { const value = valueAt(row, index % BLOCK_CELLS, blockCells);
            return validValue(row.variable, value) ? [item(row, nx, ny, value)] : []; });
        items.push(...values);
        if (!values.some((value) => value.category === 'VEC')) missingWindDirection.add(valid);
        complete = rows; break;
      } catch { console.error(JSON.stringify({ event: 'national_forecast_cache_corrupt', issue: rows[0].issue, valid })); }
    }
    if (complete) {
      fetchedAt.set(valid, complete.map((row) => row.updatedAt).sort()[0]);
      latestIssue = latestIssue > complete[0].issue ? latestIssue : complete[0].issue;
    }
    for (const variable of ['TMN', 'TMX'] as const) {
      for (const row of [...issues.values()].flat().filter((r) => r.variable === variable)) {
        try {
          const value = valueAt(row, index % BLOCK_CELLS, blockCells);
          if (validValue(variable, value)) { items.push(item(row, nx, ny, value)); break; }
        } catch { console.error(JSON.stringify({ event: 'national_forecast_cache_corrupt', issue: row.issue, valid, variable })); }
      }
    }
  }
  if (!latestIssue) return null;
  try {
    const forecast = buildForecastFromItems(items, now, { baseDate: latestIssue.slice(0, 8), baseTime: latestIssue.slice(8) + '00' });
    for (const snapshot of [forecast.current, ...forecast.hourly, ...forecast.timelineHourly ?? []]) {
      const valid = snapshot.observedAt.replace(/[-:T]/g, '').slice(0, 10);
      snapshot.fetchedAt = fetchedAt.get(valid);
      if (missingWindDirection.has(valid)) snapshot.qualityFlags = [...new Set([...(snapshot.qualityFlags ?? []), 'WIND_DIRECTION_UNAVAILABLE'])];
    }
    for (const day of forecast.daily) {
      const issues = items.filter((i) => i.fcstDate === day.date).map((i) => i.baseDate + i.baseTime).sort();
      if (issues[0]) { const t = issues[0]; day.issuedAt = `${t.slice(0,4)}-${t.slice(4,6)}-${t.slice(6,8)}T${t.slice(8,10)}:00:00+09:00`; }
    }
    return forecast;
  }
  catch { return null; }
}

function valueAt(row: FieldRow, index: number, cells: number): number {
  if (typeof row.payload !== 'string') throw new Error('CORRUPT_NATIONWIDE_FORECAST_FIELD');
  const key = row.payload;
  let view = decoded.get(key);
  if (!view) {
    const compressed = Uint8Array.from(atob(row.payload), (s) => s.charCodeAt(0));
    const raw = gunzipSync(compressed);
    if (raw.byteLength % 8 !== 0 || raw.byteLength > BLOCK_CELLS * 8 || raw.byteLength === 0) throw new Error('CORRUPT_NATIONWIDE_FORECAST_FIELD');
    view = new DataView(raw.buffer, raw.byteOffset, raw.byteLength);
    decoded.set(key, view);
    if (decoded.size > MAX_DECODED_FIELDS) decoded.delete(decoded.keys().next().value!);
  }
  if (view.byteLength !== cells * 8) throw new Error('CORRUPT_NATIONWIDE_FORECAST_FIELD');
  return view.getFloat64(index * 8, true);
}
function validValue(variable: NationalForecastVariable, value: number): boolean {
  if (!Number.isFinite(value) || value === -99 || value <= -900) return false;
  if (['TMP', 'TMN', 'TMX'].includes(variable)) return value >= -80 && value <= 60;
  if (variable === 'SKY') return [1, 3, 4].includes(value);
  if (variable === 'PTY') return Number.isInteger(value) && value >= 0 && value <= 7;
  if (variable === 'VEC') return value >= 0 && value <= 360;
  return value >= 0 && value <= (variable === 'PCP' || variable === 'SNO' ? 500 : 100);
}
function item(row: FieldRow, nx: number, ny: number, value: number): KmaForecastItem {
  return { nx, ny, baseDate: row.issue.slice(0, 8), baseTime: row.issue.slice(8) + '00',
    fcstDate: row.valid.slice(0, 8), fcstTime: row.valid.slice(8) + '00',
    category: isExtendedForecast(row.issue, row.valid) && ['WSD', 'PCP', 'SNO'].includes(row.variable)
      ? `${row.variable}_QUALITATIVE` : row.variable,
    fcstValue: String(value) };
}

// 현재 이후의 완성된 원본 1시각을 전수 검사한다. 파일 미수집은 공간 결측으로 판정하지 않는다.
export async function missingLandForecastGrids(db: D1Database, grids: readonly { nx: number; ny: number }[], now: Date) {
  const missing = new Set<string>() as Set<string> & { sourceAvailable: boolean };
  missing.sourceAvailable = false;
  const base = latestBaseDateTimes(now, 1)[0];
  const required = NATIONAL_FORECAST_REQUIRED_VARIABLES;
  const complete = await db.prepare(`SELECT issue_time AS issue,valid_time AS valid FROM nationwide_forecast_fields
    WHERE valid_time >= ? AND issue_time <= ? AND variable IN (${required.map(() => '?').join(',')})
    GROUP BY issue_time,valid_time HAVING COUNT(DISTINCT variable)=? ORDER BY valid_time,issue_time DESC LIMIT 1`)
    .bind(new Date(now.getTime() + 9 * 3_600_000).toISOString().replace(/[-:T]/g,'').slice(0,10),
      base.baseDate + base.baseTime.slice(0,2), ...required, required.length).first<{ issue: string; valid: string }>();
  if (!complete) return missing;
  const rows = await db.prepare('SELECT variable,payload FROM nationwide_forecast_fields WHERE issue_time=? AND valid_time=?')
    .bind(complete.issue, complete.valid).all<{ variable: NationalForecastVariable; payload: string }>();
  const fields = new Map(rows.results.filter((row) => required.includes(row.variable as typeof required[number]))
    .map((row) => [row.variable, JSON.parse(row.payload).blocks as string[]]));
  for (const { nx, ny } of grids) {
    const index = (ny-1)*149 + nx-1;
    if (!Number.isInteger(nx) || !Number.isInteger(ny) || nx < 1 || nx > 149 || ny < 1 || ny > 253) continue;
    const valid = required.every((variable) => validValue(variable, valueAt({ ...complete, variable, updatedAt: '',
      payload: fields.get(variable)?.[Math.floor(index/BLOCK_CELLS)] }, index%BLOCK_CELLS,
      Math.min(BLOCK_CELLS,37697-Math.floor(index/BLOCK_CELLS)*BLOCK_CELLS))));
    if (!valid) missing.add(`${nx}:${ny}`);
  }
  missing.sourceAvailable = true;
  return missing;
}
