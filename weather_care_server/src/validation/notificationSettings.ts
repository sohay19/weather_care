import { z } from 'zod';

const notificationTimeSchema = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);
const officialAlertSettingsSchema = z.object({
  enabled: z.boolean(),
  bulletin: z.boolean(),
  S: z.boolean(),
  W: z.boolean(),
  V: z.boolean(),
  D: z.boolean(),
  O: z.boolean(),
  N: z.boolean(),
  T: z.boolean(),
  Y: z.boolean(),
  F: z.boolean(),
  K: z.boolean(),
}).strict();

export type OfficialAlertSettings = z.infer<typeof officialAlertSettingsSchema>;

export const notificationSettingsBodySchema = z
  .object({
    notificationEnabled: z.boolean().optional(),
    notificationTime: notificationTimeSchema.optional(),
    commuteToWorkStart: notificationTimeSchema.optional(),
    commuteToWorkEnd: notificationTimeSchema.optional(),
    commuteFromWorkStart: notificationTimeSchema.optional(),
    commuteFromWorkEnd: notificationTimeSchema.optional(),
    umbrellaEnabled: z.boolean().optional(),
    parasolEnabled: z.boolean().optional(),
    heavySnowEnabled: z.boolean().optional(),
    outerwearEnabled: z.boolean().optional(),
    maskEnabled: z.boolean().optional(),
    waterEnabled: z.boolean().optional(),
    sunscreenEnabled: z.boolean().optional(),
    drynessEnabled: z.boolean().optional(),
    todayVisibilityEnabled: z.boolean().optional(),
    todayOzoneEnabled: z.boolean().optional(),
    todayWindEnabled: z.boolean().optional(),
    todayHumidityEnabled: z.boolean().optional(),
    todayApparentTemperatureEnabled: z.boolean().optional(),
    snowPreparationEnabled: z.boolean().optional(),
    uvPreparationEnabled: z.boolean().optional(),
    pollenEnabled: z.boolean().optional(),
    blackIceEnabled: z.boolean().optional(),
    carryNotificationEnabled: z.boolean().optional(),
    todayNotificationEnabled: z.boolean().optional(),
    weatherNotificationEnabled: z.boolean().optional(),
    roadControlEnabled: z.boolean().optional(),
    officialAlertSettings: officialAlertSettingsSchema.optional(),
    dailyWeatherEnabled: z.boolean().optional(),
    heavyRainEnabled: z.boolean().optional(),
    heatwaveEnabled: z.boolean().optional(),
    coldWaveEnabled: z.boolean().optional(),
    showerAndLightRainEnabled: z.boolean().optional(),
    lightningEnabled: z.boolean().optional(),
    pipeFreezeEnabled: z.boolean().optional(),
  })
  .strict();
