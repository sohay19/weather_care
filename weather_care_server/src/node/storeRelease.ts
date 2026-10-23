import { z } from 'zod';
import { createGoogleAccessToken, type GoogleServiceAccountCredentials } from '../google/googleServiceAccount';

export const STORE_PACKAGE = 'com.codesoha.weathercare';
export type StorePlatform = 'ios' | 'android';
export interface StoreRelease {
  platform: StorePlatform;
  version: string;
  build?: number;
  url: string;
}
const versionPattern = /^\d+(?:\.\d+){1,3}$/;
export function compareVersions(left: string, right: string): number | null {
  if (!versionPattern.test(left) || !versionPattern.test(right)) return null;
  const a = left.split('.').map(Number), b = right.split('.').map(Number);
  if ([...a, ...b].some((n) => !Number.isSafeInteger(n))) return null;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const difference = (a[i] ?? 0) - (b[i] ?? 0);
    if (difference) return Math.sign(difference);
  }
  return 0;
}

export function needsStoreUpdate(installed: string | null, release: StoreRelease): boolean {
  // 버전을 보고하지 않던 기존 앱은 새 공개 버전의 안내 대상에 포함한다.
  if (!installed?.trim()) return true;
  const [version, build] = installed.trim().split('+');
  if (release.platform === 'android' && release.build && /^\d+$/.test(build ?? '')) {
    return Number(build) < release.build;
  }
  const order = compareVersions(version, release.version);
  return order !== null && order < 0;
}

export function releaseKey(release: StoreRelease): string {
  return release.platform === 'android' ? String(release.build) : release.version;
}
export function newerRelease(next: StoreRelease, previous: StoreRelease): boolean {
  return next.platform === 'android' ? next.build! > previous.build! :
    compareVersions(next.version, previous.version) === 1;
}

async function jsonResponse(response: Response, label: string): Promise<unknown> {
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error(`${label}_HTTP_${response.status}`);
  }
  return response.json();
}

export async function readIosRelease(fetcher: typeof fetch = fetch): Promise<StoreRelease | null> {
  const data = z.object({ results: z.array(z.object({
    bundleId: z.string(), version: z.string(), trackViewUrl: z.string(),
  }).passthrough()) }).parse(await jsonResponse(await fetcher(
    `https://itunes.apple.com/lookup?bundleId=${STORE_PACKAGE}&country=kr`,
    { signal: AbortSignal.timeout(15_000) }), 'APP_STORE'));
  const app = data.results.find((item) => item.bundleId === STORE_PACKAGE);
  if (!app) return null;
  const url = new URL(app.trackViewUrl);
  if (compareVersions(app.version, app.version) !== 0 || url.protocol !== 'https:' ||
      url.hostname !== 'apps.apple.com' || !/\/id\d+/.test(url.pathname)) {
    throw new Error('APP_STORE_RESPONSE_INVALID');
  }
  return { platform: 'ios', version: app.version, url: url.toString() };
}

export async function readAndroidRelease(credentials: GoogleServiceAccountCredentials,
  fetcher: typeof fetch = fetch, tokenProvider?: () => Promise<string>): Promise<StoreRelease | null> {
  const token = await (tokenProvider?.() ?? createGoogleAccessToken(credentials,
    'https://www.googleapis.com/auth/androidpublisher', fetcher));
  const base = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${STORE_PACKAGE}/edits`;
  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
  // 조회용 임시 edit만 생성한다. commit/배포/트랙 수정은 호출하지 않는다.
  const edit = z.object({ id: z.string().regex(/^[A-Za-z0-9_-]+$/) }).parse(await jsonResponse(
    await fetcher(base, { method: 'POST', headers, body: '{}', signal: AbortSignal.timeout(15_000) }), 'PLAY_EDIT'));
  const editUrl = `${base}/${edit.id}`;
  try {
    const data = z.object({ track: z.literal('production'), releases: z.array(z.object({
      name: z.string().optional(), status: z.string(), versionCodes: z.array(z.string().regex(/^\d+$/)),
      countryTargeting: z.unknown().optional(),
    })).default([]) }).parse(await jsonResponse(await fetcher(`${editUrl}/tracks/production`, {
      headers, signal: AbortSignal.timeout(15_000),
    }), 'PLAY_TRACK'));
    const completed = data.releases.filter((r) => r.status === 'completed' && !r.countryTargeting)
      .flatMap((r) => r.versionCodes.map((code) => ({ build: Number(code), version: r.name ?? '' })))
      .filter((r) => Number.isSafeInteger(r.build) && r.build > 0)
      .sort((a, b) => b.build - a.build)[0];
    if (!completed) return null;
    // 릴리스 이름은 운영자가 임의로 지정할 수 있으므로 버전 코드가 판단 기준이다.
    return { platform: 'android', ...completed,
      url: `https://play.google.com/store/apps/details?id=${STORE_PACKAGE}` };
  } finally {
    const cleanup = await fetcher(editUrl, { method: 'DELETE', headers, signal: AbortSignal.timeout(15_000) });
    if (!cleanup.ok) { await cleanup.body?.cancel(); throw new Error(`PLAY_EDIT_CLEANUP_HTTP_${cleanup.status}`); }
  }
}
