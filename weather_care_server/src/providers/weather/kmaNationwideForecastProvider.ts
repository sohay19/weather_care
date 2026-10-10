import { latestBaseDateTimes } from './kmaWeatherProvider';
import { parseKmaGridObservationPayload, type ParsedGrid } from './kmaGridObservationProvider';
import { isRoadIceSeason } from '../road/kmaRoadIceProvider';

export const NATIONAL_FORECAST_VARIABLES = ['TMP', 'REH', 'WSD', 'VEC', 'SKY', 'PTY', 'POP', 'PCP', 'SNO'] as const;
// 풍향 파일이 늦거나 미제공이어도 같은 발표의 나머지 예보를 보존한다.
export const NATIONAL_FORECAST_REQUIRED_VARIABLES = NATIONAL_FORECAST_VARIABLES.filter((variable) => variable !== 'VEC');
export type NationalForecastVariable = typeof NATIONAL_FORECAST_VARIABLES[number] | 'TMN' | 'TMX';
export interface NationalForecastRequest { issue: string; valid: string; variable: NationalForecastVariable }

export function nationwideForecastPlan(now: Date): NationalForecastRequest[] {
  const latest = latestBaseDateTimes(now, 1)[0];
  const issue = `${latest.baseDate}${latest.baseTime.slice(0, 2)}`;
  const fullHours = isRoadIceSeason(now) ? [17] : [5, 17];
  const full = latestBaseDateTimes(now, 16).find((base) => fullHours.includes(Number(base.baseTime.slice(0, 2))))!;
  const fullIssue = `${full.baseDate}${full.baseTime.slice(0, 2)}`;
  const requests: NationalForecastRequest[] = [];
  const todayStart = compactClock(issue); todayStart.setUTCHours(0, 0, 0, 0);
  for (const [base, nearOnly] of [[issue, true], [fullIssue, false]] as const) {
    const clock = compactClock(base);
    const hour = clock.getUTCHours();
    const extended = new Date(clock); extended.setUTCHours(hour < 17 ? 72 : 96, 0, 0, 0);
    const hours = nearOnly ? 24 : (hour < 17 ? 96 : 120) - hour;
    for (let step = 1; step <= hours; step++) {
      const validClock = new Date(clock.getTime() + step * 3_600_000);
      if (validClock < todayStart) continue;
      // 연장 마지막 날은 모든 요소가 3시간 간격이며 풍속·강수량·적설은 정성 코드다.
      if (validClock > extended && validClock.getUTCHours() % 3 !== 0) continue;
      const valid = compactTime(validClock);
      for (const variable of NATIONAL_FORECAST_VARIABLES) {
        // 05시·17시 전체 수집의 마지막 연장일 VEC는 반복 빈 응답이므로 요청·재시도에서 제외한다.
        if (variable === 'VEC' && validClock > extended) continue;
        requests.push({ issue: base, valid, variable });
      }
    }
  }
  // 일 최저·최고는 공식 유효시각 06시·15시만 요청한다.
  const clock = compactClock(issue);
  const end = new Date(clock); end.setUTCHours(clock.getUTCHours() < 17 ? 96 : 120, 0, 0, 0);
  for (let hour = new Date(clock.getTime() + 3_600_000); hour <= end; hour = new Date(hour.getTime() + 3_600_000)) {
    if (hour.getUTCHours() === 6 || hour.getUTCHours() === 15) requests.push({ issue,
      valid: compactTime(hour), variable: hour.getUTCHours() === 6 ? 'TMN' : 'TMX' });
  }
  const coverage = latestBaseDateTimes(now, 16).find((base) => base.baseTime === '0200')!;
  for (const [variable, hour] of [['TMN', 6], ['TMX', 15]] as const) {
    const valid = compactClock(issue); valid.setUTCHours(hour, 0, 0, 0);
    const coverageClock = compactClock(coverage.baseDate + '02');
    if (valid > coverageClock) requests.push({ issue: coverage.baseDate + '02', valid: compactTime(valid), variable });
  }
  return [...new Map(requests.map((r) => [`${r.issue}:${r.valid}:${r.variable}`, r])).values()];
}
export function isExtendedForecast(issue: string, valid: string): boolean {
  const clock = compactClock(issue); const extended = new Date(clock);
  extended.setUTCHours(clock.getUTCHours() < 17 ? 72 : 96, 0, 0, 0);
  return compactClock(valid) > extended;
}

export class KmaNationwideForecastProvider {
  constructor(private readonly key: string, private readonly fetcher: typeof fetch = globalThis.fetch) {}
  async getField(request: NationalForecastRequest): Promise<ParsedGrid> {
    if (!this.key.trim()) throw new Error('KMA APIHub key is not configured');
    const query = new URLSearchParams({ tmfc: request.issue, tmef: request.valid,
      vars: request.variable, authKey: this.key.trim() });
    const response = await this.fetcher(`https://apihub.kma.go.kr/api/typ01/cgi-bin/url/nph-dfs_shrt_grd?${query}`,
      { signal: AbortSignal.timeout(30_000) });
    if (!response.ok) throw new Error(`KMA national forecast request failed with status ${response.status}`);
    const payload = await response.arrayBuffer();
    if (payload.byteLength === 0) throw new Error('KMA national forecast has no body');
    return parseKmaGridObservationPayload(payload);
  }
}

export function compactClock(value: string): Date {
  return new Date(Date.UTC(Number(value.slice(0, 4)), Number(value.slice(4, 6)) - 1,
    Number(value.slice(6, 8)), Number(value.slice(8, 10))));
}
export function compactTime(value: Date): string { return value.toISOString().replace(/[-:T]/g, '').slice(0, 10); }
