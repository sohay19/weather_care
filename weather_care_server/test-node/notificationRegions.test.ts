import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { loadCollectionTargets } from '../src/collection/collectionTargets';
import { collectWarnings } from '../src/collection/weatherCollectionJob';
import { Hono } from 'hono';
import installations from '../src/api/installations';
import settings from '../src/api/notificationSettings';
import { asD1Database, runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { secretHash, deleteInstallationData } from '../src/security/installationAccess';
import { catalogNotificationRegion, expandNotificationRegions, notificationRegionsSchema, regionStillEnabled, saveNotificationRegions } from '../src/notification/notificationRegions';
import { runRecommendationNotificationJob } from '../src/notification/notificationScheduler';
import { KMA_ADMINISTRATIVE_AREAS } from '../src/regions/kmaAdministrativeAreas';
import { sendBatch, type FcmPayload, type FcmSendResult } from '../src/notification/fcmClient';
import type { ServerEnv } from '../src/types';
import { saveCollectedCache, collectedCacheKey } from '../src/database/collectedWeatherRepository';
import type { OfficialWeatherWarning } from '../src/providers/warnings/kmaWarningProvider';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import { adjacentMarineWarningZoneIds } from '../src/regions/marineWarningAdjacency';
import { selectableMarineWarningZones } from '../src/regions/kmaMarineWarningZones';
import { kmaGridFromCoordinates } from '../src/regions/kmaGridFromCoordinates';

let sqlite: SqliteD1Database;
let env: ServerEnv;
let hash: string;
const secret = 'a'.repeat(64);
const headers = {Authorization:`Bearer ${secret}`, 'Content-Type':'application/json'};
const now = new Date('2026-09-02T07:00:00+09:00');
const keys = KMA_ADMINISTRATIVE_AREAS.filter(r => r[1].includes('구로구 구로') && r[1].endsWith('동'))
  .map(r => `${r[0]}|${r[1].split(' ').at(-1)}|${r[2]}|${r[3]}`);
const first = keys[0], second = keys[1];
const coastalKey = (name: string) => {
  const area = KMA_ADMINISTRATIVE_AREAS.find(area => area[1] === name)!;
  return `${area[0]}|${name.split(' ').at(-1)}|${area[2]}|${area[3]}`;
};
const busan = coastalKey('부산광역시 해운대구 우제1동');
const ulsan = coastalKey('울산광역시 동구 방어동');
it('allows 49 saved regions alongside GPS and LEGACY', () => {
  const saved = Array.from({length: 49}, (_, index) => ({key: `saved-${index}`, enabled: true}));
  const special = [{key: 'GPS', enabled: true}, {key: 'LEGACY', enabled: true}];
  expect(notificationRegionsSchema.safeParse({regions: [...saved, ...special]}).success).toBe(true);
  expect(notificationRegionsSchema.safeParse({regions: [...saved, {key: 'extra', enabled: true}]}).success).toBe(false);
});
const router = new Hono<{Bindings:ServerEnv}>().route('/installations', installations).route('/settings',settings);
const success = (sent:FcmPayload[]) => async (_env:ServerEnv, payloads:FcmPayload[]):Promise<FcmSendResult[]> => {
  sent.push(...payloads); return payloads.map(p => ({token:p.token,notificationKey:p.notificationKey,success:true,unregistered:false,status:200}));
};
function forecast() {
  const hourly = [7,8,9].map(hour => ({observedAt:`2026-09-02T0${hour}:00:00+09:00`,
    forecastAt:`2026-09-02T0${hour}:00:00+09:00`,temperature:24,humidity:75,windSpeed:2,
    precipitationType:'RAIN' as const, precipitationProbability:80,precipitationAmount:3}));
  return {current:hourly[0],hourly,daily:[],baseDate:'20260902',baseTime:'0500',dataSource:'기상청 단기예보'};
}
const dependencies = {now,forecastLoader:async () => forecast(),warningLoader:async () => [],
  warningRegionResolver:async () => ({regionId:'L1010100',regionName:'서울서남권',provider:'기상청'}),
  precipitationLoader:async () => ({state:'DRY' as const,observedAt:now.toISOString(),provider:'test'}),
  roadIceLoader:async () => undefined,roadControlLoader:async () => undefined};
async function save(regions = [{key:first,enabled:true},{key:second,enabled:true}]) {
  return router.request('/installations/device/notification-regions',{method:'PUT',headers,body:JSON.stringify({regions})},env);
}
async function job(sent:FcmPayload[], overrides = {}) {
  await runRecommendationNotificationJob(env,{...dependencies,sender:success(sent),...overrides});
}
beforeEach(async () => {
  sqlite = new SqliteD1Database(':memory:'); runSqliteMigrations(sqlite);
  env = {DB:asD1Database(sqlite)} as ServerEnv; hash = await secretHash(secret);
  sqlite.sqlite.prepare('INSERT INTO installation_credentials VALUES(?,?,?)').run('device',hash,now.toISOString());
  sqlite.sqlite.prepare(`INSERT INTO installations(installation_id,fcm_token,nx,ny,region_topic,location_mode,
    minimum_age_confirmed_at,age_policy_version,created_at,updated_at) VALUES('device','token',60,127,'test','GPS',?,1,?,?)`)
    .run(now.toISOString(),now.toISOString(),now.toISOString());
  sqlite.sqlite.prepare(`INSERT INTO notification_settings(installation_id,created_at,updated_at) VALUES('device',?,?)`)
    .run(now.toISOString(),now.toISOString());
});
afterEach(() => sqlite.close());

describe('구역별 알림 구독과 기존 앱 호환', () => {
  it('앱의 모든 카탈로그 키를 동·격자 단위로 확인한다', () => {
    const data = JSON.parse(readFileSync('../weather_care_app/assets/data/kma_regions.json','utf8'));
    const missing = data.regions.filter((r:unknown[]) => !catalogNotificationRegion(`${r[0]}|${r[2]}|${r[3]}|${r[4]}`));
    expect(missing).toEqual([]);
  });
  it('인증 없는 요청·중복·위조 구역·형식 오류를 거부한다', async () => {
    expect((await router.request('/installations/device/notification-regions',{method:'PUT',body:'{}'},env)).status).toBe(401);
    for (const regions of [[{key:'forged',enabled:true}], [{key:first,enabled:true},{key:first,enabled:false}], [{key:first,enabled:'yes'}]]) {
      expect((await save(regions as never)).status).toBe(400);
    }
    expect((await router.request('/installations/device/notification-regions',{method:'PUT',headers,body:'{'},env)).status).toBe(400);
  });
  it('구독 없는 기존 앱에는 기존 키로 한 지역만 보낸다', async () => {
    const sent:FcmPayload[]=[]; await job(sent); await job(sent);
    expect(sent.filter(p => p.notificationKey==='MORNING_BRIEF')).toHaveLength(1);
    expect(sent[0].notificationRegionKey).toBeUndefined();
  });
  it('ON인 동마다 발송하고 같은 날 반복 발송하지 않는다', async () => {
    expect((await save()).status).toBe(200);
    const firstName = catalogNotificationRegion(first)!.name;
    const secondName = catalogNotificationRegion(second)!.name;
    const baseForecast = forecast();
    const dailyWeather = {skyCondition:'CLOUDY',precipitationProbability:80,precipitationAmount:3};
    const forecastLoader = async (_env: ServerEnv, _nx: number, _ny: number,
      _coordinates?: { latitude: number; longitude: number }, regionName?: string): Promise<WeatherForecast> => ({
      ...baseForecast,
      daily: [
        {...dailyWeather,date:'20260901',minTemperature:-12,maxTemperature:-5},
        {...dailyWeather,date:'20260902',minTemperature:regionName===firstName ? -2.34 : 8,
          maxTemperature:regionName===firstName ? 17 : 18.64},
      ],
    });
    const sent:FcmPayload[]=[];
    await job(sent, {forecastLoader});
    await job(sent, {forecastLoader});
    const briefs=sent.filter(p => p.notificationKey==='MORNING_BRIEF');
    expect(briefs).toHaveLength(2);
    expect(new Set(briefs.map(p=>p.notificationRegionId)).size).toBe(2);
    expect(briefs.map(p=>p.notificationRegionKey)).toEqual([first,second]);
    expect(briefs.map(p=>p.title)).toEqual([
      `[${firstName}] 최저 -2.3 °C · 최고 17.0 °C`,
      `[${secondName}] 최저 8.0 °C · 최고 18.6 °C`,
    ]);
    expect(sqlite.sqlite.prepare('SELECT COUNT(*) AS n FROM notification_history').get()).toEqual({n:2});
  });
  it('업데이트 직전 현재 지역의 발송 이력과 강수 상태를 이어 받는다', async () => {
    const sent:FcmPayload[]=[];await job(sent);
    sqlite.sqlite.exec('UPDATE installations SET current_rain_state=1');
    await save([{key:'GPS',enabled:true}]);
    expect(sqlite.sqlite.prepare('SELECT SUM(current_rain_state) AS n FROM notification_region_state').get()).toEqual({n:1});
    await job(sent);
    expect(sent.filter(p=>p.notificationKey==='MORNING_BRIEF')).toHaveLength(1);
  });
  it('OFF인 동과 전체 OFF에는 발송하지 않는다', async () => {
    await save([{key:first,enabled:true},{key:second,enabled:false}]);
    const sent:FcmPayload[]=[]; await job(sent); expect(sent).toHaveLength(1);
    sqlite.sqlite.exec('DELETE FROM notification_history; UPDATE notification_settings SET notification_enabled=0');
    await job(sent); expect(sent).toHaveLength(1);
    await save([]); sqlite.sqlite.exec('UPDATE notification_settings SET notification_enabled=1');
    await job(sent); expect(sent).toHaveLength(1); // 빈 구독도 구버전 경로로 되돌아가지 않는다.
  });
  it('발송 직전 구역 OFF·전체 OFF·삭제를 다시 확인한다', async () => {
    for (const change of ['region','global','delete']) {
      await save([{key:first,enabled:true}]);
      const sent:FcmPayload[]=[];
      await job(sent,{forecastLoader:async()=>{
        if(change==='region') await save([{key:first,enabled:false}]);
        if(change==='global') sqlite.sqlite.exec('UPDATE notification_settings SET notification_enabled=0');
        if(change==='delete') await deleteInstallationData(env.DB,'device',hash);
        return forecast();
      }});
      expect(sent).toHaveLength(0);
      if(change!=='delete') sqlite.sqlite.exec('UPDATE notification_settings SET notification_enabled=1');
    }
  });
  it('기존 두 설정 API의 부분·전체 저장이 구역 구독과 출퇴근 시간을 보존한다', async () => {
    await save();
    const before=sqlite.sqlite.prepare('SELECT * FROM notification_regions ORDER BY region_key').all();
    for(const path of ['/settings/device','/installations/device/notification-settings']) {
      expect((await router.request(path,{method:'PUT',headers,body:JSON.stringify({notificationEnabled:true,notificationTime:'08:00'})},env)).status).toBe(200);
      expect(sqlite.sqlite.prepare('SELECT * FROM notification_regions ORDER BY region_key').all()).toEqual(before);
    }
  });
  it('지역별 현재 강수 상태를 분리하고 실패 시 수신 상태로 기록하지 않는다', async () => {
    await save(); const sent:FcmPayload[]=[];
    const rain={state:'RAIN',observedAt:now.toISOString(),provider:'test'};
    await job(sent,{precipitationLoader:async()=>rain});
    await job(sent,{precipitationLoader:async()=>rain});
    expect(sent.filter(p=>p.notificationKey==='CURRENT_RAIN')).toHaveLength(2);
    expect(sqlite.sqlite.prepare('SELECT SUM(current_rain_state) AS n FROM notification_region_state').get()).toEqual({n:2});
    expect(sqlite.sqlite.prepare('SELECT current_rain_state AS n FROM installations').get()).toEqual({n:0});
  });
  it('특보 발효·변경·해제와 도로 상태를 지역별로 기록한다', async () => {
    await save(); const sent:FcmPayload[]=[];
    const warning={typeCode:'R',type:'호우',levelCode:'2',level:'주의보',commandCode:'1',
      regionId:'L1010100',regionName:'서울서남권',announcedAt:now.toISOString(),validFrom:now.toISOString(),provider:'기상청 특보현황'};
    const control={eventKey:'test-road',controlKind:'FULL',startedAt:now.toISOString(),roadName:'검증도로',provider:'국가교통정보센터 돌발상황정보'};
    const ice={level:2,levelLabel:'주의',linkId:'test-link',producedAt:now.toISOString(),roadName:'검증고속도로',provider:'기상청'};
    await job(sent,{warningLoader:async()=>[warning],roadControlLoader:async()=>control,roadIceLoader:async()=>ice});
    await job(sent,{warningLoader:async()=>[warning],roadControlLoader:async()=>control,roadIceLoader:async()=>ice});
    expect(sent.filter(p=>p.notificationKey.startsWith('OFFICIAL_WARNING_ACTIVE'))).toHaveLength(2);
    expect(sent.filter(p=>p.notificationKey.startsWith('ROAD_CONTROL'))).toHaveLength(2);
    expect(sent.filter(p=>p.notificationKey.startsWith('ROAD_ICE'))).toHaveLength(2);
    expect(sqlite.sqlite.prepare('SELECT COUNT(*) AS n FROM notification_region_warning_state').get()).toEqual({n:2});
    expect(sqlite.sqlite.prepare('SELECT COUNT(*) AS n FROM installation_warning_state').get()).toEqual({n:0});
    await job(sent,{warningLoader:async()=>[{...warning,levelCode:'3',level:'경보'}]});
    expect(sent.filter(p=>p.notificationKey.startsWith('OFFICIAL_WARNING_CHANGED'))).toHaveLength(2);
    await job(sent);
    expect(sent.filter(p=>p.notificationKey.startsWith('OFFICIAL_WARNING_RELEASED'))).toHaveLength(2);
    expect(sqlite.sqlite.prepare('SELECT COUNT(*) AS n FROM notification_region_warning_state').get()).toEqual({n:0});
  });
  it('알림을 켠 육상 구역에 인접하고 선택한 해역의 풍랑 발효·변경·해제만 보낸다', async () => {
    const zones = await router.request('/installations/marine-warning-zones', {}, env);
    expect(await zones.json()).toMatchObject({
      zones: expect.arrayContaining([{ id: 'S1311100', name: '부산앞바다' }]),
      maxSubscriptions: 112,
    });
    expect((await save([{ key: 'S9999999', enabled: true }])).status).toBe(400);
    expect((await save([{ key: busan, enabled: true }, { key: 'S1311100', enabled: true }, { key: 'S1131100', enabled: false }])).status).toBe(200);
    const warning: OfficialWeatherWarning = {
      typeCode: 'V', type: '풍랑', levelCode: '2', level: '주의보', commandCode: '1',
      regionId: 'S1311100', regionName: '부산앞바다', announcedAt: now.toISOString(),
      validFrom: now.toISOString(), provider: '기상청 특보현황',
    };
    const writeSnapshot = (warnings: OfficialWeatherWarning[], marineCoverage: boolean) => saveCollectedCache(env.DB, {
      key: collectedCacheKey.warningSnapshot, type: 'COLLECTED_WARNING_SNAPSHOT',
      value: { warnings, marineCoverage }, updatedAt: new Date(),
    });
    const sent: FcmPayload[] = [];
    const forecastLoader = vi.fn(dependencies.forecastLoader);
    const warningRegionResolver = vi.fn(dependencies.warningRegionResolver);
    const precipitationLoader = vi.fn(dependencies.precipitationLoader);
    const run = () => job(sent, { warningLoader: undefined, forecastLoader, warningRegionResolver, precipitationLoader });
    await writeSnapshot([warning, { ...warning, regionId: 'S1131100' }], true);
    await run();
    await run();
    expect(sent.filter(p => p.notificationKey.startsWith('OFFICIAL_WARNING'))).toMatchObject([{
      title: '[부산앞바다] 풍랑주의보 발효',
      notificationKey: expect.stringMatching(/^OFFICIAL_WARNING_ACTIVE_V_.*_S1311100$/),
    }]);
    expect(sent.find(p => p.notificationKey.startsWith('OFFICIAL_WARNING'))!.notificationRegionKey).toBeUndefined();
    await writeSnapshot([], false);
    await run();
    expect(sent.filter(p => p.notificationKey.startsWith('OFFICIAL_WARNING'))).toHaveLength(1);
    await writeSnapshot([{ ...warning, levelCode: '3', level: '경보' }], true);
    await run();
    await writeSnapshot([], true);
    await run();
    expect(sent.filter(p => p.notificationKey.startsWith('OFFICIAL_WARNING')).map(p => p.title)).toEqual([
      '[부산앞바다] 풍랑주의보 발효', '[부산앞바다] 풍랑특보 변경', '[부산앞바다] 풍랑경보 해제',
    ]);
    expect(forecastLoader).toHaveBeenCalled();
    expect(warningRegionResolver).toHaveBeenCalled();
    expect(precipitationLoader).toHaveBeenCalled();
  });
  it('전체 해역 구독이어도 서울에는 0개, 부산에는 부산 인접 해역만 확장한다', async () => {
    const all = selectableMarineWarningZones.map(zone => ({ key: zone.id, enabled: true }));
    const targets = () => expandNotificationRegions(env, [{ installationId: 'device', nx: 60, ny: 127,
      latitude: null, longitude: null }], now, true);
    await save([{ key: first, enabled: true }, ...all]);
    expect((await targets()).filter(row => row.regionKey?.startsWith('S'))).toHaveLength(0);
    await save([{ key: busan, enabled: true }, { key: ulsan, enabled: false }, ...all]);
    const marine = (await targets()).filter(row => row.regionKey?.startsWith('S'));
    expect(marine.map(row => row.regionKey)).toContain('S1311100');
    expect(marine.map(row => row.regionKey)).not.toContain('S1131100');
    expect(marine.map(row => row.regionKey)).not.toContain('S1324020');
    expect(marine.every(row => row.marineSourceRegions?.length === 1)).toBe(true);
    await save([{ key: busan, enabled: false }, ...all]);
    expect((await targets()).filter(row => row.regionKey?.startsWith('S'))).toHaveLength(0);
  });
  it('해역만 구독하거나 인접 육상 구역을 발송 준비 중 끄면 풍랑과 해상 속보를 보내지 않는다', async () => {
    const sent: FcmPayload[] = [];
    const sea = { key: 'S1311100', enabled: true };
    const warning: OfficialWeatherWarning = { typeCode: 'V', type: '풍랑', levelCode: '2', level: '주의보', commandCode: '1',
      regionId: sea.key, regionName: '부산앞바다', announcedAt: now.toISOString(), validFrom: now.toISOString(), provider: '기상청 특보현황' };
    await saveCollectedCache(env.DB, { key: collectedCacheKey.disasterBulletin, type: collectedCacheKey.disasterBulletin,
      value: { issuedAt: '202609020655', title: '풍랑 현황과 전망', regionCodes: [sea.key] }, updatedAt: now });
    await save([sea]);
    await job(sent, { warningLoader: async () => [warning] });
    expect(sent).toHaveLength(0);
    await save([{ key: busan, enabled: true }, sea]);
    await job(sent, { warningLoader: async (_env: ServerEnv, ids: string[]) => {
      if (ids.includes(sea.key)) {
        await save([{ key: busan, enabled: false }, sea]);
        return [warning];
      }
      return [];
    } });
    expect(sent.filter(p => /OFFICIAL_WARNING|DISASTER_BULLETIN/.test(p.notificationKey))).toHaveLength(0);
    await save([{ key: busan, enabled: true }, sea]);
    await job(sent, { warningLoader: async (_env: ServerEnv, ids: string[]) => ids.includes(sea.key) ? [warning] : [] });
    expect(sent.filter(p => p.notificationKey.startsWith('OFFICIAL_WARNING'))).toHaveLength(1);
    expect(sent.filter(p => p.notificationKey.startsWith('DISASTER_BULLETIN'))).toHaveLength(1);
  });
  it('앞바다 관할 시군을 구분하고 내륙·먼바다·불명확한 지역은 연결하지 않는다', () => {
    const adjacent = (name: string) => adjacentMarineWarningZoneIds({ nx: 60, ny: 127, regionName: name });
    expect(adjacent('서울특별시 구로구 구로1동').size).toBe(0);
    expect(adjacent('경기도 시흥시 정왕1동')).toContain('S1251200');
    expect(adjacent('강원특별자치도 고성군 토성면')).toContain('S1151100');
    expect(adjacent('경상남도 고성군 동해면')).toContain('S1311300');
    expect(adjacent('경상남도 고성군 동해면')).not.toContain('S1151100');
    expect(adjacent('제주특별자치도 제주시 구좌읍')).toContain('S1323200');
    expect(adjacent('제주특별자치도 제주시 구좌읍')).not.toContain('S1323400');
    expect(adjacent('경기도').size).toBe(0);
    expect(adjacent('부산광역시 해운대구 우1동')).not.toContain('S1312020');
  });
  it('GPS가 같은 격자 안에서 이동해도 발송 직전에 인접 판정 좌표를 재확인한다', async () => {
    sqlite.sqlite.exec("UPDATE installations SET nx=99,ny=75,latitude=35.16,longitude=129.16");
    await save([{ key: 'GPS', enabled: true }, { key: 'S1311100', enabled: true }]);
    sqlite.sqlite.exec("UPDATE notification_regions SET region_name='부산광역시 해운대구 우제1동' WHERE region_key='GPS'");
    const targets = await expandNotificationRegions(env, [{ installationId: 'device', nx: 99, ny: 75,
      latitude: 35.16, longitude: 129.16 }], now, true);
    const sea = targets.find(target => target.regionKey === 'S1311100')!;
    expect(sea).toBeDefined();
    expect(await regionStillEnabled(env.DB, 'device', sea)).toBe(true);
    sqlite.sqlite.exec('UPDATE installations SET latitude=35.17');
    expect(await regionStillEnabled(env.DB, 'device', sea)).toBe(false);
  });
  it('같은 격자의 GPS 두 곳에 각자 정확히 포함된 육상 특보만 보낸다', async () => {
    const firstPoint = {latitude:37.44526,longitude:126.96402};
    const secondPoint = {latitude:37.44028,longitude:127.00249};
    const grid = kmaGridFromCoordinates(firstPoint.latitude,firstPoint.longitude);
    expect(grid).toEqual(kmaGridFromCoordinates(secondPoint.latitude,secondPoint.longitude));
    sqlite.sqlite.prepare('UPDATE installations SET nx=?,ny=?,latitude=?,longitude=?').run(grid.nx,grid.ny,firstPoint.latitude,firstPoint.longitude);
    sqlite.sqlite.prepare('INSERT INTO installation_credentials VALUES(?,?,?)').run('other',hash,now.toISOString());
    sqlite.sqlite.prepare(`INSERT INTO installations(installation_id,fcm_token,nx,ny,region_topic,location_mode,minimum_age_confirmed_at,age_policy_version,created_at,updated_at,latitude,longitude)
      SELECT 'other','other-token',nx,ny,region_topic,location_mode,minimum_age_confirmed_at,age_policy_version,created_at,updated_at,?,? FROM installations WHERE installation_id='device'`)
      .run(secondPoint.latitude,secondPoint.longitude);
    sqlite.sqlite.prepare("INSERT INTO notification_settings(installation_id,created_at,updated_at) VALUES('other',?,?)").run(now.toISOString(),now.toISOString());
    const warning: OfficialWeatherWarning = { typeCode:'R',type:'호우',levelCode:'2',level:'주의보',commandCode:'1',
      regionId:'L1100300',regionName:'서울서남권',announcedAt:now.toISOString(),validFrom:now.toISOString(),provider:'기상청 특보현황' };
    await saveCollectedCache(env.DB,{key:collectedCacheKey.warningSnapshot,type:'COLLECTED_WARNING_SNAPSHOT',
      value:{warnings:[warning,{...warning,regionId:'L1010300',regionName:'과천시'}]},updatedAt:new Date()});
    const sent:FcmPayload[]=[];
    await job(sent,{warningRegionResolver:undefined,warningLoader:undefined});
    const official=sent.filter(item=>item.notificationKey.startsWith('OFFICIAL_WARNING'));
    expect(official).toHaveLength(2);
    expect(official.find(item=>item.token==='token')!.body).toContain('서울서남권');
    expect(official.find(item=>item.token==='other-token')!.body).toContain('과천시');
    expect(sqlite.sqlite.prepare('SELECT installation_id,region_id FROM installation_warning_state ORDER BY installation_id').all())
      .toEqual([{installation_id:'device',region_id:'L1100300'},{installation_id:'other',region_id:'L1010300'}]);
  });
  it('GPS 이동 후 이전 구역의 해제를 보내지 않고 발송 준비 중 이동도 차단한다', async () => {
    const point={latitude:37.44526,longitude:126.96402};
    const grid=kmaGridFromCoordinates(point.latitude,point.longitude);
    sqlite.sqlite.prepare('UPDATE installations SET nx=?,ny=?,latitude=?,longitude=?').run(grid.nx,grid.ny,point.latitude,point.longitude);
    const warning:OfficialWeatherWarning={typeCode:'W',type:'강풍',levelCode:'2',level:'주의보',commandCode:'1',regionId:'L1100300',regionName:'서울서남권',
      announcedAt:now.toISOString(),validFrom:now.toISOString(),provider:'기상청 특보현황'};
    const sent:FcmPayload[]=[];
    await job(sent,{warningRegionResolver:undefined,warningLoader:async()=>[warning]});
    expect(sent.filter(p=>p.notificationKey.startsWith('OFFICIAL_WARNING'))).toHaveLength(1);
    sqlite.sqlite.exec('UPDATE installations SET latitude=37.44028,longitude=127.00249');
    await job(sent,{warningRegionResolver:undefined});
    expect(sent.filter(p=>p.notificationKey.includes('RELEASED'))).toHaveLength(0);
    expect(sqlite.sqlite.prepare('SELECT 1 FROM installation_warning_state').get()).toBeUndefined();
    sqlite.sqlite.exec('DELETE FROM notification_history; UPDATE installations SET latitude=37.44526,longitude=126.96402');
    sent.length=0;
    await job(sent,{warningRegionResolver:undefined,warningLoader:async()=>[warning],forecastLoader:async()=>{
      sqlite.sqlite.exec('UPDATE installations SET latitude=37.44028,longitude=127.00249'); return forecast();
    }});
    expect(sent.filter(p=>p.notificationKey.startsWith('OFFICIAL_WARNING'))).toHaveLength(0);
    expect(sqlite.sqlite.prepare('SELECT 1 FROM installation_warning_state').get()).toBeUndefined();
  });
  it('좌표 없는 경계 격자에서 65% 이상인 시군과 광역의 공식 특보만 발송한다', async () => {
    sqlite.sqlite.exec('UPDATE installations SET nx=69,ny=132');
    const collectedAt = new Date();
    const issued = new Date(collectedAt.getTime() + 8 * 3_600_000).toISOString().slice(0,16).replace(/\D/g,'');
    await saveCollectedCache(env.DB, {
      key: collectedCacheKey.warningStations, type: 'COLLECTED_WARNING_STATIONS', updatedAt: collectedAt,
      value: [{ regionId:'L1011400', regionName:'가평군', stationId:'1', stationName:'가평', latitude:37.82, longitude:127.51 }],
    });
    const fetcher = vi.fn(async () => new Response([
      `L1010000,경기도,L1010000,경기도,${issued},${issued},호우,주의,발표,,=`,
      `L1010000,경기도,L1011400,가평군,${issued},${issued},강풍,주의,발표,,=`,
      `L1020000,강원도,L1021600,춘천시,${issued},${issued},강풍,경보,발표,,=`,
    ].join('\n'), { headers:{'content-type':'text/plain; charset=UTF-8'} }));
    vi.stubGlobal('fetch', fetcher);
    try {
      await collectWarnings({ ...env, KMA_APIHUB_KEY:'test-key' }, [], collectedAt);
    } finally {
      vi.unstubAllGlobals();
    }
    expect(fetcher).toHaveBeenCalledTimes(1);
    const sent: FcmPayload[] = [];
    await job(sent, { now:collectedAt, warningLoader:undefined, warningRegionResolver:undefined });
    const warnings = sent.filter(item => item.notificationKey.startsWith('OFFICIAL_WARNING'));
    expect(warnings).toHaveLength(2);
    expect(warnings.every(item => item.title.includes('주의보'))).toBe(true);
    expect(sqlite.sqlite.prepare('SELECT region_id FROM installation_warning_state ORDER BY region_id').all())
      .toEqual([{ region_id:'L1010000' }, { region_id:'L1011400' }]);
  });
  it('전체 해역 요청은 전해상을 제외하고 기존 구역을 보존하며 빈 선택을 구분한다', async () => {
    const put = (marineWarningZones: 'all' | string[]) => router.request('/installations/device/notification-regions', {
      method: 'PUT', headers, body: JSON.stringify({ regions: [{ key: first, enabled: true }], marineWarningZones }),
    }, env);
    expect((await put(['S1000000'])).status).toBe(400);
    expect((await put('all')).status).toBe(200);
    const rows = () => sqlite.sqlite.prepare('SELECT region_key, scope_id FROM notification_regions ORDER BY region_key').all();
    const all = rows();
    expect(all).toHaveLength(113);
    expect(all).not.toContainEqual(expect.objectContaining({ region_key: 'S1000000' }));
    expect((await put('all')).status).toBe(200);
    expect(rows()).toEqual(all);
    expect((await put([])).status).toBe(200);
    expect(rows()).toEqual([expect.objectContaining({ region_key: first })]);
  });
  it('출퇴근 도로통제 스위치는 구 앱 저장 후에도 유지되며 발송 직전에 다시 확인한다', async () => {
    await save([{ key: first, enabled: true }]);
    const put = (body: Record<string, unknown>) => router.request('/settings/device', {
      method: 'PUT', headers, body: JSON.stringify(body),
    }, env);
    const control = { eventKey: 'test-road', controlKind: 'FULL', startedAt: now.toISOString(),
      roadName: '검증도로', provider: '국가교통정보센터 돌발상황정보' };
    const roadControlLoader = vi.fn(async () => control);
    const sent: FcmPayload[] = [];
    const roadPushes = () => sent.filter(p => p.notificationKey.startsWith('ROAD_CONTROL'));
    expect((await put({ roadControlEnabled: false })).status).toBe(200);
    expect(await (await put({ notificationTime: '07:05' })).json()).toMatchObject({ roadControlEnabled: false });
    await job(sent, { roadControlLoader });
    expect(roadControlLoader).not.toHaveBeenCalled();
    expect((await put({ roadControlEnabled: true })).status).toBe(200);
    await job(sent, { roadControlLoader, forecastLoader: async () => {
      await put({ roadControlEnabled: false });
      return forecast();
    } });
    expect(roadPushes()).toHaveLength(0);
    expect((await put({ roadControlEnabled: true })).status).toBe(200);
    await job(sent, { roadControlLoader });
    expect(roadPushes()).toHaveLength(1);
  });
  it('전송 실패 시 지역별 강수·특보·발송 이력을 기록하지 않는다', async () => {
    await save();
    await job([], {precipitationLoader:async()=>({state:'RAIN',observedAt:now.toISOString()}),
      sender:async (_env:ServerEnv, payloads:FcmPayload[])=>payloads.map(p=>({token:p.token,notificationKey:p.notificationKey,
        success:false,unregistered:false,status:503}))});
    expect(sqlite.sqlite.prepare('SELECT COUNT(*) AS n FROM notification_history').get()).toEqual({n:0});
    expect(sqlite.sqlite.prepare('SELECT COUNT(*) AS n FROM notification_region_state').get()).toEqual({n:0});
  });
  it('방재속보는 일치하는 알림 구역이 켜진 설치에 속보당 한 번만 보낸다', async () => {
    await save();
    const writeBulletin = (regionCodes: string[]) => saveCollectedCache(env.DB, {
      key: collectedCacheKey.disasterBulletin, type: collectedCacheKey.disasterBulletin,
      value: { issuedAt: '202609020655', title: '안개 현황과 전망', regionCodes }, updatedAt: now,
    });
    const sent: FcmPayload[] = [];
    const pushKey = 'DISASTER_BULLETIN_202609020655';
    const notices = () => sent.filter((item) => item.notificationKey === pushKey);
    await writeBulletin(['2600000000']);
    await job(sent);
    expect(notices()).toHaveLength(0);
    await writeBulletin(['1153000000']);
    sqlite.sqlite.exec('UPDATE notification_settings SET weather_notification_enabled=0');
    await job(sent);
    expect(notices()).toHaveLength(0);
    sqlite.sqlite.exec('UPDATE notification_settings SET weather_notification_enabled=1');
    await job(sent);
    expect(notices()).toMatchObject([{
      title: expect.stringContaining('기상청 방재속보'),
      notificationRegionKey: first,
      expiresAt: '2026-09-01T22:40:00.000Z',
    }]);
    await save([{ key: first, enabled: false }, { key: second, enabled: true }]);
    await job(sent);
    expect(notices()).toHaveLength(1);
  });
  it('속보·특보 전체와 유형 설정을 생활 알림과 분리하고 구 앱 저장에도 보존한다', async () => {
    await save([{ key: first, enabled: true }]);
    const official = {
      enabled: true, bulletin: false, S: false, W: true, V: true, D: true,
      O: true, N: true, T: true, Y: true, F: true, K: true,
    };
    const put = (body: Record<string, unknown>) => router.request('/settings/device', {
      method: 'PUT', headers, body: JSON.stringify(body),
    }, env);
    expect((await put({ weatherNotificationEnabled: false, officialAlertSettings: official })).status).toBe(200);
    expect(await (await put({ notificationTime: '07:05' })).json()).toMatchObject({
      weatherNotificationEnabled: false, officialAlertSettings: official,
    });
    await saveCollectedCache(env.DB, {
      key: collectedCacheKey.disasterBulletin, type: collectedCacheKey.disasterBulletin,
      value: { issuedAt: '202609020655', title: '안개 현황과 전망', regionCodes: ['1153000000'] }, updatedAt: now,
    });
    const wind: OfficialWeatherWarning = {
      typeCode: 'W', type: '강풍', levelCode: '2', level: '주의보', commandCode: '1',
      regionId: 'L1010100', regionName: '서울서남권', announcedAt: now.toISOString(),
      validFrom: now.toISOString(), provider: '기상청 특보현황',
    };
    const snow: OfficialWeatherWarning = { ...wind, typeCode: 'S', type: '대설' };
    const sent: FcmPayload[] = [];
    const bulletin = () => sent.filter(p => p.notificationKey.startsWith('DISASTER_BULLETIN_'));
    const warnings = () => sent.filter(p => p.notificationKey.startsWith('OFFICIAL_WARNING_'));
    await job(sent, { warningLoader: async () => [wind, snow] });
    expect(warnings().map(p => p.notificationKey)).toEqual([expect.stringContaining('ACTIVE_W_')]);
    expect(bulletin()).toHaveLength(0);
    expect((await put({ officialAlertSettings: { ...official, bulletin: true } })).status).toBe(200);
    await job(sent, { warningLoader: async () => [wind, snow], forecastLoader: async () => {
      // 푸시 큐에 들어간 뒤에도 개별 설정을 다시 확인한다.
      await put({ officialAlertSettings: { ...official, bulletin: false } });
      return forecast();
    } });
    expect(bulletin()).toHaveLength(0);
    expect((await put({ officialAlertSettings: { ...official, bulletin: true } })).status).toBe(200);
    await job(sent, { warningLoader: async () => [wind, snow] });
    expect(bulletin()).toHaveLength(1);
    expect((await put({ weatherNotificationEnabled: true, officialAlertSettings: { ...official, enabled: false } })).status).toBe(200);
    await job(sent, { warningLoader: async () => [{ ...wind, levelCode: '3', level: '경보' }] });
    expect(warnings()).toHaveLength(1);
  });
  it('실제 이전 스키마의 설치·설정·이력을 추가 마이그레이션에서 보존한다', () => {
    for(const [directory,latest] of [['migrations','0021_notification_regions.sql'],['node-migrations/users','0004_notification_regions.sql']]) {
      const old=new SqliteD1Database(':memory:');
      try {
        for(const file of readdirSync(directory).filter(n=>n.endsWith('.sql') && n<latest).sort()) old.sqlite.exec(readFileSync(`${directory}/${file}`,'utf8'));
        old.sqlite.prepare('INSERT INTO installation_credentials VALUES(?,?,?)').run('old','synthetic',now.toISOString());
        old.sqlite.prepare(`INSERT INTO installations(installation_id,nx,ny,region_topic,location_mode,created_at,updated_at)
          VALUES('old',60,127,'test','GPS',?,?)`).run(now.toISOString(),now.toISOString());
        old.sqlite.prepare(`INSERT INTO notification_settings(installation_id,notification_enabled,notification_time,commute_to_work_start,created_at,updated_at)
          VALUES('old',1,'08:35','05:10',?,?)`).run(now.toISOString(),now.toISOString());
        old.sqlite.prepare(`INSERT INTO notification_history VALUES('old','2026-09-01','MORNING_BRIEF',?,'test')`).run(now.toISOString());
        const tables=['installations','notification_settings','notification_history','installation_credentials'];
        const before=tables.map(table=>old.sqlite.prepare(`SELECT * FROM ${table}`).all());
        old.sqlite.exec(readFileSync(`${directory}/${latest}`,'utf8'));
        expect(tables.map(table=>old.sqlite.prepare(`SELECT * FROM ${table}`).all())).toEqual(before);
        expect(old.sqlite.pragma('quick_check',{simple:true})).toBe('ok');
        expect(old.sqlite.pragma('foreign_key_check')).toEqual([]);
      } finally {old.close();}
    }
  });
  it('시험 DB가 구버전이어도 공용 수집기는 기존 위치와 새 구독을 함께 읽는다', async () => {
    const legacy=new SqliteD1Database(':memory:');
    try {
      legacy.sqlite.exec(`CREATE TABLE installations(nx INTEGER,ny INTEGER,latitude REAL,longitude REAL);
        INSERT INTO installations VALUES(98,76,NULL,NULL)`);
      await save([{key:first,enabled:true}]);
      const targets=await loadCollectionTargets({...env,COLLECTION_USER_DATABASES:[asD1Database(legacy),env.DB]});
      expect(targets.some(t=>t.nx===98&&t.ny===76)).toBe(true);
      const area=catalogNotificationRegion(first)!;
      expect(targets.some(t=>t.nx===area.nx&&t.ny===area.ny)).toBe(true);
    }finally{legacy.close();}
  });
  it('알림 ON인 저장 구역도 기기를 조회하지 않아도 날씨 수집 대상에 포함한다', async () => {
    await save([{key:first,enabled:true},{key:second,enabled:false}]);
    const targets=await loadCollectionTargets(env);
    const area=catalogNotificationRegion(first)!;
    expect(targets.some(t=>t.nx===area.nx && t.ny===area.ny)).toBe(true);
    sqlite.sqlite.exec('UPDATE notification_settings SET notification_enabled=0');
    expect(await loadCollectionTargets(env)).toHaveLength(1);
  });
  it('수동 조회 지역 변경이 GPS 구독을 바꾸지 않고 실제 GPS 이동만 새 구역으로 반영한다', async () => {
    await save([{key:'GPS',enabled:true},{key:first,enabled:true}]);
    const before=sqlite.sqlite.prepare("SELECT * FROM notification_regions WHERE region_key='GPS'").get() as Record<string,unknown>;
    sqlite.sqlite.exec("UPDATE installations SET nx=98,ny=76,location_mode='MANUAL'");
    expect(sqlite.sqlite.prepare("SELECT * FROM notification_regions WHERE region_key='GPS'").get()).toEqual(before);
    sqlite.sqlite.exec("UPDATE installations SET nx=58,ny=125,location_mode='GPS',latitude=37.48,longitude=126.88");
    const after=sqlite.sqlite.prepare("SELECT * FROM notification_regions WHERE region_key='GPS'").get() as Record<string,unknown>;
    expect(after.nx).toBe(58); expect(after.scope_id).not.toBe(before.scope_id);
  });
  it('인증 삭제 시 새 구독·지역별 상태를 함께 삭제한다', async () => {
    await save(); await job([]); await deleteInstallationData(env.DB,'device',hash);
    for(const table of ['notification_region_preferences','notification_regions','notification_region_state','notification_region_warning_state'])
      expect(sqlite.sqlite.prepare(`SELECT COUNT(*) AS n FROM ${table}`).get()).toEqual({n:0});
    expect(await saveNotificationRegions(env.DB,'device',hash,[{key:first,enabled:true}])).toBe(false);
  });
  it('FCM 지역 정보는 선택 필드이며 기존 클릭 키를 유지한다', async () => {
    let body: any;
    await sendBatch({projectId:'test',clientEmail:'test@test',privateKey:'test'},[{
      token:'test',title:'제목',body:'본문',notificationKey:'MORNING_BRIEF',notificationTarget:'MAIN',notificationTopic:'OVERVIEW',
      notificationRegionKey:first,notificationRegionId:'scope',notificationRegionNx:'58',notificationRegionNy:'125',notificationRegionName:'서울 구로구 구로3동',
    }],{accessTokenProvider:async()=> 'synthetic',fetcher:async (_url,init)=>{body=JSON.parse(String(init?.body));return Response.json({name:'test'});}});
    expect(body.message.data).toMatchObject({notificationKey:'MORNING_BRIEF',notificationTarget:'MAIN',notificationRegionKey:first});
  });
});
