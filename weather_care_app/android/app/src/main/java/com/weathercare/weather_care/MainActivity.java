package com.codesoha.weathercare;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.provider.Settings;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import org.json.JSONObject;

import java.util.Map;
import java.util.UUID;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.codesoha.weathercare/home-widget";
    static final String WIDGET_PREFERENCES = "weather_care_widget";
    static final String SNAPSHOT_KEY = "snapshot";
    static final String REFRESH_URL_KEY = "refresh_url";
    static final String WIDGET_TEST_ACCESS_KEY = "test_access_key";
    static final String GPS_ENABLED_KEY = "gps_enabled";
    static final String REVISION_KEY = "selection_revision";
    static final String LOCATION_MEASURED_KEY = "location_measured_millis";
    static final Object WIDGET_LOCK = new Object();
    private MethodChannel.Result backgroundPermissionResult;

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == 731) {
            BackgroundLocationManager.resume(this);
            if (backgroundPermissionResult != null) {
                backgroundPermissionResult.success(null);
                backgroundPermissionResult = null;
            }
        }
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                "com.codesoha.weathercare/background-location").setMethodCallHandler((call, result) -> {
            try {
                switch (call.method) {
                    case "configure": BackgroundLocationManager.configure(this, (Map<?, ?>) call.arguments); break;
                    case "stop": BackgroundLocationManager.stop(this); break;
                    case "resume": BackgroundLocationManager.resume(this); break;
                    case "openNotificationSettings":
                        BackgroundLocationService.ensureNotificationChannel(this);
                        startActivity(new Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName())
                                .putExtra(Settings.EXTRA_CHANNEL_ID, BackgroundLocationService.CHANNEL));
                        result.success(true);
                        return;
                    case "requestPermission":
                        if (backgroundPermissionResult != null) { result.success(null); return; }
                        boolean initial = call.arguments instanceof Map<?, ?> args && Boolean.TRUE.equals(args.get("initial"));
                        if (BackgroundLocationManager.requestPermission(this, initial)) {
                            backgroundPermissionResult = result;
                            return;
                        }
                        break;
                    case "status": result.success(BackgroundLocationManager.status(this)); return;
                    default: result.notImplemented(); return;
                }
                result.success(null);
            } catch (Exception error) {
                result.error("BACKGROUND_LOCATION_FAILED", "이동 감지를 설정하지 못했어요.", null);
            }
        });
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {
            synchronized (WIDGET_LOCK) {
                SharedPreferences preferences = getSharedPreferences(
                        WIDGET_PREFERENCES,
                        Context.MODE_PRIVATE
                );
                if ("save".equals(call.method)) {
                    String snapshot = null;
                    String refreshUrl = null;
                    String testAccessKey = null;
                    boolean gpsEnabled = false;
                    long locationMeasuredMillis = 0;
                    if (call.arguments instanceof String) {
                        snapshot = (String) call.arguments;
                    } else if (call.arguments instanceof Map<?, ?> values) {
                        Object rawSnapshot = values.get("snapshot");
                        Object rawRefreshUrl = values.get("refreshUrl");
                        Object rawTestAccessKey = values.get("testAccessKey");
                        Object rawGpsEnabled = values.get("gpsEnabled");
                        if (rawSnapshot instanceof String) snapshot = (String) rawSnapshot;
                        if (rawRefreshUrl instanceof String) refreshUrl = (String) rawRefreshUrl;
                        if (rawTestAccessKey instanceof String) testAccessKey = (String) rawTestAccessKey;
                        if (rawGpsEnabled instanceof Boolean) gpsEnabled = (Boolean) rawGpsEnabled;
                        if (values.get("locationMeasuredAt") instanceof String time) {
                            try { locationMeasuredMillis = java.time.Instant.parse(time).toEpochMilli(); }
                            catch (Exception ignored) { }
                        }
                    }
                    if (snapshot == null) {
                        result.error("INVALID_WIDGET_DATA", "위젯 자료가 비어 있습니다.", null);
                        return;
                    }
                    if (gpsEnabled && preferences.getBoolean(GPS_ENABLED_KEY, false) &&
                            preferences.getLong(LOCATION_MEASURED_KEY, 0) > locationMeasuredMillis) {
                        result.success(null);
                        return;
                    }
                    SharedPreferences.Editor editor = preferences.edit()
                            .putString(REVISION_KEY, UUID.randomUUID().toString())
                            .putString(SNAPSHOT_KEY, snapshot)
                            .putBoolean(WeatherCareWidgetProvider.REFRESH_IN_PROGRESS_KEY, false)
                            .remove(WeatherCareWidgetProvider.REFRESH_STATUS_KEY)
                            .putBoolean(GPS_ENABLED_KEY, gpsEnabled);
                    if (gpsEnabled) editor.putLong(LOCATION_MEASURED_KEY, locationMeasuredMillis);
                    else editor.remove(LOCATION_MEASURED_KEY);
                    if (refreshUrl == null || refreshUrl.isBlank()) {
                        editor.remove(REFRESH_URL_KEY);
                    } else {
                        editor.putString(REFRESH_URL_KEY, refreshUrl);
                    }
                    if (testAccessKey == null || testAccessKey.isBlank()) {
                        editor.remove(WIDGET_TEST_ACCESS_KEY);
                    } else {
                        editor.putString(WIDGET_TEST_ACCESS_KEY, testAccessKey);
                    }
                    editor.apply();
                    WeatherCareWidgetProvider.updateAll(this);
                    result.success(null);
                    return;
                }
                if ("clear".equals(call.method)) {
                    preferences.edit()
                            .putString(REVISION_KEY, UUID.randomUUID().toString())
                            .remove(SNAPSHOT_KEY)
                            .remove(REFRESH_URL_KEY)
                            .remove(WIDGET_TEST_ACCESS_KEY)
                            .remove(GPS_ENABLED_KEY)
                            .remove(LOCATION_MEASURED_KEY)
                            .putBoolean(WeatherCareWidgetProvider.REFRESH_IN_PROGRESS_KEY, false)
                            .remove(WeatherCareWidgetProvider.REFRESH_STATUS_KEY)
                            .apply();
                    WeatherCareWidgetProvider.updateAll(this);
                    result.success(null);
                    return;
                }
                result.notImplemented();
            }
        });
    }

    static String preserveSpecificWidgetRegion(String incoming, String previous) {
        if (previous == null || previous.isBlank()) return incoming;
        try {
            JSONObject next = new JSONObject(incoming);
            JSONObject stored = new JSONObject(previous);
            String nextRegion = next.optString("region", "").trim();
            String storedRegion = stored.optString("region", "").trim();
            if (!shouldPreserveWidgetRegion(nextRegion, storedRegion) ||
                    !sameWidgetLocation(next, stored)) {
                return incoming;
            }
            next.put("region", storedRegion);
            return next.toString();
        } catch (Exception ignored) {
            return incoming;
        }
    }

    private static boolean isSpecificWidgetRegion(String value) {
        return !value.isBlank() &&
                !"현재 위치".equals(value) &&
                !"선택 지역".equals(value) &&
                !"지역을 설정해주세요".equals(value);
    }

    private static boolean shouldPreserveWidgetRegion(String next, String stored) {
        if (!isSpecificWidgetRegion(stored)) return false;
        return !isSpecificWidgetRegion(next) ||
                (stored.length() > next.length() && stored.startsWith(next));
    }

    private static boolean sameWidgetLocation(JSONObject left, JSONObject right) {
        String leftKey = widgetLocationScope(left.optString("locationKey", ""));
        String rightKey = widgetLocationScope(right.optString("locationKey", ""));
        return !leftKey.isBlank() && leftKey.equals(rightKey);
    }

    private static String widgetLocationScope(String value) {
        String key = value.trim();
        int nameIndex = key.indexOf(":name:");
        return nameIndex < 0 ? key : key.substring(0, nameIndex);
    }
}
