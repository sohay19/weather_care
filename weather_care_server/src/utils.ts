export function regionFromQuery(nx: string | null, ny: string | null): { nx: number; ny: number; topic: string } {
  const x = parseInt(nx ?? '60', 10);
  const y = parseInt(ny ?? '121', 10);
  return { nx: x, ny: y, topic: `weather_${x}_${y}` };
}

