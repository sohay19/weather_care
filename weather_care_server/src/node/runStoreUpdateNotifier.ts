import Database from 'better-sqlite3';
import { realpathSync } from 'node:fs';
import { resolve } from 'node:path';
import { sendPush } from '../notification/fcmClient';
import { readAndroidRelease, readIosRelease, type StoreRelease } from './storeRelease';
import { initializeStoreUpdateState, notifyStoreRelease, storeUpdateCandidates } from './storeUpdateNotifier';

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  if (args.some((arg) => !['--preview', '--initialize'].includes(arg))) throw new Error('STORE_UPDATE_ARGUMENT_INVALID');
  const path = process.env.NODE_DATABASE_PATH ?? '';
  // 시험 배포 전용 실행기: 운영 DB·사용자에게는 발송할 수 없다.
  if (!process.env.TEST_ACCESS_KEY?.trim() || resolve(path) !== '/var/lib/weather-care/weather-care-users-test.sqlite' ||
      realpathSync(path) !== '/var/lib/weather-care/weather-care-users-test.sqlite') {
    throw new Error('STORE_UPDATE_TEST_DATABASE_REQUIRED');
  }
  const installations = new Database(path, { readonly: true, fileMustExist: true });
  const state = new Database('/var/lib/weather-care/store-update-test.sqlite');
  state.pragma('busy_timeout=5000');
  initializeStoreUpdateState(state);
  const credentials = {
    projectId: process.env.FCM_PROJECT_ID ?? 'weather-care-2aaa8',
    clientEmail: process.env.FCM_CLIENT_EMAIL ?? '', privateKey: process.env.FCM_PRIVATE_KEY ?? '',
  };
  const readers = [
    { platform: 'ios', read: () => readIosRelease() },
    { platform: 'android', read: () => readAndroidRelease({
      clientEmail: process.env.PLAY_CLIENT_EMAIL ?? credentials.clientEmail,
      privateKey: process.env.PLAY_PRIVATE_KEY ?? credentials.privateKey,
    }) },
  ];
  try {
    for (const reader of readers) {
      try {
        const release: StoreRelease | null = await reader.read();
        if (!release) {
          console.log(JSON.stringify({ event: 'store_update_no_public_release', platform: reader.platform }));
          continue;
        }
        if (args.includes('--initialize')) {
          state.prepare('INSERT OR IGNORE INTO store_releases VALUES (?,?,0,?)')
            .run(release.platform, JSON.stringify(release), new Date().toISOString());
          console.log(JSON.stringify({ event: 'store_update_baseline_initialized', platform: release.platform,
            version: release.version, build: release.build }));
        } else if (args.includes('--preview')) {
          console.log(JSON.stringify({ event: 'store_update_preview', release,
            candidates: storeUpdateCandidates(installations, release).length }));
        } else {
          const summary = await notifyStoreRelease({ state, installations, release,
            send: (payload) => sendPush(credentials, payload) });
          console.log(JSON.stringify({ event: 'store_update_checked', platform: release.platform,
            version: release.version, build: release.build, ...summary }));
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : '';
        console.error(JSON.stringify({ event: 'store_update_check_failed', platform: reader.platform,
          code: /^[A-Z_0-9]+$/.test(message) ? message : 'STORE_UPDATE_CHECK_ERROR' }));
        process.exitCode = 1;
      }
    }
  } finally { installations.close(); state.close(); }
}
void main().catch(() => {
  console.error(JSON.stringify({ event: 'store_update_failed', code: 'STORE_UPDATE_STARTUP_FAILED' }));
  process.exitCode = 1;
});
