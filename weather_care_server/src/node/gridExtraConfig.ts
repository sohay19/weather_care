import { readFileSync } from 'node:fs';
import { z } from 'zod';
import type { GridExtraConfig } from '../collection/gridExtraCollection';

const code = z.string().min(1).max(40).regex(/^[A-Za-z0-9_:-]+$/);
const coordinate = z.number().finite();
const configSchema = z.object({
  tideStations: z.array(code).default([]),
  buoyStations: z.array(code).default([]),
  forecastStations: z.array(code).default([]),
  ripCurrentBeaches: z.array(code).default([]),
  romsAreas: z.array(z.object({ id: code,
    ymin: coordinate.min(-90).max(90), ymax: coordinate.min(-90).max(90),
    xmin: coordinate.min(-180).max(180), xmax: coordinate.min(-180).max(180),
  }).refine((area) => area.ymin < area.ymax && area.xmin < area.xmax)).default([]),
  riverStations: z.array(z.object({ damCode: code, stationCode: code })).default([]),
  dams: z.array(code).default([]),
});

export function loadGridExtraConfig(path: string | undefined): GridExtraConfig | null {
  if (!path?.trim()) return null;
  return configSchema.parse(JSON.parse(readFileSync(path, 'utf8'))) as GridExtraConfig;
}
