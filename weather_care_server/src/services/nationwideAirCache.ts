import { collectedCacheKey, getCollectedCache, saveCollectedCache } from '../database/collectedWeatherRepository';
import { AIRKOREA_PROVINCES, AirKoreaAirQualityProvider, AirKoreaAirQualityProviderError,
  isRecentAirObservation, type AirStationCatalog } from '../providers/air/airKoreaAirQualityProvider';
import type { AirQualitySnapshot } from '../providers/air/airQualityProvider';
import type { NationwideAirQualitySnapshot } from '../providers/environmental/environmentalDataService';
import { providerErrorDiagnostic } from '../observability/providerErrorDiagnostics';
import type { ServerEnv } from '../types';

interface AirRetry { failures: number; nextRetryAt: string; blocked?: boolean }
const retryKey = (source:string) => `AIR_RETRY_${source}`;
const provinceKey = (province:string) => `AIR_PROVINCE_${province}`;
const GLOBAL = 'GLOBAL';

// 캐시와 실패 상태는 SQLite에 보존해 프로세스 재시작으로 429 대기가 초기화되지 않게 한다.
export async function collectNationwideAirQuality(env:ServerEnv, now:Date):Promise<NationwideAirQualitySnapshot|null> {
  const owner=crypto.randomUUID();
  const key='AIR_COLLECTOR_LEASE';
  const acquired=await env.DB.prepare(`INSERT INTO weather_cache(cache_key,region_id,nx,ny,cache_type,payload,status,updated_at)
    VALUES(?,?,0,0,'AIR_COLLECTOR_LEASE',?,'AVAILABLE',?) ON CONFLICT(cache_key) DO UPDATE SET
    payload=excluded.payload,updated_at=excluded.updated_at WHERE weather_cache.updated_at <= ?`)
    .bind(key,key,owner,now.toISOString(),new Date(now.getTime()-10*60_000).toISOString()).run();
  if (!acquired.meta.changes) return (await getCollectedCache<NationwideAirQualitySnapshot>(env.DB,collectedCacheKey.nationwideAir))?.value ?? null;
  try { return await collectAir(env,now); }
  finally { await env.DB.prepare('DELETE FROM weather_cache WHERE cache_key=? AND payload=?').bind(key,owner).run(); }
}

async function collectAir(env:ServerEnv, now:Date):Promise<NationwideAirQualitySnapshot|null> {
  const cached = await getCollectedCache<NationwideAirQualitySnapshot>(env.DB,collectedCacheKey.nationwideAir);
  const control = await getCollectedCache<AirRetry>(env.DB,retryKey(GLOBAL));
  if (control?.value.blocked || Date.parse(control?.value.nextRetryAt ?? '') > now.getTime()) return cached?.value ?? null;
  // 기존 배포 캐시도 최초 1시간은 재사용한다. 부분 갱신에서는 각 도의 수집 시각을 판정한다.
  const states = await env.DB.prepare("SELECT cache_key FROM weather_cache WHERE cache_type='AIR_PROVINCE'").all();
  if (!states.results.length && cached && now.getTime()-Date.parse(cached.updatedAt) < 3_600_000) return cached.value;
  let actualCalls = 0;
  const provider = new AirKoreaAirQualityProvider({serviceKey:env.KMA_SERVICE_KEY,now:()=>now,timeoutMs:30_000,
    fetcher:async (input,init) => { actualCalls++; return globalThis.fetch(input,init); }});
  const catalogCache = await getCollectedCache<AirStationCatalog>(env.DB,'AIR_STATION_CATALOG');
  let catalog = catalogCache?.value ?? cached?.value.catalog;
  if (!catalog || now.getTime()-Date.parse(catalog.fetchedAt) >= 86_400_000) {
    const status = await getCollectedCache<AirRetry>(env.DB,retryKey('CATALOG'));
    if (!status?.value.blocked && !(Date.parse(status?.value.nextRetryAt ?? '') > now.getTime())) {
      try {
        catalog = await provider.getStationCatalog();
        await saveCollectedCache(env.DB,{key:'AIR_STATION_CATALOG',type:'AIR_STATION_CATALOG',value:catalog,updatedAt:now});
        await clearRetry(env.DB,'CATALOG');
      } catch (error) {
        const stop = await failed(env.DB,'CATALOG',error,now);
        if (stop) return cached?.value ?? null;
        // 유효한 이전 좌표 목록으로 실측 수집을 계속한다. 신규 미등록 지점은 채택되지 않는다.
      }
    }
  }
  if (!catalog) return null;
  let stopped = false, cursor = 0, succeeded = 0, skipped = 0;
  let failureWrites=Promise.resolve();
  // 최대 3개 진행 중 요청은 완료·저장하고, 429/권한 실패 뒤에는 대기열을 시작하지 않는다.
  await Promise.all(Array.from({length:3},async () => {
    while (!stopped && cursor < AIRKOREA_PROVINCES.length) {
      const province = AIRKOREA_PROVINCES[cursor++];
      const [record,state] = await Promise.all([
        getCollectedCache<AirQualitySnapshot[]>(env.DB,provinceKey(province)),
        getCollectedCache<AirRetry>(env.DB,retryKey(province)),
      ]);
      if (stopped || state?.value.blocked || Date.parse(state?.value.nextRetryAt ?? '') > now.getTime() ||
          record && now.getTime()-Date.parse(record.updatedAt) < 3_600_000) { skipped++; continue; }
      try {
        const observations = await provider.getProvinceMeasurements(province);
        await saveCollectedCache(env.DB,{key:provinceKey(province),type:'AIR_PROVINCE',value:observations,updatedAt:now});
        await clearRetry(env.DB,province);
        succeeded++;
      } catch (error) {
        const reason=providerErrorDiagnostic(error).failureReason;
        const code=error instanceof AirKoreaAirQualityProviderError ? error.resultCode : undefined;
        if (['RATE_LIMITED','AUTHORIZATION_FAILED','NOT_CONFIGURED'].includes(reason) || ['20','22','30','31','32'].includes(code ?? '')) stopped=true;
        failureWrites=failureWrites.then(async()=>{if (await failed(env.DB,province,error,now)) stopped=true;});
        await failureWrites;
      }
    }
  }));
  const byStation = new Map<string,AirQualitySnapshot>();
  for (const item of cached?.value.observations ?? []) if (usable(item,now)) byStation.set(item.stationName!,item);
  for (const province of AIRKOREA_PROVINCES) {
    const record = await getCollectedCache<AirQualitySnapshot[]>(env.DB,provinceKey(province));
    for (const item of record?.value ?? []) if (usable(item,now)) {
      const old = byStation.get(item.stationName!);
      if (!old || Date.parse(item.observedAt) >= Date.parse(old.observedAt)) byStation.set(item.stationName!,item);
    }
  }
  const snapshot = {catalog,observations:[...byStation.values()],collectedAt:succeeded ? now.toISOString() : cached?.value.collectedAt ?? now.toISOString()};
  if (succeeded && !stopped) await clearRetry(env.DB,GLOBAL);
  if (succeeded || catalog !== cached?.value.catalog) await saveCollectedCache(env.DB,{
    key:collectedCacheKey.nationwideAir,type:'COLLECTED_NATIONWIDE_AIR',value:snapshot,updatedAt:now});
  console.log(JSON.stringify({event:'nationwide_air_collection_completed',actualCalls,succeeded,skipped,stopped,
    observations:snapshot.observations.length,catalogFetchedAt:catalog.fetchedAt}));
  return snapshot.observations.length ? snapshot : null;
}

function usable(item:AirQualitySnapshot,now:Date):boolean {
  const age = now.getTime()-Date.parse(item.observedAt);
  return isRecentAirObservation(item.observedAt,now) && age >= 0 && age <= 3*3_600_000;
}
async function clearRetry(db:D1Database,source:string) {
  await db.prepare('DELETE FROM weather_cache WHERE cache_key=?').bind(retryKey(source)).run();
}
async function failed(db:D1Database,source:string,error:unknown,now:Date):Promise<boolean> {
  const diagnostic = providerErrorDiagnostic(error);
  const code = error instanceof AirKoreaAirQualityProviderError ? error.resultCode : undefined;
  const auth = ['AUTHORIZATION_FAILED','NOT_CONFIGURED'].includes(diagnostic.failureReason) || ['20','30','31','32'].includes(code ?? '');
  const rate = diagnostic.failureReason === 'RATE_LIMITED' || ['22','LIMITED_NUMBER_OF_SERVICE_REQUESTS_EXCEEDS_ERROR'].includes(code ?? '');
  const old = await getCollectedCache<AirRetry>(db,retryKey(rate || auth ? GLOBAL : source));
  const failures = (old?.value.failures ?? 0)+1;
  const base = rate ? 15*60_000 : 5*60_000;
  const delay = Math.min(3_600_000,base*2**Math.min(failures-1,4));
  const requested = error instanceof AirKoreaAirQualityProviderError ? error.retryAfterMs ?? 0 : 0;
  const nextRetryAt = new Date(now.getTime()+Math.max(requested,delay)+Math.floor(Math.random()*30_000)).toISOString();
  const value = {failures,nextRetryAt,blocked:auth || old?.value.blocked};
  await saveCollectedCache(db,{key:retryKey(source),type:'AIR_RETRY',value,updatedAt:now});
  if (rate || auth) await saveCollectedCache(db,{key:retryKey(GLOBAL),type:'AIR_RETRY',value,updatedAt:now});
  console.error(JSON.stringify({event:'nationwide_air_source_failed',source,
    endpoint:source==='CATALOG' ? 'STATION_CATALOG' : 'PROVINCE_MEASUREMENTS',
    ...diagnostic,resultCode:code && /^[A-Z_0-9]{1,64}$/.test(code) ? code : undefined,
    failures,nextRetryAt,authorizationBlocked:auth,retryAfterMs:requested}));
  return rate || auth;
}
