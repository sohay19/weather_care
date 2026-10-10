import {afterEach,beforeEach,describe,expect,it,vi} from 'vitest';
import {SqliteD1Database,runSqliteMigrations} from '../src/node/sqliteD1';
import {nodeServerEnv} from '../src/node/runtime';
import {collectGridObservationSnapshot,backfillGridObservationHistory} from '../src/services/gridObservationCache';
import {getGridObservationSnapshot,saveGridObservationSnapshot} from '../src/database/gridObservationRepository';
import {getCollectedCache,saveCollectedCache,collectedCacheKey} from '../src/database/collectedWeatherRepository';
import {apiHubBudgetedFetch} from '../src/services/apiHubFetch';
import {reserveApiHubBudget,getApiHubUsage} from '../src/database/apiUsageRepository';
import {collectNationwideAirQuality} from '../src/services/nationwideAirCache';
import {AirKoreaAirQualityProvider,AirKoreaAirQualityProviderError,AIRKOREA_PROVINCES} from '../src/providers/air/airKoreaAirQualityProvider';
import {observationSnapshot} from './gridObservationFixture';
import {KmaDailyObservationProvider,dailyObservationsAtLocations} from '../src/providers/weather/kmaDailyObservationProvider';
import {nearestNationwideAirQuality} from '../src/providers/environmental/environmentalDataService';

let database:SqliteD1Database;
const now=new Date('2026-10-09T06:00:00Z');
beforeEach(()=>{
  database=new SqliteD1Database(':memory:');runSqliteMigrations(database);
  vi.useFakeTimers();vi.setSystemTime(now);
  vi.spyOn(console,'log').mockImplementation(()=>{});vi.spyOn(console,'error').mockImplementation(()=>{});
  vi.spyOn(console,'warn').mockImplementation(()=>{});
  vi.spyOn(globalThis,'fetch').mockRejectedValue(new Error('TEST_EXTERNAL_NETWORK_FORBIDDEN'));
});
afterEach(()=>{vi.restoreAllMocks();vi.useRealTimers();database.close();});
const env=()=>nodeServerEnv(database,{KMA_APIHUB_KEY:'synthetic',KMA_SERVICE_KEY:'synthetic'});
function gridResponse(variable:string):Response {
  const buffer=new ArrayBuffer(4+149*253*8),view=new DataView(buffer);
  view.setUint16(0,149,true);view.setUint16(2,253,true);
  const value={T1H:20,REH:60,WSD:3,VEC:90,PTY:0,RN1:0}[variable];
  for(let i=0;i<149*253;i++)view.setFloat64(4+i*8,value,true);
  return new Response(buffer);
}
describe('실황 파일 보존과 누락 보충',()=>{
  it('습도 실패 시 정상 5개를 보존하고 다음에는 습도만 요청해 같은 회차를 게시한다',async()=>{
    const db=env().DB,calls:string[]=[];let fail=true;
    vi.mocked(globalThis.fetch).mockImplementation(async input=>{
      const variable=new URL(String(input)).searchParams.get('vars')!;calls.push(variable);
      if(variable==='REH'&&fail)throw new DOMException('timeout','TimeoutError');
      return gridResponse(variable);
    });
    const clock=new Date('2026-10-09T14:50:00Z'),at='2026-10-09T14:50:00+09:00';
    expect(await collectGridObservationSnapshot({db,serviceKey:'synthetic',clock,now})).toBeNull();
    expect(await getGridObservationSnapshot(db,at)).toBeNull();
    const partial=await getCollectedCache<any>(db,'GRID_OBSERVATION_PARTIAL_2026-10-09T05:50:00.000Z');
    expect(Object.keys(partial!.value.fields).sort()).toEqual(['PTY','RN1','T1H','VEC','WSD']);
    expect(await collectGridObservationSnapshot({db,serviceKey:'synthetic',clock,now:new Date(now.getTime()+60_000)})).toBeNull();
    expect(calls).toHaveLength(6);
    fail=false;vi.setSystemTime(new Date(now.getTime()+120_000));
    const result=await collectGridObservationSnapshot({db,serviceKey:'synthetic',clock,now:new Date(now.getTime()+120_000),requiredOnly:true});
    expect(result!.observedAt).toBe(at);expect(calls.slice(6)).toEqual(['REH']);
    expect(Object.keys((await getGridObservationSnapshot(db,at))!.value.fields)).toHaveLength(6);
    expect(await getCollectedCache(db,'GRID_OBSERVATION_PARTIAL_2026-10-09T05:50:00.000Z')).toBeNull();
  });
  it('지난 누락 회차를 찾아 핵심 3개만 수집하고 현재 시각과 섞지 않는다',async()=>{
    const db=env().DB;
    await saveGridObservationSnapshot(db,observationSnapshot('2026-10-09T14:10:00+09:00'),now);
    await saveGridObservationSnapshot(db,observationSnapshot('2026-10-09T14:30:00+09:00'),now);
    const calls:string[]=[];
    vi.mocked(globalThis.fetch).mockImplementation(async input=>{
      const url=new URL(String(input));calls.push(url.searchParams.get('tmfc')+':'+url.searchParams.get('vars'));
      return gridResponse(url.searchParams.get('vars')!);
    });
    await backfillGridObservationHistory(db,'synthetic',now);
    expect(await getGridObservationSnapshot(db,'2026-10-09T14:20:00+09:00')).not.toBeNull();
    expect(calls).toHaveLength(6);expect(calls.every(call=>/:(T1H|REH|WSD)$/.test(call))).toBe(true);
    expect(calls.every(call=>call.startsWith('202610091420')||call.startsWith('202610091440'))).toBe(true);
  });
});
describe('APIHub 보호 예산',()=>{
  it('다른 항목의 재시도 한도가 찼어도 핵심 실황 예산을 유지한다',async()=>{
    const db=env().DB;
    await reserveApiHubBudget(db,'APIHUB_RETRY_OTHER',1,15_000_000,now);
    const fetcher=vi.fn(async()=>new Response('ok'));
    await expect(apiHubBudgetedFetch({db,provider:'RADAR',now,maxBytes:1000,retry:true,fetcher})('https://apihub.kma.go.kr/test'))
      .rejects.toThrow('BUDGET_EXHAUSTED');
    await apiHubBudgetedFetch({db,provider:'GRID_OBSERVATION_10_MINUTES',now,maxBytes:1000,retry:true,fetcher})
      ('https://apihub.kma.go.kr/test?vars=T1H');
    expect(fetcher).toHaveBeenCalledOnce();
    expect((await getApiHubUsage(db,now)).responseBytes).toBe(15_000_002);
  });
  it('기존 공통 재시도 장부도 합산해 한도를 초기화하지 않고 대기 시각을 반환한다',async()=>{
    const db=env().DB;await reserveApiHubBudget(db,'APIHUB_RETRY',1,100_000_000,now);
    const fetcher=vi.fn();
    const request=apiHubBudgetedFetch({db,provider:'GRID_OBSERVATION_10_MINUTES',now,maxBytes:1000,retry:true,fetcher});
    await expect(request('https://apihub.kma.go.kr/test?vars=T1H')).rejects.toMatchObject({message:'APIHUB_BUDGET_EXHAUSTED',nextRetryAt:expect.any(Number)});
    expect(fetcher).not.toHaveBeenCalled();
  });
  it('동시 예약에도 재시도 전체 상한을 원자적으로 적용한다',async()=>{
    const db=env().DB;await reserveApiHubBudget(db,'APIHUB_RETRY',1,99_000_000,now);
    const options={retryDailyByteLimit:100_000_000,providerDailyByteLimit:50_000_000};
    expect((await Promise.all(['CORE','FORECAST'].map(group=>reserveApiHubBudget(db,'APIHUB_RETRY_'+group,1,1_000_000,now,options))))
      .filter(Boolean)).toHaveLength(1);
  });
});
describe('지역별 대기질 재시도',()=>{
  function mockCatalog(){return vi.spyOn(AirKoreaAirQualityProvider.prototype,'getStationCatalog').mockResolvedValue({
    fetchedAt:now.toISOString(),stations:AIRKOREA_PROVINCES.map(stationName=>({stationName,latitude:37.5,longitude:127}))});}
  it('한 도의 시간초과에도 나머지 성공을 저장하고 정상 도를 다시 요청하지 않는다',async()=>{
    mockCatalog();const provider=vi.spyOn(AirKoreaAirQualityProvider.prototype,'getProvinceMeasurements').mockImplementation(async province=>{
      if(province==='경기')throw new DOMException('timeout','TimeoutError');
      return [{stationName:province,observedAt:now.toISOString(),pm10:20,pm25:10,ozone:0.02}];
    });
    const result=await collectNationwideAirQuality(env(),now);expect(result!.observations).toHaveLength(16);
    provider.mockClear();await collectNationwideAirQuality(env(),new Date(now.getTime()+60_000));expect(provider).not.toHaveBeenCalled();
    await collectNationwideAirQuality(env(),new Date(now.getTime()+6*60_000));
    expect(provider).toHaveBeenCalledOnce();expect(provider).toHaveBeenCalledWith('경기');
  });
  it('429 이후 대기열을 중단하고 Retry-After 2시간 동안 재요청하지 않는다',async()=>{
    mockCatalog();const provider=vi.spyOn(AirKoreaAirQualityProvider.prototype,'getProvinceMeasurements').mockRejectedValue(
      new AirKoreaAirQualityProviderError('AirKorea request failed with status 429',2*3_600_000));
    await collectNationwideAirQuality(env(),now);expect(provider.mock.calls.length).toBeLessThanOrEqual(3);
    provider.mockClear();await collectNationwideAirQuality(env(),new Date(now.getTime()+3_600_000));expect(provider).not.toHaveBeenCalled();
    expect((await getCollectedCache<any>(env().DB,'AIR_RETRY_GLOBAL'))!.value.nextRetryAt)
      .toSatisfy(value=>Date.parse(value)>=now.getTime()+2*3_600_000);
  });
  it('403은 재시작해도 자동 재시도하지 않고 권한 복구 대기 상태를 보존한다',async()=>{
    mockCatalog();const provider=vi.spyOn(AirKoreaAirQualityProvider.prototype,'getProvinceMeasurements').mockRejectedValue(
      new AirKoreaAirQualityProviderError('AirKorea request failed with status 403'));
    await collectNationwideAirQuality(env(),now);provider.mockClear();
    await collectNationwideAirQuality(env(),new Date(now.getTime()+86_400_000));expect(provider).not.toHaveBeenCalled();
    expect((await getCollectedCache<any>(env().DB,'AIR_RETRY_GLOBAL'))!.value.blocked).toBe(true);
  });
  it('관측소 목록 갱신 실패에도 이전 좌표 목록으로 신규 측정값을 수집한다',async()=>{
    await saveCollectedCache(env().DB,{key:collectedCacheKey.nationwideAir,type:'COLLECTED_NATIONWIDE_AIR',updatedAt:new Date(now.getTime()-25*3_600_000),
      value:{catalog:{fetchedAt:new Date(now.getTime()-25*3_600_000).toISOString(),stations:[{stationName:'서울',latitude:37.5,longitude:127}]},observations:[],collectedAt:now.toISOString()}});
    vi.spyOn(AirKoreaAirQualityProvider.prototype,'getStationCatalog').mockRejectedValue(new DOMException('timeout','TimeoutError'));
    const provider=vi.spyOn(AirKoreaAirQualityProvider.prototype,'getProvinceMeasurements').mockImplementation(async province=>[
      {stationName:province,observedAt:now.toISOString(),pm10:20}]);
    expect((await collectNationwideAirQuality(env(),now))!.observations).toHaveLength(17);
    expect(provider).toHaveBeenCalledTimes(17);
  });
  it('3시간 지난 가까운 관측값보다 유효한 다른 관측소를 선택한다',()=>{
    const snapshot={catalog:{fetchedAt:now.toISOString(),stations:[
      {stationName:'A',latitude:37.5,longitude:127},{stationName:'B',latitude:37.6,longitude:127}]},collectedAt:now.toISOString(),observations:[
      {stationName:'A',observedAt:new Date(now.getTime()-3*3_600_000-1).toISOString(),pm10:20},
      {stationName:'B',observedAt:now.toISOString(),pm10:10}]};
    expect(nearestNationwideAirQuality(snapshot,37.5,127,now)!.stationName).toBe('B');
  });
});
describe('적설의 독립 가용성',()=>{
  it('기존 캐시에 응답 성공 여부가 없으면 누락 강수량을 정상 빈 응답으로 단정하지 않는다',()=>{
    const snapshot={snowfallMetricAvailable:false,stations:[
      {date:'2026-10-08',stationId:'A',latitude:37.5,longitude:127,minTemperature:18,maxTemperature:22}]};
    const day=dailyObservationsAtLocations(snapshot,[{latitude:37.5,longitude:127}],'2026-10-08','2026-10-08')[0][0];
    expect(day.observationAvailability!.precipitationAmount).toBe('UNAVAILABLE');
    expect(day.observationAvailability!.snowfallAmount).toBe('UNAVAILABLE');
  });
  it('적설 빈 응답은 NO_RECORD이며 기온·강수는 완비로 제공하고 다음 수집에서 빈 응답을 재요청하지 않는다',async()=>{
    const calls:string[]=[];const provider=new KmaDailyObservationProvider({serviceKey:'synthetic',fetcher:async input=>{
      const metric=new URL(String(input)).searchParams.get('obs')!;calls.push(metric);
      return new Response(metric==='sd_day_max'?'#END':`20261008,108,127,37.5,0,${{ta_min:18,ta_max:22,rn_day:0}[metric]}`);
    }});
    const snapshot=await provider.getNationwide('2026-10-08','2026-10-08');
    expect(snapshot.metricAvailability!['2026-10-08'].sd_day_max).toBe('NO_RECORD');
    const day=dailyObservationsAtLocations(snapshot,[{latitude:37.5,longitude:127}],'2026-10-08','2026-10-08')[0][0];
    expect(day.weatherDataComplete).toBe(true);expect(day.snowfallDataAvailable).toBe(false);
    expect(day.observationAvailability!.snowfallAmount).toBe('NO_RECORD');
    await provider.getNationwide('2026-10-08','2026-10-08',snapshot);expect(calls).toHaveLength(4);
  });
  it('적설 실패 시 UNAVAILABLE을 표시하고 정상 지표를 재요청하지 않는다',async()=>{
    const calls:string[]=[];let fail=true;
    const provider=new KmaDailyObservationProvider({serviceKey:'synthetic',fetcher:async input=>{
      const metric=new URL(String(input)).searchParams.get('obs')!;calls.push(metric);
      if(metric==='sd_day_max'&&fail)throw new DOMException('timeout','TimeoutError');
      return new Response(`20261008,108,127,37.5,0,${{ta_min:18,ta_max:22,rn_day:0,sd_day_max:0}[metric]}`);
    }});
    const snapshot=await provider.getNationwide('2026-10-08','2026-10-08');
    expect(snapshot.completedDates).toEqual(['2026-10-08']);expect(snapshot.settledDates).toEqual([]);
    expect(snapshot.metricAvailability!['2026-10-08'].sd_day_max).toBe('UNAVAILABLE');
    fail=false;const final=await provider.getNationwide('2026-10-08','2026-10-08',snapshot);
    expect(calls.slice(4)).toEqual(['sd_day_max']);expect(final.metricAvailability!['2026-10-08'].sd_day_max).toBe('AVAILABLE');
  });
  it('먼 관측소의 양수 적설을 눈 기록 없는 인근 기온 관측소에 확대하지 않는다',()=>{
    const snapshot={snowfallMetricAvailable:true,stations:[
      {date:'2026-10-08',stationId:'A',latitude:37.5,longitude:127,minTemperature:18,maxTemperature:22,precipitationAmount:0},
      {date:'2026-10-08',stationId:'B',latitude:38.5,longitude:129,snowfallAmount:15}]};
    const day=dailyObservationsAtLocations(snapshot,[{latitude:37.5,longitude:127}],'2026-10-08','2026-10-08')[0][0];
    expect(day.snowfallDataAvailable).toBe(false);expect(day.skyCondition).toBe('하늘 상태 관측 없음');
  });
});
