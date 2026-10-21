function coordinate(value: unknown, limit: number): number | undefined {
  const text = String(value ?? '').trim();
  if (!text) return;
  const dms = /^(\d{1,3})-(\d{1,2})-(\d{1,2}(?:\.\d+)?)$/.exec(text);
  if (dms && (Number(dms[2]) >= 60 || Number(dms[3]) >= 60)) return;
  const number = dms ? Number(dms[1]) + Number(dms[2]) / 60 + Number(dms[3]) / 3600 : Number(text);
  if (Number.isFinite(number) && Math.abs(number) <= limit) return number;
}

export function hrfcoStationCoordinates(row: Record<string, unknown>) {
  const latitude = coordinate(row.lat, 90);
  const longitude = coordinate(row.lon, 180);
  return latitude !== undefined && longitude !== undefined &&
    latitude >= 32 && latitude <= 40 && longitude >= 123 && longitude <= 133
    ? { latitude, longitude } : {};
}
