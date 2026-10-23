import { kmaGridCoordinates } from '../regions/kmaGridCoordinates';
import type { GridExtraConfig } from './gridExtraCollection';
import { KHOA_BUOY_STATIONS, KHOA_TIDE_STATIONS, type StationPoint } from './khoaStationCatalog';

type Coordinates = { latitude: number; longitude: number };

const TIDE_MAX_KM = 40;
const BUOY_MAX_KM = 60;
const tideStations = KHOA_TIDE_STATIONS.filter(([code]) => code.startsWith('DT_'));
const buoyStations = KHOA_BUOY_STATIONS.filter(([code]) => code.startsWith('TW_'));

function distanceKm(a: Coordinates, station: StationPoint): number {
  const radians = Math.PI / 180;
  const lat1 = a.latitude * radians;
  const lat2 = station[1] * radians;
  const deltaLat = lat2 - lat1;
  const deltaLon = (station[2] - a.longitude) * radians;
  const haversine = Math.sin(deltaLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLon / 2) ** 2;
  return 2 * 6371.0088 * Math.asin(Math.min(1, Math.sqrt(haversine)));
}

export function nearestStation(
  coordinates: Coordinates, stations: readonly StationPoint[], maxKm: number,
): string | undefined {
  let selected: string | undefined;
  let shortest = maxKm;
  for (const station of stations) {
    const distance = distanceKm(coordinates, station);
    if (distance < shortest || (distance === shortest && station[0] < (selected ?? ''))) {
      selected = station[0];
      shortest = distance;
    }
  }
  return selected;
}

function coordinatesForInstallation(row: {
  nx: number; ny: number; latitude: number | null; longitude: number | null;
}): Coordinates | undefined {
  if (row.latitude !== null && row.longitude !== null &&
    Number.isFinite(row.latitude) && Number.isFinite(row.longitude) &&
    row.latitude >= 30 && row.latitude <= 45 &&
    row.longitude >= 120 && row.longitude <= 135) {
    return { latitude: row.latitude, longitude: row.longitude };
  }
  return kmaGridCoordinates(Number(row.nx), Number(row.ny));
}

export async function selectGridCollectionStations(
  db: D1Database, config: GridExtraConfig, databases: D1Database[] = [db],
): Promise<GridExtraConfig> {
  const groups = await Promise.all(databases.map(database => database.prepare(`SELECT nx, ny, latitude, longitude FROM installations
    GROUP BY nx, ny, latitude, longitude`).all<{
    nx: number; ny: number; latitude: number | null; longitude: number | null;
  }>()));
  const tide = new Set(config.tideStations);
  const buoy = new Set(config.buoyStations);
  const forecast = new Set(config.forecastStations);
  for (const row of groups.flatMap(group => group.results)) {
    const coordinates = coordinatesForInstallation(row);
    if (!coordinates) continue;
    const tideCode = nearestStation(coordinates, tideStations, TIDE_MAX_KM);
    const buoyCode = nearestStation(coordinates, buoyStations, BUOY_MAX_KM);
    if (tideCode) tide.add(tideCode);
    if (buoyCode) buoy.add(buoyCode);
    if (tideCode) forecast.add(tideCode);
  }
  return {
    ...config,
    tideStations: [...tide].sort(),
    buoyStations: [...buoy].sort(),
    forecastStations: [...forecast].sort(),
  };
}
