import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { SqliteD1Database, runSqliteMigrations, asD1Database } from '../src/node/sqliteD1';
import { KmaSnowObservationProvider, parseSnowSnapshot } from '../src/providers/weather/kmaSnowObservationProvider';
import { collectCurrentSnow, currentSnowFields, CURRENT_SNOW_CACHE_KEY } from '../src/services/currentSnowCache';
import { getCollectedCache, saveCollectedCache } from '../src/database/collectedWeatherRepository';

const now = new Date('2026-10-10T04:30:00Z');
const row = (id: number, value: number, time='202610101300', lon=127, lat=37) =>
  `${time},${id},서울 관측소,${lon},${lat},000-----,${value},=`;

describe('현재 총 적설 정규 수집', () => {
  let directory: string, database: SqliteD1Database, db: D1Database;
  beforeEach(() => {
    vi.useFakeTimers(); vi.setSystemTime(now);
    directory=mkdtempSync(join(tmpdir(),'weather-care-snow-'));
    database=new SqliteD1Database(join(directory,'weather.sqlite'));
    runSqliteMigrations(database); db=asD1Database(database);
    vi.spyOn(console,'log').mockImplementation(()=>{});
    vi.spyOn(console,'error').mockImplementation(()=>{});
  });
  afterEach(() => { database.close(); rmSync(directory,{recursive:true,force:true}); vi.restoreAllMocks(); vi.useRealTimers(); });

  it('한글·실제 관측시각·명시적 0·양수를 읽고 음수 결측을 0으로 만들지 않는다', () => {
    const snapshot=parseSnowSnapshot([row(1,0),row(2,12.4),row(3,-99.7)].join('\n'),'202610101320',now);
    expect(snapshot.stations.map(s=>s.depthCm)).toEqual([0,12.4,undefined]);
    expect(snapshot.stations[0]).toMatchObject({stationName:'서울 관측소',observedAt:'2026-10-10T13:00:00+09:00'});
  });

  it.each([row(1,0)+ '\n'+row(1,1),row(1,0).replace(',=',',oops'),row(1,1,'202602301300'),row(1,1,'202610101400'),'<html>error</html>'])
    ('중복·변형·미래·잘못된 날짜·HTML을 정상 눈 자료로 저장하지 않는다', text => {
      expect(()=>parseSnowSnapshot(text,'202610101320',now)).toThrow();
    });

  it('원본 좌표 오류가 있는 지점만 제외하고 다른 정상 지점은 보존한다', () => {
    const snapshot=parseSnowSnapshot([row(536,0,'202610101300',27.97242,37.4876),row(1,0)].join('\n'),'202610101320',now);
    expect(snapshot.invalidCoordinateRows).toBe(1);
    expect(snapshot.stations.map(s=>s.stationId)).toEqual(['1']);
    expect(()=>parseSnowSnapshot(row(536,0,'202610101300',27.97242),'202610101320',now)).toThrow('no usable data');
  });

  it('sd=tot/snow=0을 별도 예산으로 수집하며 같은 10분 안의 중복 호출을 막는다', async () => {
    const fetcher=vi.spyOn(globalThis,'fetch').mockResolvedValue(new Response(row(1,0)));
    await Promise.all([collectCurrentSnow(db,'test-key',now),collectCurrentSnow(db,'test-key',now)]);
    expect(fetcher).toHaveBeenCalledTimes(1);
    const url=new URL(String(fetcher.mock.calls[0][0]));
    expect(url.pathname).toContain('kma_snow1.php');
    expect(Object.fromEntries(url.searchParams)).toMatchObject({sd:'tot',snow:'0',tm:'202610101320'});
    expect(await currentSnowFields(db,{nx:60,ny:121,coordinates:{latitude:37,longitude:127}},now))
      .toMatchObject({snowDepthStatus:'AVAILABLE',snowDepthCm:0,snowDepthObservedAt:'2026-10-10T13:00:00+09:00',snowDepthStationDistanceKm:0});
    expect(database.sqlite.prepare("select request_count from api_usage_daily where provider='SNOW_TOTAL'").get())
      .toMatchObject({request_count:1});
  });

  it('실제 EUC-KR 한글 응답을 손상 없이 파싱한다', async () => {
    const prefix=new TextEncoder().encode('202610101300,1,');
    const suffix=new TextEncoder().encode(',127,37,000-----,0,=');
    const body=new Uint8Array([...prefix,0xb0,0xa1,...suffix]); // EUC-KR '가'
    const provider=new KmaSnowObservationProvider('test-key',async()=>new Response(body));
    expect((await provider.getSnapshot(now)).stations[0].stationName).toBe('가');
  });

  it('가장 가까운 결측·오래된 관측소를 제외하고 실제 유효 인근 값을 사용한다', async () => {
    const snapshot=parseSnowSnapshot([row(1,-99.7),row(2,2,'202610101000'),row(3,4,'202610101300',127.01)].join('\n'),'202610101320',now);
    await saveCollectedCache(db,{key:CURRENT_SNOW_CACHE_KEY,type:CURRENT_SNOW_CACHE_KEY,value:snapshot,updatedAt:now});
    const fields=await currentSnowFields(db,{nx:60,ny:121,coordinates:{latitude:37,longitude:127}},now);
    expect(fields).toMatchObject({snowDepthCm:4,snowDepthStationId:'3'});
    expect(fields.snowDepthStationDistanceKm).toBeGreaterThan(0);
    expect(await currentSnowFields(db,{nx:60,ny:121},new Date(now.getTime()+4*3_600_000)))
      .toEqual({snowDepthStatus:'UNAVAILABLE',snowDepthProvider:'KMA_APIHUB_SNOW_TOTAL'});
  });

  it('수집 실패·모두 결측이면 기존 정상 캐시를 유지하고 백오프 뒤 재시도한다', async () => {
    const fetcher=vi.spyOn(globalThis,'fetch').mockResolvedValueOnce(new Response(row(1,1)))
      .mockResolvedValueOnce(new Response(row(1,-99.7))).mockResolvedValueOnce(new Response(row(1,2)));
    await collectCurrentSnow(db,'test-key',now);
    const later=new Date(now.getTime()+10*60_000); vi.setSystemTime(later);
    await collectCurrentSnow(db,'test-key',later);
    const cached=await getCollectedCache<{stations:{depthCm:number}[]}>(db,CURRENT_SNOW_CACHE_KEY);
    expect(cached?.value.stations[0].depthCm).toBe(1);
    await collectCurrentSnow(db,'test-key',new Date(later.getTime()+60_000));
    expect(fetcher).toHaveBeenCalledTimes(2);
    const retry=new Date(later.getTime()+2*60_000); vi.setSystemTime(retry);
    await collectCurrentSnow(db,'test-key',retry);
    expect((await getCollectedCache<{stations:{depthCm:number}[]}>(db,CURRENT_SNOW_CACHE_KEY))?.value.stations[0].depthCm).toBe(2);
  });

  it('403 이후 자동 재요청을 멈추고 결측은 미확보로 제공한다', async () => {
    const fetcher=vi.spyOn(globalThis,'fetch').mockResolvedValue(new Response('',{status:403}));
    await collectCurrentSnow(db,'test-key',now);
    await collectCurrentSnow(db,'test-key',new Date(now.getTime()+3_600_000));
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect((await currentSnowFields(db,{nx:60,ny:121},now)).snowDepthStatus).toBe('UNAVAILABLE');
  });
});
