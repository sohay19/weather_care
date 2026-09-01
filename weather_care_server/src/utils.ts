export function regionFromQuery(nx: string | null, ny: string | null): { nx: number; ny: number; topic: string } {
  const x = parseInt(nx ?? '60', 10);
  const y = parseInt(ny ?? '121', 10);
  return { nx: x, ny: y, topic: `weather_${x}_${y}` };
}

export function coordinatesFromQuery(
  latitude: string | undefined,
  longitude: string | undefined,
): { latitude: number; longitude: number } | undefined {
  if (latitude === undefined || longitude === undefined) return undefined;
  const parsedLatitude = Number(latitude);
  const parsedLongitude = Number(longitude);
  if (
    !Number.isFinite(parsedLatitude) ||
    !Number.isFinite(parsedLongitude) ||
    parsedLatitude < 30 ||
    parsedLatitude > 44 ||
    parsedLongitude < 120 ||
    parsedLongitude > 134
  ) {
    return undefined;
  }
  return { latitude: parsedLatitude, longitude: parsedLongitude };
}
