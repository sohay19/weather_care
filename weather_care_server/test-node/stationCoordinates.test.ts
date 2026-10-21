import { expect, it } from 'vitest';
import { hrfcoStationCoordinates } from '../src/collection/stationCoordinates';

it('공식 제원의 도분초와 십진도 좌표를 같은 WGS84 값으로 읽는다', () => {
  const point = hrfcoStationCoordinates({ lat: '37-37-27 ', lon: '128-33-04' });
  expect(point.latitude).toBeCloseTo(37.6241666667);
  expect(point.longitude).toBeCloseTo(128.5511111111);
  expect(hrfcoStationCoordinates({ lat: 37.5, lon: '127.25' })).toEqual({ latitude: 37.5, longitude: 127.25 });
});

it('제원 결측·잘못된 도분초·국외 좌표를 위치 0이나 추정 위치로 만들지 않는다', () => {
  for (const row of [{ lat: '', lon: '127' }, { lat: '37-60-00', lon: '127' },
    { lat: '37-00-99', lon: '127' }, { lat: 'NaN', lon: '127' },
    { lat: 0, lon: 0 }, { lat: 127, lon: 37 }, { lat: 37.5, lon: undefined }]) {
    expect(hrfcoStationCoordinates(row)).toEqual({});
  }
});
