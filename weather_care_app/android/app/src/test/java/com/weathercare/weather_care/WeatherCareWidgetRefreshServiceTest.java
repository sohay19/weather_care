package com.codesoha.weathercare;

import org.junit.Test;

import static org.junit.Assert.assertArrayEquals;
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
}
