import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { loadCollectionTargets } from '../src/collection/collectionTargets';
import { Hono } from 'hono';
import installations from '../src/api/installations';
import settings from '../src/api/notificationSettings';
import { asD1Database, runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { secretHash, deleteInstallationData } from '../src/security/installationAccess';
import { catalogNotificationRegion, expandNotificationRegions, saveNotificationRegions } from '../src/notification/notificationRegions';
import { runRecommendationNotificationJob } from '../src/notification/notificationScheduler';
import { KMA_ADMINISTRATIVE_AREAS } from '../src/regions/kmaAdministrativeAreas';
import { sendBatch, type FcmPayload, type FcmSendResult } from '../src/notification/fcmClient';
import type { ServerEnv } from '../src/types';

let sqlite: SqliteD1Database;
let env: ServerEnv;
let hash: string;
const secret = 'a'.repeat(64);
const headers = {Authorization:`Bearer ${secret}`, 'Content-Type':'application/json'};
const now = new Date('2026-09-02T07:00:00+09:00');
const keys = KMA_ADMINISTRATIVE_AREAS.filter(r => r[1].includes('구로구 구로') && r[1].endsWith('동'))
  .map(r => `${r[0]}|${r[1].split(' ').at(-1)}|${r[2]}|${r[3]}`);
const first = keys[0], second = keys[1];
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
    const sent:FcmPayload[]=[]; await job(sent); await job(sent);
    const briefs=sent.filter(p => p.notificationKey==='MORNING_BRIEF');
    expect(briefs).toHaveLength(2);
    expect(new Set(briefs.map(p=>p.notificationRegionId)).size).toBe(2);
    expect(briefs.map(p=>p.notificationRegionKey)).toEqual([first,second]);
    for(const p of briefs) expect(p.title).toBe(`[${catalogNotificationRegion(p.notificationRegionKey!)!.name}] 오늘자 준비물 😊`);
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
  it('전송 실패 시 지역별 강수·특보·발송 이력을 기록하지 않는다', async () => {
    await save();
    await job([], {precipitationLoader:async()=>({state:'RAIN',observedAt:now.toISOString()}),
      sender:async (_env:ServerEnv, payloads:FcmPayload[])=>payloads.map(p=>({token:p.token,notificationKey:p.notificationKey,
        success:false,unregistered:false,status:503}))});
    expect(sqlite.sqlite.prepare('SELECT COUNT(*) AS n FROM notification_history').get()).toEqual({n:0});
    expect(sqlite.sqlite.prepare('SELECT COUNT(*) AS n FROM notification_region_state').get()).toEqual({n:0});
  });
  it('실제 이전 스키마의 설치·설정·이력을 추가 마이그레이션에서 보존한다', () => {
    for(const [directory,latest] of [['migrations','0021_notification_regions.sql'],['node-migrations/users','0004_notification_regions.sql']]) {
      const old=new SqliteD1Database(':memory:');
      try {
        for(const file of readdirSync(directory).filter(n=>n.endsWith('.sql') && n!==latest).sort()) old.sqlite.exec(readFileSync(`${directory}/${file}`,'utf8'));
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
