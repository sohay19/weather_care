const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const OFFICIAL_ZENITH_DEGREES = 90.833;

export interface SunTimes {
  sunriseAt?: string;
  sunsetAt?: string;
}

export function calculateSunTimes(
  now: Date,
  latitude: number,
  longitude: number,
): SunTimes {
  if (!validCoordinates(latitude, longitude)) return {};
  const koreanDate = new Date(now.getTime() + KST_OFFSET_MS)
    .toISOString()
    .slice(0, 10);
  return {
    sunriseAt: solarEvent(koreanDate, latitude, longitude, true),
    sunsetAt: solarEvent(koreanDate, latitude, longitude, false),
  };
}

function solarEvent(
  calendarDate: string,
  latitude: number,
  longitude: number,
  sunrise: boolean,
): string | undefined {
  const dayOfYear = ordinalDay(calendarDate);
  const longitudeHour = longitude / 15;
  const approximateTime = dayOfYear + ((sunrise ? 6 : 18) - longitudeHour) / 24;
  const meanAnomaly = 0.9856 * approximateTime - 3.289;
  const trueLongitude = normalizeDegrees(
    meanAnomaly +
      1.916 * sinDegrees(meanAnomaly) +
      0.02 * sinDegrees(2 * meanAnomaly) +
      282.634,
  );
  let rightAscension = normalizeDegrees(
    radiansToDegrees(
      Math.atan(0.91764 * Math.tan(degreesToRadians(trueLongitude))),
    ),
  );
  rightAscension +=
    Math.floor(trueLongitude / 90) * 90 - Math.floor(rightAscension / 90) * 90;
  rightAscension /= 15;

  const sinDeclination = 0.39782 * sinDegrees(trueLongitude);
  const cosDeclination = Math.cos(Math.asin(sinDeclination));
  const cosHour =
    (cosDegrees(OFFICIAL_ZENITH_DEGREES) -
      sinDeclination * sinDegrees(latitude)) /
    (cosDeclination * cosDegrees(latitude));
  if (cosHour < -1 || cosHour > 1) return undefined;

  const hourAngle = sunrise
    ? 360 - radiansToDegrees(Math.acos(cosHour))
    : radiansToDegrees(Math.acos(cosHour));
  const localMeanTime =
    hourAngle / 15 + rightAscension - 0.06571 * approximateTime - 6.622;
  const utcHour = normalizeHours(localMeanTime - longitudeHour);
  const koreanHour = normalizeHours(utcHour + 9);
  const koreanMidnight = Date.parse(`${calendarDate}T00:00:00+09:00`);
  return new Date(koreanMidnight + koreanHour * 60 * 60 * 1000).toISOString();
}

function ordinalDay(calendarDate: string): number {
  const year = Number(calendarDate.slice(0, 4));
  const start = Date.UTC(year, 0, 1);
  const date = Date.parse(`${calendarDate}T00:00:00Z`);
  return Math.floor((date - start) / 86_400_000) + 1;
}

function validCoordinates(latitude: number, longitude: number): boolean {
  return (
    Number.isFinite(latitude) &&
    latitude >= -90 &&
    latitude <= 90 &&
    Number.isFinite(longitude) &&
    longitude >= -180 &&
    longitude <= 180
  );
}

function normalizeDegrees(value: number): number {
  return ((value % 360) + 360) % 360;
}

function normalizeHours(value: number): number {
  return ((value % 24) + 24) % 24;
}

function degreesToRadians(value: number): number {
  return (value * Math.PI) / 180;
}

function radiansToDegrees(value: number): number {
  return (value * 180) / Math.PI;
}

function sinDegrees(value: number): number {
  return Math.sin(degreesToRadians(value));
}

function cosDegrees(value: number): number {
  return Math.cos(degreesToRadians(value));
}
