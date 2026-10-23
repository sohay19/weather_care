import { pathToFileURL } from 'node:url';
import { collectGridLightning } from '../collection/gridExtraCollection';
import { weatherDatabase } from '../database/weatherDatabase';
import { createNodeRuntime } from './runtime';

/** 기존 운영 버전에 낙뢰 수집기가 없을 때 공용 관측만 갱신한다. 알림은 보내지 않는다. */
export async function collectSharedLightning(): Promise<void> {
  const runtime = createNodeRuntime();
  try {
    if (runtime.env.WEATHER_COLLECTION_ENABLED === 'false') return;
    await collectGridLightning({ db: weatherDatabase(runtime.env),
      key: runtime.env.KMA_APIHUB_KEY, now: new Date() });
  } finally { runtime.close(); }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  void collectSharedLightning().catch(() => {
    console.error(JSON.stringify({ event: 'shared_lightning_collection_failed' }));
    process.exitCode = 1;
  });
}
