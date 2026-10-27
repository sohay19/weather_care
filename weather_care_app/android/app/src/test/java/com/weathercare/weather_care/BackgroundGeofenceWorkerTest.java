package com.codesoha.weathercare;

import org.junit.Test;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class BackgroundGeofenceWorkerTest {
    private static final long NOW = 1_800_000_000_000L;

    @Test public void uncertaintyLargerThanTheFenceCannotMoveItsCenter() {
        assertTrue(BackgroundGeofenceWorker.usableCenterSample(37.5, 127, 1000, NOW, NOW));
        assertFalse(BackgroundGeofenceWorker.usableCenterSample(37.5, 127, 1001, NOW, NOW));
        assertFalse(BackgroundGeofenceWorker.usableCenterSample(37.5, 127, 0, NOW, NOW));
    }

    @Test public void delayedEventsMustObtainANewLocationRatherThanRecenterOnExpiredData() {
        assertTrue(BackgroundGeofenceWorker.usableCenterSample(37.5, 127, 50, NOW - 900_000, NOW));
        assertFalse(BackgroundGeofenceWorker.usableCenterSample(37.5, 127, 50, NOW - 900_001, NOW));
        assertFalse(BackgroundGeofenceWorker.usableCenterSample(37.5, 127, 50, NOW + 60_001, NOW));
    }

    @Test public void invalidAndForeignEventsCannotRegisterARegion() {
        assertFalse(BackgroundGeofenceWorker.usableCenterSample(Double.NaN, 127, 50, NOW, NOW));
        assertFalse(BackgroundGeofenceWorker.usableCenterSample(37.5, Double.POSITIVE_INFINITY, 50, NOW, NOW));
        assertFalse(BackgroundGeofenceWorker.usableCenterSample(35.7, 139.7, 50, NOW, NOW));
    }
}
