package com.codesoha.weathercare;

import org.junit.Test;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.assertEquals;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingRequest;

public class BackgroundLocationManagerTest {
    private static final long NOW = 1_800_000_000_000L;

    @Test public void movementFenceOnlyReportsExitAndRecoversAnAlreadyExitedRegion() {
        GeofencingRequest request = BackgroundLocationManager.geofenceRequest("session-a", 37.5665, 126.978);
        assertEquals(GeofencingRequest.INITIAL_TRIGGER_EXIT, request.getInitialTrigger());
        assertEquals(1, request.getGeofences().size());
        Geofence fence = request.getGeofences().get(0);
        assertEquals("session-a", fence.getRequestId());
        assertEquals(1000, fence.getRadius(), 0);
        assertEquals(Geofence.GEOFENCE_TRANSITION_EXIT, fence.getTransitionTypes());
        assertEquals(Geofence.NEVER_EXPIRE, fence.getExpirationTime());
    }

    @Test public void movementCreatesANewFenceGenerationWithinTheSameSession() {
        String revision = "e19169ef-a3fe-4534-84fc-3e45fb5cac3f";
        String previousId = BackgroundLocationManager.newGeofenceId(revision);
        String nextId = BackgroundLocationManager.newGeofenceId(revision);
        Geofence previous = BackgroundLocationManager.geofenceRequest(previousId, 37.5665, 126.978).getGeofences().get(0);
        Geofence next = BackgroundLocationManager.geofenceRequest(nextId, 35.1796, 129.0756).getGeofences().get(0);
        assertFalse(previous.getRequestId().equals(next.getRequestId()));
        assertTrue(nextId.startsWith(revision + ":"));
        assertTrue(nextId.length() <= 100);
        assertEquals(35.1796, next.getLatitude(), 0);
        assertEquals(129.0756, next.getLongitude(), 0);
    }

    @Test public void delayedExitFromPreviousGenerationCannotMoveTheCurrentFence() {
        String previous = BackgroundLocationManager.newGeofenceId("session-a");
        String current = BackgroundLocationManager.newGeofenceId("session-a");
        assertTrue(BackgroundLocationManager.currentGeofence("session-a", current, current));
        assertFalse(BackgroundLocationManager.currentGeofence("session-a", current, previous));
        assertFalse(BackgroundLocationManager.currentGeofence("session-a", current, "session-a"));
        assertFalse(BackgroundLocationManager.currentGeofence("session-b", null, previous));
        assertFalse(BackgroundLocationManager.currentGeofence("session-a", current, null));
    }

    @Test public void legacyFenceIsAcceptedOnlyUntilANewGenerationIsRegistered() {
        assertTrue(BackgroundLocationManager.currentGeofence("session-a", null, "session-a"));
        assertTrue(BackgroundLocationManager.currentGeofence("session-a", "", "session-a"));
        assertFalse(BackgroundLocationManager.currentGeofence("session-a", "session-a:new", "session-a"));
    }

    @Test public void stationarySamplesAndShortMovesDoNotUploadAgain() {
        assertFalse(BackgroundLocationManager.moved(37.5665, 126.978, 37.5665, 126.978));
        assertFalse(BackgroundLocationManager.moved(37.5665, 126.978, 37.5675, 126.978));
        assertTrue(BackgroundLocationManager.moved(37.5665, 126.978, 37.5865, 126.978));
        assertTrue(BackgroundLocationManager.moved(37.5665, 126.978, 35.1796, 129.0756));
    }

    @Test public void expiredOfflineMovementCanBeRefreshedWithoutMovingAgain() {
        assertFalse(BackgroundLocationManager.needsFreshRetry(NOW, NOW, false, NOW + 1_000_000));
        assertFalse(BackgroundLocationManager.needsFreshRetry(NOW, NOW - 1, true, NOW + 900_000));
        assertTrue(BackgroundLocationManager.needsFreshRetry(NOW, NOW - 1, true, NOW + 900_001));
        assertTrue(BackgroundLocationManager.needsFreshRetry(NOW, NOW - 1, false, NOW + 1));
    }

    @Test public void recentDomesticSampleIsAccepted() {
        assertTrue(BackgroundLocationManager.usableSample(37.5, 127, 50, NOW, NOW));
    }
    @Test public void expiredOfflineSampleIsRejected() {
        assertTrue(BackgroundLocationManager.usableSample(37.5, 127, 50, NOW - 900_000, NOW));
        assertFalse(BackgroundLocationManager.usableSample(37.5, 127, 50, NOW - 900_001, NOW));
    }
    @Test public void futureSampleIsRejected() {
        assertTrue(BackgroundLocationManager.usableSample(37.5, 127, 50, NOW + 60_000, NOW));
        assertFalse(BackgroundLocationManager.usableSample(37.5, 127, 50, NOW + 60_001, NOW));
    }
    @Test public void foreignAndInvalidCoordinatesAreRejected() {
        assertFalse(BackgroundLocationManager.usableSample(35.7, 139.7, 50, NOW, NOW));
        assertFalse(BackgroundLocationManager.usableSample(Double.NaN, 127, 50, NOW, NOW));
        assertFalse(BackgroundLocationManager.usableSample(37.5, Double.POSITIVE_INFINITY, 50, NOW, NOW));
    }
    @Test public void unknownOrVeryInaccurateSampleIsRejected() {
        for (float accuracy : new float[]{0, -1, 5001, Float.NaN, Float.POSITIVE_INFINITY}) {
            assertFalse(BackgroundLocationManager.usableSample(37.5, 127, accuracy, NOW, NOW));
        }
    }
}
