package com.codesoha.weathercare;

import org.junit.Test;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.assertEquals;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.Priority;
import com.google.android.gms.location.CurrentLocationRequest;

public class BackgroundLocationManagerTest {
    private static final long NOW = 1_800_000_000_000L;

    @Test public void monitorCanRequestGpsWithoutAnotherLocationConsumer() {
        LocationRequest request = BackgroundLocationManager.monitoringRequest();
        assertEquals(Priority.PRIORITY_HIGH_ACCURACY, request.getPriority());
        assertEquals(300_000, request.getIntervalMillis());
        assertEquals(60_000, request.getMinUpdateIntervalMillis());
        assertEquals(1000, request.getMinUpdateDistanceMeters(), 0);
        assertFalse(request.isWaitForAccurateLocation());
    }

    @Test public void ownFreshMeasurementIsBoundedAndDoesNotUseCachedFixes() {
        CurrentLocationRequest request = BackgroundLocationManager.freshLocationRequest();
        assertEquals(Priority.PRIORITY_HIGH_ACCURACY, request.getPriority());
        assertEquals(0, request.getMaxUpdateAgeMillis());
        assertEquals(20_000, request.getDurationMillis());
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
