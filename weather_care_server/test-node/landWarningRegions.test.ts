import { describe, expect, it } from 'vitest';
import { landWarningRegionsAtPoint, landWarningRegionsForGrid, landWarningRegionsForTarget } from '../src/regions/landWarningRegions';
import { kmaGridFromCoordinates } from '../src/regions/kmaGridFromCoordinates';
import data from '../src/regions/kmaWarningBoundaries.json';
import { decodeBoundaryGeometry } from '../src/regions/administrativeBoundaries';

const seoul = { latitude:37.44526,longitude:126.96402 };
const gwacheon = { latitude:37.44028,longitude:127.00249 };
describe('기상청 공식 육상 특보 경계', () => {
  it('같은 5km 격자의 서울과 과천을 정확한 경계로 구분한다', () => {
    expect(kmaGridFromCoordinates(seoul.latitude,seoul.longitude)).toEqual(kmaGridFromCoordinates(gwacheon.latitude,gwacheon.longitude));
    const first = landWarningRegionsAtPoint(seoul.latitude,seoul.longitude);
    const second = landWarningRegionsAtPoint(gwacheon.latitude,gwacheon.longitude);
    expect(first).toContain('L1100300'); expect(first).not.toContain('L1010300');
    expect(second).toContain('L1010300'); expect(second).not.toContain('L1100300');
    expect(first).toContain('L1100000'); expect(second).toContain('L1010000');
  });
  it('공식 자료의 경계선·해외·바다·잘못된 좌표를 인접 육상으로 확대하지 않는다', () => {
    const zone = data.zones.find(zone => zone.id === 'L1010300')!;
    const raw = decodeBoundaryGeometry(zone.geometry), view = new DataView(raw.buffer,raw.byteOffset,raw.byteLength);
    expect(landWarningRegionsAtPoint(view.getFloat64(16,true),view.getFloat64(8,true))).not.toContain(zone.id);
    for (const [lat,lon] of [[0,0],[36,124],[NaN,127],[Infinity,127]]) expect(landWarningRegionsAtPoint(lat,lon)).toEqual([]);
  });
  it('직접 선택한 동은 공식 행정구역 설명으로 연결하고 격자 중심으로 대체하지 않는다', () => {
    const at = (key:string) => landWarningRegionsForTarget({regionKey:key,scopeId:'saved',nx:60,ny:124,latitude:null,longitude:null});
    expect(at('4129051000|중앙동|60|124')).toContain('L1010300');
    expect(at('4129051000|중앙동|60|124')).not.toContain('L1100300');
    expect(at('2635051000|우1동|99|75')).toContain('L1082500');
    expect(at('3117051000|방어동|104|83')).toContain('L1082800');
    expect(at('9999999999|위조동|60|124')).toEqual([]);
  });
  it('GPS나 읍면동 코드가 있으면 격자에서 더 넓게 잡힌 다른 구역을 사용하지 않는다', () => {
    const grid = { nx:60, ny:124, latitude:null, longitude:null };
    expect(landWarningRegionsForTarget({ ...grid, locationMode:'GPS' })).toContain('L1010300');
    expect(landWarningRegionsForTarget({ ...grid, locationMode:'GPS', ...seoul })).toEqual(['L1100300','L1100000']);
    expect(landWarningRegionsForTarget({locationMode:'GPS',nx:1,ny:1,...seoul})).toEqual([]);
    expect(landWarningRegionsForTarget({ ...grid, locationMode:'GPS', latitude:seoul.latitude })).toEqual([]);
    expect(landWarningRegionsForTarget({ ...grid, regionKey:'1153055000|구로4동|60|124', scopeId:'saved' })).not.toContain('L1010300');
    expect(landWarningRegionsForTarget({ ...grid, locationMode:'MANUAL', adminCode:'9999999999' })).toEqual([]);
    expect(landWarningRegionsForTarget({ ...grid, locationMode:'MANUAL', ...seoul })).toEqual([]);
  });
  it('좌표 없는 등록에는 격자 면적 65% 이상인 구역만 적용한다', () => {
    expect(landWarningRegionsForGrid(77,122)).toEqual(['L1021200','L1020000']);
    expect(landWarningRegionsForGrid(58,124)).toEqual(['L1010200','L1010000']);
    expect(landWarningRegionsForGrid(69,132)).toEqual(['L1011400','L1010000']);
    expect(landWarningRegionsForGrid(1,1)).toEqual([]);
    expect(landWarningRegionsForGrid(0,124)).toEqual([]);
    const grid = { nx:69, ny:132, latitude:null, longitude:null };
    expect(landWarningRegionsForTarget({ ...grid, locationMode:'MANUAL' })).toEqual(['L1011400','L1010000']);
    expect(landWarningRegionsForTarget({ ...grid, regionKey:'LEGACY', scopeId:'legacy' })).toEqual(['L1011400','L1010000']);
    expect(landWarningRegionsForTarget({ ...grid, regionKey:'GPS', scopeId:'gps' })).toEqual(['L1011400','L1010000']);
    expect(landWarningRegionsForTarget({ ...grid, locationMode:'GPS', latitude:37 })).toEqual([]);
  });
});
