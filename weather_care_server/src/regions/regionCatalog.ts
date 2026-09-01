export interface RegionMetadata {
  nx: number;
  ny: number;
  name: string;
  uvAreaNo: string;
  airKoreaStationName: string;
  latitude: number;
  longitude: number;
}

const REGION_CATALOG: RegionMetadata[] = [
  {
    nx: 60,
    ny: 121,
    name: '수원',
    uvAreaNo: '4111000000',
    airKoreaStationName: '인계동',
    latitude: 37.2636,
    longitude: 127.0286,
  },
  {
    nx: 60,
    ny: 127,
    name: '서울',
    uvAreaNo: '1100000000',
    airKoreaStationName: '종로구',
    latitude: 37.5665,
    longitude: 126.978,
  },
];

const REGION_BY_GRID = new Map(
  REGION_CATALOG.map((region) => [`${region.nx}:${region.ny}`, region]),
);

export function regionMetadataForGrid(
  nx: number,
  ny: number,
): RegionMetadata | undefined {
  return REGION_BY_GRID.get(`${nx}:${ny}`);
}

export function regionName(nx: number, ny: number): string {
  return regionMetadataForGrid(nx, ny)?.name ?? '선택 지역';
}

export function supportedEnvironmentalRegions(): readonly RegionMetadata[] {
  return REGION_CATALOG;
}
