import { z } from 'zod';

const notificationTimeSchema = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);

export const notificationSettingsBodySchema = z
  .object({
    notificationEnabled: z.boolean().optional(),
    notificationTime: notificationTimeSchema.optional(),
    umbrellaEnabled: z.boolean().optional(),
    parasolEnabled: z.boolean().optional(),
    heavySnowEnabled: z.boolean().optional(),
    outerwearEnabled: z.boolean().optional(),
    maskEnabled: z.boolean().optional(),
    waterEnabled: z.boolean().optional(),
    sunscreenEnabled: z.boolean().optional(),
    dailyWeatherEnabled: z.boolean().optional(),
    heavyRainEnabled: z.boolean().optional(),
    heatwaveEnabled: z.boolean().optional(),
    coldWaveEnabled: z.boolean().optional(),
    showerAndLightRainEnabled: z.boolean().optional(),
  })
  .strict();
