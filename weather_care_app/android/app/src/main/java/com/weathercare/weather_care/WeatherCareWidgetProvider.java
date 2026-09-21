package com.codesoha.weathercare;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Typeface;
import android.os.Bundle;
import android.text.Spannable;
import android.text.SpannableStringBuilder;
import android.text.style.StyleSpan;
import android.view.View;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class WeatherCareWidgetProvider extends AppWidgetProvider {
    private static final int MEDIUM_MIN_WIDTH_DP = 220;
    // Pixel Launcher 측정값(2칸 108dp, 3칸 169dp)의 중간값이다.
    private static final int LARGE_MIN_HEIGHT_DP = 140;

    @Override
    public void onUpdate(
            Context context,
            AppWidgetManager appWidgetManager,
            int[] appWidgetIds
    ) {
        for (int appWidgetId : appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId);
        }
    }

    @Override
    public void onAppWidgetOptionsChanged(
            Context context,
            AppWidgetManager appWidgetManager,
            int appWidgetId,
            Bundle newOptions
    ) {
        updateWidget(context, appWidgetManager, appWidgetId);
    }

    static void updateAll(Context context) {
        AppWidgetManager manager = AppWidgetManager.getInstance(context);
        ComponentName provider = new ComponentName(context, WeatherCareWidgetProvider.class);
        int[] ids = manager.getAppWidgetIds(provider);
        for (int id : ids) updateWidget(context, manager, id);
    }

    private static void updateWidget(
            Context context,
            AppWidgetManager manager,
            int appWidgetId
    ) {
        Bundle options = manager.getAppWidgetOptions(appWidgetId);
        int minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110);
        int minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110);
        // 2열은 작은, 3열 이상은 2행에서 중간·3행 이상에서 큰 위젯으로 표시한다.
        WidgetSize size = minHeight >= LARGE_MIN_HEIGHT_DP
                && minWidth >= MEDIUM_MIN_WIDTH_DP
                ? WidgetSize.LARGE
                : minWidth >= MEDIUM_MIN_WIDTH_DP
                        ? WidgetSize.MEDIUM
                        : WidgetSize.SMALL;
        int layout = switch (size) {
            case SMALL -> R.layout.weather_widget_small;
            case MEDIUM -> R.layout.weather_widget_medium;
            case LARGE -> R.layout.weather_widget_large;
        };
        RemoteViews views = new RemoteViews(context.getPackageName(), layout);
        Snapshot snapshot = readSnapshot(context);

        bindHeader(views, snapshot);
        bindTemperature(context, views, snapshot, size);
        views.setTextViewText(R.id.widget_min_max, minMax(snapshot));
        views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context));

        if (size != WidgetSize.SMALL) {
            views.setTextViewText(R.id.widget_apparent_temperature, snapshot.apparentTemperature);
        }
        if (size == WidgetSize.MEDIUM) {
            views.setTextViewText(R.id.widget_short_message, snapshot.shortMessage);
        }
        if (size == WidgetSize.LARGE) {
            bindLargeContent(context, views, snapshot);
        }

        manager.updateAppWidget(appWidgetId, views);
    }

    private static void bindHeader(RemoteViews views, Snapshot snapshot) {
        views.setTextViewText(R.id.widget_region, snapshot.region);
        views.setTextViewText(R.id.widget_refresh_time, snapshot.refreshTime);
    }

    private static void bindTemperature(
            Context context,
            RemoteViews views,
            Snapshot snapshot,
            WidgetSize size
    ) {
        views.setTextViewText(R.id.widget_current_temperature, snapshot.currentTemperature);
        int iconSizeDp = size == WidgetSize.SMALL ? 64 : size == WidgetSize.MEDIUM ? 58 : 72;
        views.setImageViewBitmap(
                R.id.widget_weather_icon,
                WidgetIconRenderer.weather(context, snapshot.condition, iconSizeDp, false)
        );
        views.setContentDescription(
                R.id.widget_weather_icon,
                WidgetIconRenderer.weatherDescription(snapshot.condition)
        );
    }

    private static void bindLargeContent(
            Context context,
            RemoteViews views,
            Snapshot snapshot
    ) {
        views.setTextViewText(R.id.widget_brief, snapshot.brief);
        views.setTextViewText(R.id.widget_next_time, snapshot.nextTime);
        views.setTextViewText(R.id.widget_next_temperature, snapshot.nextTemperature);
        views.setImageViewBitmap(
                R.id.widget_next_icon,
                WidgetIconRenderer.weather(context, snapshot.nextCondition, 32, true)
        );
        views.setContentDescription(
                R.id.widget_next_icon,
                WidgetIconRenderer.weatherDescription(snapshot.nextCondition)
        );

        int[] slots = {R.id.widget_preparation_1, R.id.widget_preparation_2,
                R.id.widget_preparation_3};
        int[] icons = {R.id.widget_preparation_icon_1, R.id.widget_preparation_icon_2,
                R.id.widget_preparation_icon_3};
        int[] labels = {R.id.widget_preparation_label_1, R.id.widget_preparation_label_2,
                R.id.widget_preparation_label_3};
        views.setViewVisibility(
                R.id.widget_preparation_row,
                snapshot.preparations.isEmpty() ? View.GONE : View.VISIBLE
        );
        for (int index = 0; index < slots.length; index++) {
            if (index >= snapshot.preparations.size()) {
                views.setViewVisibility(slots[index], View.GONE);
                continue;
            }
            Preparation preparation = snapshot.preparations.get(index);
            views.setViewVisibility(slots[index], View.VISIBLE);
            views.setTextViewText(labels[index], preparation.label);
            views.setImageViewBitmap(
                    icons[index],
                    WidgetIconRenderer.preparation(context, preparation.type, 28)
            );
            views.setContentDescription(icons[index], preparation.label);
        }
    }

    private static CharSequence minMax(Snapshot snapshot) {
        String minimumPrefix = "최저 ";
        String divider = "   최고 ";
        SpannableStringBuilder text = new SpannableStringBuilder()
                .append(minimumPrefix)
                .append(snapshot.minimumTemperature)
                .append(divider)
                .append(snapshot.maximumTemperature);
        int minimumStart = minimumPrefix.length();
        int minimumEnd = minimumStart + snapshot.minimumTemperature.length();
        int maximumStart = minimumEnd + divider.length();
        text.setSpan(
                new StyleSpan(Typeface.BOLD),
                minimumStart,
                minimumEnd,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        );
        text.setSpan(
                new StyleSpan(Typeface.BOLD),
                maximumStart,
                text.length(),
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        );
        return text;
    }

    private static PendingIntent launchAppIntent(Context context) {
        Intent launch = context.getPackageManager()
                .getLaunchIntentForPackage(context.getPackageName());
        if (launch == null) launch = new Intent(context, MainActivity.class);
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        return PendingIntent.getActivity(
                context,
                1701,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
    }

    private static Snapshot readSnapshot(Context context) {
        SharedPreferences preferences = context.getSharedPreferences(
                MainActivity.WIDGET_PREFERENCES,
                Context.MODE_PRIVATE
        );
        String raw = preferences.getString(MainActivity.SNAPSHOT_KEY, null);
        if (raw == null) return Snapshot.empty();
        try {
            return Snapshot.fromJson(new JSONObject(raw));
        } catch (Exception ignored) {
            return Snapshot.empty();
        }
    }

    private enum WidgetSize { SMALL, MEDIUM, LARGE }

    private record Preparation(String type, String label) { }

    private static final class Snapshot {
        final String region;
        final String refreshTime;
        final String condition;
        final String currentTemperature;
        final String apparentTemperature;
        final String minimumTemperature;
        final String maximumTemperature;
        final String shortMessage;
        final String brief;
        final String nextTime;
        final String nextCondition;
        final String nextTemperature;
        final List<Preparation> preparations;

        Snapshot(
                String region,
                String refreshTime,
                String condition,
                String currentTemperature,
                String apparentTemperature,
                String minimumTemperature,
                String maximumTemperature,
                String shortMessage,
                String brief,
                String nextTime,
                String nextCondition,
                String nextTemperature,
                List<Preparation> preparations
        ) {
            this.region = region;
            this.refreshTime = refreshTime;
            this.condition = condition;
            this.currentTemperature = currentTemperature;
            this.apparentTemperature = apparentTemperature;
            this.minimumTemperature = minimumTemperature;
            this.maximumTemperature = maximumTemperature;
            this.shortMessage = shortMessage;
            this.brief = brief;
            this.nextTime = nextTime;
            this.nextCondition = nextCondition;
            this.nextTemperature = nextTemperature;
            this.preparations = preparations;
        }

        static Snapshot fromJson(JSONObject json) {
            JSONArray rawPreparations = json.optJSONArray("preparations");
            List<Preparation> preparations = new ArrayList<>();
            if (rawPreparations != null) {
                for (int index = 0; index < rawPreparations.length() && index < 3; index++) {
                    JSONObject item = rawPreparations.optJSONObject(index);
                    if (item == null) continue;
                    preparations.add(new Preparation(
                            text(item, "type", ""),
                            text(item, "label", "")
                    ));
                }
            }
            return new Snapshot(
                    text(json, "region", "지역을 설정해주세요"),
                    text(json, "refreshTime", "앱에서 갱신"),
                    text(json, "condition", "unknown"),
                    text(json, "currentTemperature", "--°"),
                    text(json, "apparentTemperature", "--°"),
                    text(json, "minimumTemperature", "--°"),
                    text(json, "maximumTemperature", "--°"),
                    text(json, "shortMessage", "날씨챙겨를 열어 최신 날씨를 확인하세요"),
                    text(json, "brief", "날씨챙겨를 열어 최신 날씨를 확인하세요."),
                    text(json, "nextTime", "예보 준비 중"),
                    text(json, "nextCondition", "unknown"),
                    text(json, "nextTemperature", "--°"),
                    preparations
            );
        }

        static Snapshot empty() {
            return fromJson(new JSONObject());
        }

        private static String text(JSONObject json, String key, String fallback) {
            String value = json.optString(key, fallback).trim();
            return value.isEmpty() ? fallback : value;
        }
    }
}
