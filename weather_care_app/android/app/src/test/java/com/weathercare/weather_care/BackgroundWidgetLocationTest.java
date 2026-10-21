package com.codesoha.weathercare;

import org.junit.Test;
import static org.junit.Assert.*;

public class BackgroundWidgetLocationTest {
    private static final String PREVIOUS = "https://weather-test-api.codesoha.com/api/v1/weather/widget?nx=60&ny=127&regionName=old&regionCode=old&latitude=37.57&longitude=126.98&widgetSettings=u1p1";

    @Test public void movementReplacesLocationAndDropsOldRegion() {
        String next = BackgroundWidgetLocation.movedUrl(PREVIOUS, 35.1796, 129.0756, true);
        assertEquals("https://weather-test-api.codesoha.com/api/v1/weather/widget?nx=98&ny=76&widgetSettings=u1p1&latitude=35.1796&longitude=129.0756", next);
    }

    @Test public void coarseMovementOnlySendsGrid() {
        String next = BackgroundWidgetLocation.movedUrl(PREVIOUS, 33.4996, 126.5312, false);
        assertEquals("https://weather-test-api.codesoha.com/api/v1/weather/widget?nx=53&ny=38&widgetSettings=u1p1", next);
        assertNull(BackgroundWidgetLocation.movedUrl(PREVIOUS, Double.NaN, 126, true));
        assertNull(BackgroundWidgetLocation.movedUrl(PREVIOUS, 0, 0, true));
    }

    @Test public void manualSelectionAndNewerFixWin() {
        assertFalse(BackgroundWidgetLocation.canFollow(false, 10, 20));
        assertFalse(BackgroundWidgetLocation.canFollow(true, 20, 10));
        assertTrue(BackgroundWidgetLocation.canFollow(true, 10, 20));
        assertTrue(BackgroundWidgetLocation.canFollow(true, 20, 20));
    }

    @Test public void serverAndEndpointMustMatch() {
        assertTrue(BackgroundWidgetLocation.sameServer(PREVIOUS, "https://weather-test-api.codesoha.com/api/v1/installations/test/location"));
        assertFalse(BackgroundWidgetLocation.sameServer(PREVIOUS, "https://weather-api.codesoha.com/api/v1/installations/test/location"));
        assertFalse(BackgroundWidgetLocation.sameServer(PREVIOUS, "http://weather-test-api.codesoha.com/api/v1/installations/test/location"));
        assertNull(BackgroundWidgetLocation.movedUrl("https://example.com/other", 37.57, 126.98, true));
        assertNull(BackgroundWidgetLocation.movedUrl("https://user@example.com/api/v1/weather/widget", 37.57, 126.98, true));
    }

    @Test public void settingsAreEncodedOnceAndUnknownQueryIsRemoved() {
        String next = BackgroundWidgetLocation.movedUrl("https://example.com/api/v1/weather/widget?widgetSettings=a%2Bb&unknown=secret", 37.5665, 126.978, false);
        assertEquals("https://example.com/api/v1/weather/widget?nx=60&ny=127&widgetSettings=a%2Bb", next);
    }

    @Test public void resolvedKoreanRegionReplacesOldNameAndIsEncodedOnce() throws Exception {
        String next = BackgroundWidgetLocation.movedUrl(PREVIOUS, 35.1796, 129.0756, true, "부산 중구 중앙동");
        assertTrue(java.net.URLDecoder.decode(next, "UTF-8").endsWith("&regionName=부산 중구 중앙동"));
        assertFalse(next.contains("regionName=old"));
        assertFalse(next.contains("regionCode"));
        assertFalse(BackgroundWidgetLocation.movedUrl(PREVIOUS, 35.1796, 129.0756, false, "부산 중구 중앙동").contains("regionName"));
    }
}
