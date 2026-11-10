import { Hono } from 'hono';
import { bodyLimit } from 'hono/body-limit';
import type { ServerEnv } from '../types';
import { ownerForRequest } from '../security/installationAccess';
import { catalogNotificationRegion, notificationRegionsSchema, saveNotificationRegions } from '../notification/notificationRegions';
import { allSeasWarningZoneId, marineWarningZoneName, maxMarineWarningSubscriptions, selectableMarineWarningZones } from '../regions/kmaMarineWarningZones';

const router = new Hono<{Bindings: ServerEnv}>();
router.use('*', bodyLimit({maxSize: 16384}));
router.get('/marine-warning-zones', c => c.json({
  zones: selectableMarineWarningZones,
  maxSubscriptions: maxMarineWarningSubscriptions,
}));
router.put('/:installationId/notification-regions', async c => {
  const id = c.req.param('installationId');
  const hash = await ownerForRequest(c, id);
  if (!hash) return c.json({error:'INSTALLATION_AUTH_REQUIRED'},401);
  const parsed = notificationRegionsSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success || parsed.data.regions.some(r => r.key !== 'GPS' && r.key !== 'LEGACY' &&
    !marineWarningZoneName(r.key) && !catalogNotificationRegion(r.key))) {
    return c.json({error:'INVALID_NOTIFICATION_REGIONS'},400);
  }
  const { marineWarningZones } = parsed.data;
  const regions = parsed.data.regions
    .filter(r => r.key !== allSeasWarningZoneId && (marineWarningZones === undefined || !marineWarningZoneName(r.key)))
    .map(r => ({ key: r.key!, enabled: r.enabled! }));
  const marineIds = marineWarningZones === 'all' ? selectableMarineWarningZones.map(zone => zone.id) : marineWarningZones;
  if (marineIds) regions.push(...marineIds.map(key => ({ key, enabled: true })));
  if (!await saveNotificationRegions(c.env.DB,id,hash,regions)) return c.json({error:'INSTALLATION_AUTH_REQUIRED'},401);
  return c.json({ok:true});
});
export default router;
