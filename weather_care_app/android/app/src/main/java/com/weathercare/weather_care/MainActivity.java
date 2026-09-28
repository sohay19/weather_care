package com.codesoha.weathercare;

import android.content.Context;
import android.content.SharedPreferences;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.codesoha.weathercare/home-widget";
    static final String WIDGET_PREFERENCES = "weather_care_widget";
    static final String SNAPSHOT_KEY = "snapshot";
    static final String REFRESH_URL_KEY = "refresh_url";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {
            SharedPreferences preferences = getSharedPreferences(
                    WIDGET_PREFERENCES,
                    Context.MODE_PRIVATE
            );
            if ("save".equals(call.method)) {
                String snapshot = null;
                String refreshUrl = null;
                if (call.arguments instanceof String) {
                    snapshot = (String) call.arguments;
                } else if (call.arguments instanceof Map<?, ?> values) {
                    Object rawSnapshot = values.get("snapshot");
                    Object rawRefreshUrl = values.get("refreshUrl");
                    if (rawSnapshot instanceof String) snapshot = (String) rawSnapshot;
                    if (rawRefreshUrl instanceof String) refreshUrl = (String) rawRefreshUrl;
                }
                if (snapshot == null) {
                    result.error("INVALID_WIDGET_DATA", "위젯 자료가 비어 있습니다.", null);
                    return;
                }
                SharedPreferences.Editor editor = preferences.edit()
                        .putString(SNAPSHOT_KEY, snapshot);
                if (refreshUrl == null || refreshUrl.isBlank()) {
                    editor.remove(REFRESH_URL_KEY);
                } else {
                    editor.putString(REFRESH_URL_KEY, refreshUrl);
                }
                editor.apply();
                WeatherCareWidgetProvider.updateAll(this);
                result.success(null);
                return;
            }
            if ("clear".equals(call.method)) {
                preferences.edit()
                        .remove(SNAPSHOT_KEY)
                        .remove(REFRESH_URL_KEY)
                        .apply();
                WeatherCareWidgetProvider.updateAll(this);
                result.success(null);
                return;
            }
            result.notImplemented();
        });
    }
}
