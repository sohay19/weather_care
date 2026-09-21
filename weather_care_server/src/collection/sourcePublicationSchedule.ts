const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const MINUTE_MS = 60 * 1000;

export function pollingWindowVersion(now: Date, intervalMinutes: number): string {
  if (!Number.isInteger(intervalMinutes) || intervalMinutes <= 0) {
    throw new Error('Polling interval must be a positive integer');
  }
  const intervalMs = intervalMinutes * MINUTE_MS;
  return new Date(Math.floor(now.getTime() / intervalMs) * intervalMs)
    .toISOString();
}

export function latestRadarProductVersion(now: Date): string {
  const availableAt = now.getTime() - 10 * MINUTE_MS;
  const target = new Date(Math.floor(availableAt / (5 * MINUTE_MS)) * 5 * MINUTE_MS);
  return compactKoreanTime(target);
}

export function koreanObservationVersion(koreanClock: Date): string {
  return `${koreanClock.getUTCFullYear()}${String(koreanClock.getUTCMonth() + 1).padStart(2, '0')}${String(koreanClock.getUTCDate()).padStart(2, '0')}${String(koreanClock.getUTCHours()).padStart(2, '0')}00`;
}

export function previousKoreanDate(now: Date): string {
  return new Date(now.getTime() + KST_OFFSET_MS - 24 * 60 * MINUTE_MS)
    .toISOString()
    .slice(0, 10);
}

export function compactIssueToIso(issueTime: string): string {
  if (!/^\d{10}(\d{2})?$/.test(issueTime)) {
    throw new Error('Issue time must use yyyyMMddHH or yyyyMMddHHmm');
  }
  const minute = issueTime.length === 12 ? issueTime.slice(10, 12) : '00';
  return `${issueTime.slice(0, 4)}-${issueTime.slice(4, 6)}-${issueTime.slice(6, 8)}T${issueTime.slice(8, 10)}:${minute}:00+09:00`;
}

export function latestAirKoreaForecastIssue(now: Date): string {
  const effective = new Date(now.getTime() + KST_OFFSET_MS - 30 * MINUTE_MS);
  const hours = [5, 11, 17, 23];
  const currentMinutes = effective.getUTCHours() * 60 + effective.getUTCMinutes();
  const hour = [...hours].reverse().find((candidate) => candidate * 60 <= currentMinutes);
  const issue = new Date(Date.UTC(
    effective.getUTCFullYear(),
    effective.getUTCMonth(),
    effective.getUTCDate() - (hour === undefined ? 1 : 0),
    hour ?? hours.at(-1)!,
  ));
  return koreanObservationVersion(issue);
}

function compactKoreanTime(utc: Date): string {
  const koreanClock = new Date(utc.getTime() + KST_OFFSET_MS);
  return `${koreanClock.getUTCFullYear()}${String(koreanClock.getUTCMonth() + 1).padStart(2, '0')}${String(koreanClock.getUTCDate()).padStart(2, '0')}${String(koreanClock.getUTCHours()).padStart(2, '0')}${String(koreanClock.getUTCMinutes()).padStart(2, '0')}`;
}
