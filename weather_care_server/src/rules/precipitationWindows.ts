import { WeatherRuleFactType, WeatherSnapshot } from '../types';
import { snapshotEnd, snapshotTime } from './timeWindows';

const HOUR = 3_600_000;

export function precipitationPeriod(snapshot: WeatherSnapshot) {
  const period = snapshot.precipitationPeriod;
  if (!period) return undefined;
  const start = Date.parse(period.start);
  const end = Date.parse(period.end);
  return Number.isFinite(start) && end - start === HOUR &&
    end === Date.parse(snapshotTime(snapshot)) ? period : undefined;
}

export function precipitationStart(snapshot: WeatherSnapshot): string {
  return precipitationPeriod(snapshot)?.start ?? snapshotTime(snapshot);
}

export function precipitationEnd(snapshot: WeatherSnapshot): string {
  const period = precipitationPeriod(snapshot);
  return period ? new Date(Date.parse(period.end) - 1).toISOString() : snapshotEnd(snapshot);
}

export function isPrecipitationFact(type: WeatherRuleFactType): boolean {
  return [WeatherRuleFactType.RAIN_LIKELY, WeatherRuleFactType.HEAVY_RAIN,
    WeatherRuleFactType.SNOW_LIKELY, WeatherRuleFactType.HEAVY_SNOW].includes(type);
}

// Preserve the raw forecast for display. Only remove unusable/elapsed
// precipitation from the decision copy; never shift temperature or wind.
export function precipitationDecisionSnapshot(snapshot: WeatherSnapshot, now?: Date): WeatherSnapshot {
  if (snapshot.precipitationPeriod === undefined) return snapshot;
  const period = precipitationPeriod(snapshot);
  const reference = now?.getTime() ?? Date.parse(snapshot.fetchedAt ?? '');
  if (period && (!Number.isFinite(reference) || Date.parse(period.end) > reference)) return snapshot;
  return withoutPrecipitation(snapshot);
}

export function withoutPrecipitation(snapshot: WeatherSnapshot): WeatherSnapshot {
  return { ...snapshot, precipitationPeriod: null, precipitationType: undefined,
    precipitationProbability: undefined, precipitationAmount: undefined,
    precipitationAmountRange: undefined, snowExpected: undefined,
    snowProbability: undefined, snowfallAmount: undefined, snowfallAmountRange: undefined };
}

export function precipitationOnlySnapshot(snapshot: WeatherSnapshot): WeatherSnapshot {
  const { observedAt, forecastAt, precipitationPeriod, fetchedAt, issuedAt, provider,
    precipitationType, precipitationProbability, precipitationAmount,
    precipitationAmountRange, snowExpected, snowProbability, snowfallAmount, snowfallAmountRange } = snapshot;
  return { observedAt, forecastAt, precipitationPeriod, fetchedAt, issuedAt, provider,
    precipitationType, precipitationProbability, precipitationAmount,
    precipitationAmountRange, snowExpected, snowProbability, snowfallAmount, snowfallAmountRange };
}

export function koreaDate(iso: string): string {
  return new Date(Date.parse(iso) + 9 * HOUR).toISOString().slice(0, 10);
}

export function otherDatePrefix(start: string, reference?: string): string {
  if (!reference || !Number.isFinite(Date.parse(reference)) || koreaDate(start) === koreaDate(reference)) return '';
  const date = koreaDate(start);
  const referenceDate = koreaDate(reference);
  const dayOffset = Math.round(
    (Date.parse(`${date}T00:00:00Z`) - Date.parse(`${referenceDate}T00:00:00Z`)) /
      (24 * HOUR),
  );
  if (dayOffset === 1) return '내일 ';
  if (dayOffset === 2) return '모레 ';
  if (dayOffset === 3) return '글피 ';
  return `${Number(date.slice(5, 7))}월 ${Number(date.slice(8, 10))}일 `;
}

// Match rain to the hour *following* a point temperature/wind timestamp when
// finding a joint activity window. Missing/ambiguous coverage is not dry weather.
export function precipitationAtPoint(snapshot: WeatherSnapshot, hourly: WeatherSnapshot[]): WeatherSnapshot {
  if (snapshot.precipitationPeriod === undefined) return snapshot;
  const time = Date.parse(snapshotTime(snapshot));
  const matches = hourly.filter((item) => {
    const period = precipitationPeriod(item);
    return period && Date.parse(period.start) === time;
  });
  if (matches.length !== 1) return withoutPrecipitation(snapshot);
  const rain = matches[0];
  return { ...snapshot, precipitationType: rain.precipitationType,
    precipitationProbability: rain.precipitationProbability,
    precipitationAmount: rain.precipitationAmount, precipitationAmountRange: rain.precipitationAmountRange,
    snowExpected: rain.snowExpected, snowfallAmount: rain.snowfallAmount,
    snowfallAmountRange: rain.snowfallAmountRange, snowProbability: rain.snowProbability };
}

export function koreanHour(iso: string): string {
  const date = new Date(Date.parse(iso) + 9 * HOUR);
  const hour = date.getUTCHours();
  const minute = date.getUTCMinutes();
  return `${hour < 12 ? '오전' : '오후'} ${hour % 12 || 12}시${minute ? ` ${minute}분` : ''}`;
}

export function periodLabel(start: string, endExclusive: string): string {
  const startDate = new Date(Date.parse(start) + 9 * HOUR).toISOString().slice(0, 10);
  const endDate = new Date(Date.parse(endExclusive) + 9 * HOUR).toISOString().slice(0, 10);
  const from = koreanHour(start);
  const until = koreanHour(endExclusive);
  if (startDate !== endDate) return `${from}~다음 날 ${until}`;
  return from.slice(0, 2) === until.slice(0, 2)
    ? `${from}~${until.slice(3)}` : `${from}~${until}`;
}

export function precipitationLabel(snapshot: WeatherSnapshot): string {
  const period = precipitationPeriod(snapshot);
  return period ? otherDatePrefix(period.start, snapshot.fetchedAt) + periodLabel(period.start, period.end)
    : koreanHour(snapshotTime(snapshot));
}
