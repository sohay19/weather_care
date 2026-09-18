package com.codesoha.weathercare;

import android.content.Context;
import android.content.SharedPreferences;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.codesoha.weathercare/home-widget";
    static final String WIDGET_PREFERENCES = "weather_care_widget";
    static final String SNAPSHOT_KEY = "snapshot";

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
                String snapshot = call.arguments instanceof String
                        ? (String) call.arguments
                        : null;
                if (snapshot == null) {
                    result.error("INVALID_WIDGET_DATA", "위젯 자료가 비어 있습니다.", null);
                    return;
                }
                preferences.edit().putString(SNAPSHOT_KEY, snapshot).apply();
                WeatherCareWidgetProvider.updateAll(this);
                result.success(null);
                return;
            }
            if ("clear".equals(call.method)) {
                preferences.edit().remove(SNAPSHOT_KEY).apply();
                WeatherCareWidgetProvider.updateAll(this);
                result.success(null);
                return;
            }
            result.notImplemented();
        });
    }
}
