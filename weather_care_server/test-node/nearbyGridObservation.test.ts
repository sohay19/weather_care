import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { asD1Database, runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { getGridObservationSnapshot, readCurrentGridObservation, saveGridObservationSnapshot } from '../src/database/gridObservationRepository';
import { GRID_OBSERVATION_VARIABLES, type GridObservationSnapshot } from '../src/providers/weather/kmaGridObservationProvider';
import { kmaGridCoordinates } from '../src/regions/kmaGridCoordinates';
import { createComparisonRouter } from '../src/api/comparison';
import weatherRouter from '../src/api/weather';

let database: SqliteD1Database;
const now = new Date('2026-10-09T11:54:00+09:00');
const at = '2026-10-09T11:40:00+09:00';
beforeEach(() => { database = new SqliteD1Database(':memory:'); runSqliteMigrations(database); });
afterEach(() => { vi.useRealTimers(); vi.restoreAllMocks(); database.close(); });
function snapshot(clock = at): GridObservationSnapshot {
  return { observedAt: clock, fields: Object.fromEntries(GRID_OBSERVATION_VARIABLES.map((field) =>
    [field, { width:149, height:253, values:Array(37697).fill(-99) }])) };
}
function setCell(raw: GridObservationSnapshot, nx: number, ny: number, temperature = 20) {
  for (const [field,value] of Object.entries({ T1H:temperature, REH:60, WSD:2, VEC:180, PTY:0, RN1:0 })) {
    raw.fields[field]!.values[(ny-1)*149+nx-1] = value;
  }
}
describe('GPS 인근 실황 보충', () => {
  it('같은 요청 격자라도 실제 GPS에서 가장 가까운 정상 원본을 선택하고 원본 결측을 보존한다', async () => {
    const db=asD1Database(database), raw=snapshot();
    setCell(raw,59,121,19);setCell(raw,61,121,21);
    await saveGridObservationSnapshot(db,raw,now);
    const west=kmaGridCoordinates(59,121)!, east=kmaGridCoordinates(61,121)!;
    const a=await readCurrentGridObservation(db,60,121,now,west);
    const b=await readCurrentGridObservation(db,60,121,now,east);
    expect(a?.value).toMatchObject({temperature:19,sourceLocation:{nx:59,ny:121,locationMatch:'NEAREST_GRID',distanceBasis:'GPS',distanceKm:0}});
    expect(b?.value.temperature).toBe(21);
    expect(b?.value.qualityFlags).toContain('NEARBY_GRID_OBSERVATION');
    expect((await getGridObservationSnapshot(db,at))?.value).toEqual(raw);
  });
  it('원래 격자가 정상이면 더 가까운 다른 GPS 후보가 있어도 정확한 격자를 우선한다', async () => {
    const db=asD1Database(database), raw=snapshot();setCell(raw,60,121,24);setCell(raw,61,121,30);
    await saveGridObservationSnapshot(db,raw,now);
    const value=(await readCurrentGridObservation(db,60,121,now,kmaGridCoordinates(61,121)))?.value;
    expect(value).toMatchObject({temperature:24,sourceLocation:{locationMatch:'EXACT_GRID'}});
    expect(value?.qualityFlags ?? []).not.toContain('NEARBY_GRID_OBSERVATION');
  });
  it('가장 가까운 후보가 강수 결측이면 6항목이 정상인 다음 후보를 쓰고 먼 출처도 거리 표시로 제공한다', async () => {
    const db=asD1Database(database), raw=snapshot();setCell(raw,61,121,21);setCell(raw,70,121,25);
    raw.fields.PTY!.values[120*149+60]=-99;
    await saveGridObservationSnapshot(db,raw,now);
    const value=(await readCurrentGridObservation(db,60,121,now))?.value;
    expect(value).toMatchObject({temperature:25,sourceLocation:{nx:70,distanceBasis:'GRID_CENTER'}});
    expect(value?.sourceLocation?.distanceKm).toBeGreaterThan(20);
    expect(value?.qualityFlags).toContain('DISTANT_GRID_OBSERVATION');
  });
  it('30분 초과 자료와 현재 슬롯을 사용하지 않고 정상 인근값이 없으면 unavailable로 둔다', async () => {
    const db=asD1Database(database), old=snapshot('2026-10-09T11:20:00+09:00'), future=snapshot('2026-10-09T11:50:00+09:00');
    setCell(old,61,121);setCell(future,61,121);
    await saveGridObservationSnapshot(db,old,now);await saveGridObservationSnapshot(db,future,now);
    expect(await readCurrentGridObservation(db,60,121,now)).toBeNull();
    await saveGridObservationSnapshot(db,snapshot(),now);
    expect(await readCurrentGridObservation(db,60,121,now)).toBeNull();
  });
  it('같은 시각의 원본을 보충 저장하면 캐시 색인도 새 후보를 반영한다', async () => {
    const db=asD1Database(database), raw=snapshot();setCell(raw,70,121,25);
    await saveGridObservationSnapshot(db,raw,now);await readCurrentGridObservation(db,60,121,now);
    setCell(raw,61,121,21);await saveGridObservationSnapshot(db,raw,now);
    expect((await readCurrentGridObservation(db,60,121,now))?.value.temperature).toBe(21);
  });
  it('강수형태 파일이 빠진 회차도 정상 기온·습도·풍속을 제공하고 해당 결측만 표시한다', async () => {
    const db=asD1Database(database), raw=snapshot();setCell(raw,61,121,24);delete raw.fields.PTY;
    await saveGridObservationSnapshot(db,raw,now);
    const value=(await readCurrentGridObservation(db,60,121,now))?.value;
    expect(value).toMatchObject({temperature:24,humidity:60,windSpeed:2,windDirection:180,precipitationAmount:0,sourceLocation:{locationMatch:'NEAREST_GRID'}});
    expect(value?.precipitationTypeCode).toBeUndefined();
    expect(value?.qualityFlags).toContain('PRECIPITATION_TYPE_UNAVAILABLE');
  });
  it('어제 비교는 오늘 선택한 출처 격자를 고정하며 더 가까운 어제 후보로 바꾸지 않는다', async () => {
    const db=asD1Database(database), today=snapshot(), yesterday=snapshot('2026-10-08T11:40:00+09:00');
    setCell(today,61,121,24);setCell(yesterday,61,121,20);setCell(yesterday,60,121,99);
    await saveGridObservationSnapshot(db,today,now);await saveGridObservationSnapshot(db,yesterday,now);
    const router=createComparisonRouter({now:()=>now});
    const value=await (await router.request('/yesterday?nx=60&ny=121',{}, {DB:db})).json();
    expect(value).toMatchObject({comparisonAvailable:true,current:{temperature:24},comparison:{temperature:20},basis:{gridX:60,gridY:121,sourceLocation:{nx:61,ny:121,locationMatch:'NEAREST_GRID'}}});
    yesterday.fields.T1H!.values[120*149+60]=-99;await saveGridObservationSnapshot(db,yesterday,now);
    expect(await (await router.request('/yesterday?nx=60&ny=121',{}, {DB:db})).json()).toMatchObject({comparisonAvailable:false,reason:'HISTORICAL_GRID_OBSERVATION_UNAVAILABLE'});
  });
  it('메인·오늘 API에 출처를 전달하고 캐시 조회 시 외부 호출을 하지 않는다', async () => {
    vi.useFakeTimers({toFake:['Date']});vi.setSystemTime(now);
    const db=asD1Database(database), raw=snapshot();setCell(raw,61,121,24);await saveGridObservationSnapshot(db,raw,now);
    const fetcher=vi.spyOn(globalThis,'fetch').mockRejectedValue(new Error('NO_EXTERNAL_CALL'));
    const gps=kmaGridCoordinates(61,121)!;
    for (const route of ['main','today']) {
      const response=await weatherRouter.request(`/${route}?nx=60&ny=121&latitude=${gps.latitude}&longitude=${gps.longitude}`,{}, {DB:db});
      expect(response.status).toBe(200);
      expect(await response.json()).toMatchObject({current:{temperature:24,sourceLocation:{nx:61,locationMatch:'NEAREST_GRID',distanceKm:0}}});
    }
    expect(fetcher).not.toHaveBeenCalled();
  });
});
