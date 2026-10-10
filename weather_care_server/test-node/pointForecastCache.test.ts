import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { asD1Database, runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { collectPointForecasts, readPointForecast, pointForecastFetch } from '../src/services/pointForecastCache';
import { getApiHubUsage, reservePointForecastRequest } from '../src/database/apiUsageRepository';
import { getCollectedCache, saveCollectedCache } from '../src/database/collectedWeatherRepository';
import { saveGridObservationSnapshot } from '../src/database/gridObservationRepository';
import { observationSnapshot } from './gridObservationFixture';
import { buildForecastFromItems, KmaWeatherProvider, type KmaForecastItem } from '../src/providers/weather/kmaWeatherProvider';
import { readNationwideRegion } from '../src/services/nationwideWeatherCache';
import { missingLandForecastGrids, saveNationwideForecastField } from '../src/database/nationwideForecastRepository';
import { NATIONAL_FORECAST_REQUIRED_VARIABLES } from '../src/providers/weather/kmaNationwideForecastProvider';

let database: SqliteD1Database;
const now = new Date('2026-10-09T11:54:00+09:00');
const base = { baseDate:'20261009',baseTime:'1100' };
const grid = { nx:48,ny:29 };
function items(values = {TMP:'24',REH:'60',WSD:'2',SKY:'1',PTY:'0'}): KmaForecastItem[] {
  return Object.entries(values).map(([category,fcstValue])=>({...base,...grid,category,fcstValue,fcstDate:'20261009',fcstTime:'1200'}));
}
function forecast() { return buildForecastFromItems(items(),now,base); }
function payload(rows: KmaForecastItem[], totalCount = rows.length, numOfRows = rows.length) {
  return new Response(JSON.stringify({response:{header:{resultCode:'00',resultMsg:'NORMAL_SERVICE'},body:{totalCount,numOfRows,items:{item:rows}}}}));
}
beforeEach(async () => {
  database=new SqliteD1Database(':memory:');runSqliteMigrations(database);
  vi.useFakeTimers({toFake:['Date']});vi.setSystemTime(now);
  vi.spyOn(console,'log').mockImplementation(()=>{});vi.spyOn(console,'error').mockImplementation(()=>{});
  const db=asD1Database(database);
  await saveCollectedCache(db,{key:'COLLECTED_NATIONWIDE_LAND_GRIDS',type:'COLLECTED_NATIONWIDE_LAND_GRIDS',value:{grids:[grid]},updatedAt:now});
  const raw=observationSnapshot('2026-10-09T11:40:00+09:00');raw.fields.T1H!.values[(grid.ny-1)*149+grid.nx-1]=-99;
  await saveGridObservationSnapshot(db,raw,now);
});
afterEach(()=>{vi.useRealTimers();vi.restoreAllMocks();database.close();});
describe('결측 격자 공공데이터 예보 캐시',()=>{
  it('설치·대표 지역 참고가 없어도 육지와 겹치는 격자를 수집하고 동시·반복 요청은 한 번만 호출한다',async()=>{
    const db=asD1Database(database);
    const provider=vi.spyOn(KmaWeatherProvider.prototype,'getForecastByRegion').mockResolvedValue(forecast());
    await Promise.all([collectPointForecasts(db,'synthetic',now),collectPointForecasts(db,'synthetic',now)]);
    await collectPointForecasts(db,'synthetic',now);
    expect(provider).toHaveBeenCalledExactlyOnceWith(grid.nx,grid.ny);
    expect((await readPointForecast(db,grid.nx,grid.ny,now))?.current).toMatchObject({temperature:24,provider:'KMA_DATA_GO_KR',sourceLocation:{...grid,locationMatch:'EXACT_GRID'}});
    const fetcher=vi.spyOn(globalThis,'fetch');
    expect((await readNationwideRegion(db,grid,now))?.value.forecast.current.temperature).toBe(24);
    await saveCollectedCache(db,{key:`COLLECTED_REGION_${grid.nx}_${grid.ny}`,type:'COLLECTED_REGION',
      value:{forecast:{...forecast(),current:{...forecast().current,temperature:-50}}},updatedAt:now});
    expect((await readNationwideRegion(db,grid,now))?.native).toBe(true);
    expect(fetcher).not.toHaveBeenCalled();
  });
  it('시간초과 재시도는 회차·격자별 3회로 제한하고 기존 캐시를 삭제하지 않는다',async()=>{
    const db=asD1Database(database), old={...forecast(),baseTime:'0800'};
    await saveCollectedCache(db,{key:`COLLECTED_POINT_FORECAST_${grid.nx}_${grid.ny}`,type:'COLLECTED_POINT_FORECAST',value:{...grid,forecast:old},updatedAt:now});
    const provider=vi.spyOn(KmaWeatherProvider.prototype,'getForecastByRegion').mockRejectedValue(new DOMException('timeout','TimeoutError'));
    for(let i=0;i<4;i++)await collectPointForecasts(db,'synthetic',new Date(now.getTime()+i*10*60_000));
    expect(provider).toHaveBeenCalledTimes(3);
    expect((await readPointForecast(db,grid.nx,grid.ny,now))?.current.temperature).toBe(24);
  });
  it('잘못된 격자·6시간 초과·미발표 회차 캐시는 채택하지 않는다',async()=>{
    const db=asD1Database(database), key=`COLLECTED_POINT_FORECAST_${grid.nx}_${grid.ny}`;
    for(const value of [{...grid,nx:99,forecast:forecast()},{...grid,forecast:{...forecast(),baseTime:'1400'}}]) {
      await saveCollectedCache(db,{key,type:'COLLECTED_POINT_FORECAST',value,updatedAt:now});
      expect(await readPointForecast(db,grid.nx,grid.ny,now)).toBeUndefined();
    }
    await saveCollectedCache(db,{key,type:'COLLECTED_POINT_FORECAST',value:{...grid,forecast:forecast()},updatedAt:new Date(now.getTime()-6*3_600_000-1)});
    expect(await readPointForecast(db,grid.nx,grid.ny,now)).toBeUndefined();
  });
  it('공공데이터 호출 예약은 원자적으로 9,000회에서 멈추고 APIHub 예산과 분리된다',async()=>{
    const db=asD1Database(database);
    const reservations=await Promise.all([reservePointForecastRequest(db,1,now),reservePointForecastRequest(db,1,now)]);
    expect(reservations.filter(Boolean)).toHaveLength(1);
    database.sqlite.prepare("UPDATE api_usage_daily SET request_count=8999 WHERE provider='DATA_GO_POINT_FORECAST'").run();
    const fetcher=vi.spyOn(globalThis,'fetch').mockResolvedValue(new Response('abc'));
    await pointForecastFetch(db)('https://apis.data.go.kr/fixture');
    await expect(pointForecastFetch(db)('https://apis.data.go.kr/fixture')).rejects.toThrow('BUDGET_EXHAUSTED');
    expect(fetcher).toHaveBeenCalledOnce();
    expect(await getApiHubUsage(db,now)).toEqual({requestCount:0,responseBytes:0});
    expect(database.sqlite.prepare("SELECT request_count AS calls,response_bytes AS bytes FROM api_usage_daily WHERE provider='DATA_GO_POINT_FORECAST'").get()).toEqual({calls:9000,bytes:3});
  });
  it('파일이 없는 상태는 공간 결측으로 분류하지 않고 완성 원본의 잘못된 셀만 판정한다',async()=>{
    const db=asD1Database(database);
    expect((await missingLandForecastGrids(db,[grid],now)).sourceAvailable).toBe(false);
    for(const variable of NATIONAL_FORECAST_REQUIRED_VARIABLES){
      const values=Array(37697).fill(variable==='TMP'?24:variable==='REH'?60:variable==='WSD'?2:variable==='SKY'?1:0);
      if(variable==='TMP')values[(grid.ny-1)*149+grid.nx-1]=-99;
      await saveNationwideForecastField(db,{issue:'2026100911',valid:'2026100912',variable},{width:149,height:253,values},now);
    }
    const missing=await missingLandForecastGrids(db,[grid,{nx:60,ny:121}],now);
    expect(missing.sourceAvailable).toBe(true);expect([...missing]).toEqual([`${grid.nx}:${grid.ny}`]);
  });
  it('수집 대상 원본 경계 버전이 맞지 않으면 불완전한 대표 목록으로 대체하지 않는다',async()=>{
    const db=asD1Database(database);
    database.sqlite.prepare("INSERT INTO administrative_boundary_dataset VALUES(1,'new','{}',?)").run(now.toISOString());
    const fetcher=vi.spyOn(globalThis,'fetch');
    await expect(collectPointForecasts(db,'synthetic',now)).rejects.toThrow('LAND_GRIDS_NOT_READY');
    expect(fetcher).not.toHaveBeenCalled();
  });
});
describe('공공데이터 예보 전체 응답 파서',()=>{
  it('서버가 페이지 크기를 줄여도 전체 행을 읽고 반복 페이지를 거절한다',async()=>{
    const rows=items(), urls:URL[]=[];
    const fetcher=vi.fn<typeof fetch>(async(input)=>{
      const url=new URL(String(input));urls.push(url);
      const page=Number(url.searchParams.get('pageNo'));
      return payload(rows.slice((page-1)*2,page*2),rows.length,2);
    });
    const provider=new KmaWeatherProvider({serviceKey:'synthetic',now:()=>now,fetcher});
    expect((await provider.getLatestForecastByRegion(grid.nx,grid.ny)).current).toMatchObject({temperature:24,humidity:60,windSpeed:2});
    expect(urls.map(url=>url.searchParams.get('numOfRows'))).toEqual(['6000','2','2']);
    const repeating=new KmaWeatherProvider({serviceKey:'synthetic',now:()=>now,fetcher:async()=>payload(rows.slice(0,2),5,2)});
    await expect(repeating.getLatestForecastByRegion(grid.nx,grid.ny)).rejects.toThrow('repeats rows');
  });
  it('다른 격자의 응답을 캐시하지 않고 연장 구간 풍속 코드를 실제 m/s로 계산하지 않는다',async()=>{
    const wrong=new KmaWeatherProvider({serviceKey:'synthetic',now:()=>now,fetcher:async()=>payload(items().map(item=>({...item,nx:99})))});
    await expect(wrong.getLatestForecastByRegion(grid.nx,grid.ny)).rejects.toThrow('grid or issue');
    const extended=items().map(item=>({...item,fcstDate:'20261013',fcstTime:'0300'}));
    const provider=new KmaWeatherProvider({serviceKey:'synthetic',now:()=>now,fetcher:async()=>payload([...items(),...extended])});
    const result=await provider.getLatestForecastByRegion(grid.nx,grid.ny);
    expect(result.daily.find(day=>day.date==='20261013')?.maximumWindSpeed).toBeUndefined();
  });
});
