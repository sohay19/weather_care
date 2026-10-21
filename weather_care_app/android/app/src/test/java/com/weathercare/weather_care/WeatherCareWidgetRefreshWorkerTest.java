package com.codesoha.weathercare;

import org.junit.Test;
import java.net.HttpURLConnection;
import java.net.URL;
import static org.junit.Assert.*;

public class WeatherCareWidgetRefreshWorkerTest {
    @Test
    public void testServerReceivesKeyAndDoesNotFollowRedirects() throws Exception {
        HttpURLConnection connection = (HttpURLConnection)
                new URL("https://weather-test-api.codesoha.com/api/v1/weather/widget").openConnection();
        WeatherCareWidgetRefreshWorker.authorizeTestServer(connection, "test-key");
        assertEquals("test-key", connection.getRequestProperty("X-Weather-Care-Test-Key"));
        assertFalse(connection.getInstanceFollowRedirects());
    }

    @Test
    public void otherHostsAndCleartextDoNotReceiveKey() throws Exception {
        for (String address : new String[]{
                "https://weather-api.codesoha.com/api/v1/weather/widget",
                "https://weather-test-api.codesoha.com.example.org/widget",
                "http://weather-test-api.codesoha.com/widget"
        }) {
            HttpURLConnection connection = (HttpURLConnection) new URL(address).openConnection();
            WeatherCareWidgetRefreshWorker.authorizeTestServer(connection, "test-key");
            assertNull(connection.getRequestProperty("X-Weather-Care-Test-Key"));
        }
    }

    @Test
    public void missingKeyDoesNotAddEmptyHeader() throws Exception {
        HttpURLConnection connection = (HttpURLConnection)
                new URL("https://weather-test-api.codesoha.com/widget").openConnection();
        WeatherCareWidgetRefreshWorker.authorizeTestServer(connection, null);
        assertNull(connection.getRequestProperty("X-Weather-Care-Test-Key"));
    }
}
