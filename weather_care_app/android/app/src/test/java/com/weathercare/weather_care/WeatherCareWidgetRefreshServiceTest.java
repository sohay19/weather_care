package com.codesoha.weathercare;

import org.junit.Test;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

public class WeatherCareWidgetRefreshServiceTest {
    @Test
    public void currentCoordinatesUseTheSameKmaGridAsTheApp() {
        assertArrayEquals(new int[] {60, 127},
                WeatherCareWidgetRefreshService.gridFor(37.5665, 126.9780));
        assertArrayEquals(new int[] {98, 76},
                WeatherCareWidgetRefreshService.gridFor(35.1796, 129.0756));
        assertArrayEquals(new int[] {53, 38},
                WeatherCareWidgetRefreshService.gridFor(33.4996, 126.5312));
    }

    @Test
    public void outsideServiceAreaDoesNotReuseThePreviousGrid() {
        assertNull(WeatherCareWidgetRefreshService.gridFor(35.7, 139.7));
        assertNull(WeatherCareWidgetRefreshService.gridFor(Double.NaN, 126.9));
    }

    @Test
    public void addressLineCanRestoreMissingNeighborhood() {
        assertEquals("은행동", WeatherCareWidgetRefreshService.neighborhoodInAddressLine(
                "대한민국 경기도 시흥시 은행동 123"
        ));
        assertNull(WeatherCareWidgetRefreshService.neighborhoodInAddressLine(
                "대한민국 경기도 시흥시 은계중앙로 123"
        ));
    }

    @Test
    public void cityOnlyGeocoderResultKeepsNearbyDetailedName() {
        assertEquals("시흥시 은행동", WeatherCareWidgetRefreshService.preferDetailedName(
                "시흥시", "시흥시 은행동", 120, true
        ));
        assertEquals("시흥시 대야동", WeatherCareWidgetRefreshService.preferDetailedName(
                "시흥시 대야동", "시흥시 은행동", 120, true
        ));
        assertEquals("시흥시", WeatherCareWidgetRefreshService.preferDetailedName(
                "시흥시", "시흥시 은행동", 800, true
        ));
        assertEquals("시흥시", WeatherCareWidgetRefreshService.preferDetailedName(
                "시흥시", "시흥시 은행동", 120, false
        ));
        assertEquals("시흥시", WeatherCareWidgetRefreshService.preferDetailedName(
                "시흥시", "시흥시 은행동", Double.NaN, true
        ));
    }
}
