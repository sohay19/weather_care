package com.codesoha.weathercare;

import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONObject;
import java.net.URI;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

/** Publish a new GPS selection before fetching its weather. Manual selections win. */
final class BackgroundWidgetLocation {
    private static final ExecutorService GEOCODER = Executors.newSingleThreadExecutor(task -> {
        Thread thread = new Thread(task, "widget-region-name");
        thread.setDaemon(true);
        return thread;
    });

    static void follow(Context context, JSONObject sent, String sessionRevision) {
        if (!BackgroundLocationManager.permitted(context)) return;
        final String regionName;
        try {
            // Resolve outside both locks so a slow geocoder cannot block a manual selection/stop.
            synchronized (BackgroundLocationManager.LOCK) {
                JSONObject current = BackgroundLocationManager.read(context);
                SharedPreferences prefs = context.getSharedPreferences(MainActivity.WIDGET_PREFERENCES, Context.MODE_PRIVATE);
                long measured = Instant.parse(sent.getString("measuredAt")).toEpochMilli();
                if (current == null || !sessionRevision.equals(current.optString("revision")) ||
                        current.optLong("measuredMillis") > measured || !canFollow(
                        prefs.getBoolean(MainActivity.GPS_ENABLED_KEY, false),
                        prefs.getLong(MainActivity.LOCATION_MEASURED_KEY, 0), measured)) return;
            }
            regionName = sent.optBoolean("precise") && sent.optDouble("accuracy", 5001) <= 500
                    ? resolveRegionName(context, sent.getDouble("latitude"), sent.getDouble("longitude")) : null;
        } catch (Exception ignored) { return; }
        synchronized (BackgroundLocationManager.LOCK) {
            JSONObject current = BackgroundLocationManager.read(context);
            if (current == null || !sessionRevision.equals(current.optString("revision"))) return;
            try {
                long measured = Instant.parse(sent.getString("measuredAt")).toEpochMilli();
                if (current.optLong("measuredMillis") > measured) return;
                synchronized (MainActivity.WIDGET_LOCK) {
                    SharedPreferences prefs = context.getSharedPreferences(MainActivity.WIDGET_PREFERENCES, Context.MODE_PRIVATE);
                    if (!canFollow(prefs.getBoolean(MainActivity.GPS_ENABLED_KEY, false),
                            prefs.getLong(MainActivity.LOCATION_MEASURED_KEY, 0), measured)) return;
                    String previous = prefs.getString(MainActivity.REFRESH_URL_KEY, null);
                    if (previous == null || !sameServer(previous, current.getString("url"))) return;
                    String next = movedUrl(previous, sent.getDouble("latitude"), sent.getDouble("longitude"),
                            sent.optBoolean("precise") && sent.optDouble("accuracy", 5001) <= 500, regionName);
                    if (next == null) return;
                    if (!prefs.edit().putString(MainActivity.REFRESH_URL_KEY, next)
                            .putString(MainActivity.REVISION_KEY, UUID.randomUUID().toString())
                            .putLong(MainActivity.LOCATION_MEASURED_KEY, measured)
                            .remove(MainActivity.SNAPSHOT_KEY)
                            .putString(WeatherCareWidgetProvider.REFRESH_STATUS_KEY, "불러오는 중")
                            .commit()) return;
                    WeatherCareWidgetProvider.updateAll(context);
                    WeatherCareWidgetProvider.enqueueRefresh(context, true);
                }
            } catch (Exception ignored) { /* Keep the last valid selection on malformed input. */ }
        }
    }

    private static String resolveRegionName(Context context, double latitude, double longitude) {
        Future<String> result = GEOCODER.submit(() ->
                WeatherCareWidgetRefreshService.regionName(context, latitude, longitude));
        try { return result.get(4, TimeUnit.SECONDS); }
        catch (Exception ignored) { result.cancel(true); return null; }
    }

    static boolean canFollow(boolean gpsEnabled, long storedTime, long measuredTime) {
        return gpsEnabled && measuredTime >= storedTime;
    }

    static boolean sameServer(String widget, String registration) {
        try {
            URI a = URI.create(widget), b = URI.create(registration);
            return a.getHost() != null && a.getHost().equals(b.getHost()) &&
                    a.getScheme().equals(b.getScheme()) && a.getPort() == b.getPort() && a.getUserInfo() == null;
        } catch (Exception error) { return false; }
    }

    static String movedUrl(String previous, double latitude, double longitude, boolean precise) {
        return movedUrl(previous, latitude, longitude, precise, null);
    }

    static String movedUrl(String previous, double latitude, double longitude, boolean precise, String regionName) {
        int[] grid = WeatherCareWidgetRefreshService.gridFor(latitude, longitude);
        if (grid == null) return null;
        try {
            URI uri = URI.create(previous);
            if (uri.getHost() == null || uri.getUserInfo() != null ||
                    !("https".equals(uri.getScheme()) || "http".equals(uri.getScheme())) ||
                    !"/api/v1/weather/widget".equals(uri.getPath())) return null;
            String settings = null;
            for (String part : (uri.getRawQuery() == null ? "" : uri.getRawQuery()).split("&")) {
                String[] pair = part.split("=", 2);
                if (URLDecoder.decode(pair[0], "UTF-8").equals("widgetSettings") && pair.length == 2)
                    settings = URLDecoder.decode(pair[1], "UTF-8");
            }
            String query = "nx=" + grid[0] + "&ny=" + grid[1];
            if (settings != null) query += "&widgetSettings=" + URLEncoder.encode(settings, "UTF-8");
            if (precise) query += "&latitude=" + latitude + "&longitude=" + longitude;
            if (precise && regionName != null && !regionName.isBlank())
                query += "&regionName=" + URLEncoder.encode(regionName.trim(), "UTF-8");
            return new URI(uri.getScheme(), null, uri.getHost(), uri.getPort(), uri.getPath(), null, null).toString() + "?" + query;
        } catch (Exception error) { return null; }
    }
}
