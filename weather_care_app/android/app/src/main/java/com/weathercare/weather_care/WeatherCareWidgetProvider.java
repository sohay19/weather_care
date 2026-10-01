package com.codesoha.weathercare;

import android.Manifest;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.os.Bundle;
import android.view.View;
import android.widget.RemoteViews;

import androidx.work.Constraints;
import androidx.work.ExistingWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.time.Instant;
import java.time.format.DateTimeParseException;

public class WeatherCareWidgetProvider extends AppWidgetProvider {
    private static final String ACTION_BRIEFING_BOUNDARY =
            "com.codesoha.weathercare.BRIEFING_BOUNDARY";
    private static final String ACTION_REFRESH =
            "com.codesoha.weathercare.REFRESH_WIDGET";
    static final String REFRESH_IN_PROGRESS_KEY = "refresh_in_progress";
    private static final int BRIEFING_ALARM_REQUEST = 1702;
    private static final int REFRESH_REQUEST = 1703;
    // Pixel Launcher 4열 구성의 2열 위젯(약 179dp)을 작은 위젯에 포함한다.
    private static final int MEDIUM_MIN_WIDTH_DP = 200;
    private static final int TEXT_PRIMARY = Color.rgb(37, 55, 78);
    private static final int TEXT_SECONDARY = Color.rgb(96, 117, 138);
    private static final int TEXT_MIN_MAX = Color.rgb(66, 90, 114);
    // Pixel Launcher 측정값(2칸 108dp, 3칸 169dp)의 중간값이다.
    private static final int LARGE_MIN_HEIGHT_DP = 140;

    @Override
    public void onReceive(Context context, Intent intent) {
        if (ACTION_BRIEFING_BOUNDARY.equals(intent.getAction())) {
            updateAll(context);
            return;
        }
        if (ACTION_REFRESH.equals(intent.getAction())) {
            if (gpsEnabled(context)) {
                if (context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                        != PackageManager.PERMISSION_GRANTED &&
                        context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                                != PackageManager.PERMISSION_GRANTED) {
                    showLocationUnavailable(context);
                    return;
                }
                try {
                    context.startForegroundService(new Intent(
                            context, WeatherCareWidgetRefreshService.class
                    ));
                } catch (RuntimeException ignored) {
                    showLocationUnavailable(context);
                }
            } else {
                enqueueRefresh(context);
            }
            return;
        }
        super.onReceive(context, intent);
    }

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
        WidgetSize size = widgetSizeFor(minWidth, minHeight);
        int layout = switch (size) {
            case SMALL -> R.layout.weather_widget_small;
            case MEDIUM -> R.layout.weather_widget_medium;
            case LARGE -> R.layout.weather_widget_large;
        };
        RemoteViews views = new RemoteViews(context.getPackageName(), layout);
        Snapshot stored = readSnapshot(context);
        long now = System.currentTimeMillis();
        Snapshot snapshot = stored.forTime(now);

        bindHeader(context, views, snapshot, size, minWidth);
        bindTemperature(context, views, snapshot, size, minWidth);
        bindMinMax(context, views, snapshot, size);
        views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context));
        boolean refreshing = isRefreshInProgress(context);
        views.setInt(
                R.id.widget_refresh_button,
                "setBackgroundResource",
                refreshing
                        ? R.drawable.weather_widget_refresh_background_loading
                        : R.drawable.weather_widget_refresh_background
        );
        views.setImageViewResource(
                R.id.widget_refresh_button,
                refreshing ? R.drawable.ic_widget_refresh_loading : R.drawable.ic_widget_refresh
        );
        views.setBoolean(R.id.widget_refresh_button, "setEnabled", !refreshing);
        if (hasRefreshUrl(context)) {
            views.setViewVisibility(R.id.widget_refresh_button, View.VISIBLE);
            views.setOnClickPendingIntent(
                    R.id.widget_refresh_button,
                    refreshIntent(context)
            );
        } else {
            views.setViewVisibility(R.id.widget_refresh_button, View.GONE);
        }

        if (size == WidgetSize.MEDIUM) {
            setTextBitmap(
                    views,
                    R.id.widget_short_message,
                    WidgetTextRenderer.line(
                            context,
                            snapshot.shortMessage,
                            R.font.suite_extra_bold,
                            13,
                            TEXT_PRIMARY,
                            180
                    ),
                    snapshot.shortMessage
            );
        }
        if (size == WidgetSize.LARGE) {
            bindLargeContent(context, views, snapshot, minWidth);
        }

        manager.updateAppWidget(appWidgetId, views);
        scheduleBriefingBoundary(context, stored.nextBoundaryAfter(now));
    }

    private static WidgetSize widgetSizeFor(int minWidth, int minHeight) {
        // Android 가로 2열은 높이와 관계없이 iOS systemSmall처럼 처리한다.
        if (minWidth < MEDIUM_MIN_WIDTH_DP) return WidgetSize.SMALL;
        return minHeight >= LARGE_MIN_HEIGHT_DP ? WidgetSize.LARGE : WidgetSize.MEDIUM;
    }

    private static PendingIntent refreshIntent(Context context) {
        Intent intent = new Intent(context, WeatherCareWidgetProvider.class)
                .setAction(ACTION_REFRESH)
                .addFlags(Intent.FLAG_RECEIVER_FOREGROUND);
        return PendingIntent.getBroadcast(
                context,
                REFRESH_REQUEST,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
    }

    private static boolean hasRefreshUrl(Context context) {
        String url = context.getSharedPreferences(
                MainActivity.WIDGET_PREFERENCES,
                Context.MODE_PRIVATE
        ).getString(MainActivity.REFRESH_URL_KEY, null);
        return url != null && !url.isBlank();
    }

    private static boolean gpsEnabled(Context context) {
        return context.getSharedPreferences(
                MainActivity.WIDGET_PREFERENCES,
                Context.MODE_PRIVATE
        ).getBoolean(MainActivity.GPS_ENABLED_KEY, false);
    }

    static void showLocationUnavailable(Context context) {
        SharedPreferences preferences = context.getSharedPreferences(
                MainActivity.WIDGET_PREFERENCES,
                Context.MODE_PRIVATE
        );
        try {
            JSONObject snapshot = new JSONObject(
                    preferences.getString(MainActivity.SNAPSHOT_KEY, "{}")
            );
            if (!snapshot.has("region")) return;
            snapshot.put("refreshTime", "위치 확인 필요");
            preferences.edit().putString(MainActivity.SNAPSHOT_KEY, snapshot.toString()).apply();
            updateAll(context);
        } catch (Exception ignored) {
            // The app will publish a fresh snapshot when it next opens.
        }
    }

    private static boolean isRefreshInProgress(Context context) {
        return context.getSharedPreferences(
                MainActivity.WIDGET_PREFERENCES,
                Context.MODE_PRIVATE
        ).getBoolean(REFRESH_IN_PROGRESS_KEY, false);
    }

    static void setRefreshInProgress(Context context, boolean refreshing) {
        context.getSharedPreferences(
                MainActivity.WIDGET_PREFERENCES,
                Context.MODE_PRIVATE
        ).edit().putBoolean(REFRESH_IN_PROGRESS_KEY, refreshing).apply();
        updateAll(context);
    }

    private static void enqueueRefresh(Context context) {
        Constraints constraints = new Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build();
        OneTimeWorkRequest request = new OneTimeWorkRequest.Builder(
                WeatherCareWidgetRefreshWorker.class
        ).setConstraints(constraints).build();
        WorkManager.getInstance(context).enqueueUniqueWork(
                "weather-care-widget-refresh",
                ExistingWorkPolicy.REPLACE,
                request
        );
    }

    private static void scheduleBriefingBoundary(Context context, long boundary) {
        AlarmManager alarmManager = context.getSystemService(AlarmManager.class);
        if (alarmManager == null) return;
        PendingIntent pending = PendingIntent.getBroadcast(
                context,
                BRIEFING_ALARM_REQUEST,
                new Intent(context, WeatherCareWidgetProvider.class)
                        .setAction(ACTION_BRIEFING_BOUNDARY),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        alarmManager.cancel(pending);
        if (boundary > System.currentTimeMillis()) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, boundary, pending);
        }
    }

    private static void bindHeader(
            Context context,
            RemoteViews views,
            Snapshot snapshot,
            WidgetSize size,
            int minWidth
    ) {
        float regionSize = size == WidgetSize.SMALL ? 12 : size == WidgetSize.MEDIUM ? 13 : 14;
        int horizontalPadding = size == WidgetSize.SMALL ? 28
                : size == WidgetSize.MEDIUM ? 32 : 36;
        int regionWidth = Math.max(1, minWidth - horizontalPadding - 32);
        float refreshSize = size == WidgetSize.SMALL ? 9 : size == WidgetSize.MEDIUM ? 10 : 11;
        int refreshWidth = size == WidgetSize.SMALL ? 78 : size == WidgetSize.MEDIUM ? 90 : 100;
        setTextBitmap(
                views,
                R.id.widget_region,
                WidgetTextRenderer.paragraph(
                        context,
                        snapshot.region,
                        R.font.suite_extra_bold,
                        regionSize,
                        TEXT_PRIMARY,
                        regionWidth,
                        size == WidgetSize.SMALL ? 3 : 2,
                        1,
                        0
                ),
                snapshot.region
        );
        setTextBitmap(
                views,
                R.id.widget_refresh_time,
                WidgetTextRenderer.line(
                        context,
                        snapshot.refreshTime,
                        R.font.suite_regular,
                        refreshSize,
                        TEXT_SECONDARY,
                        refreshWidth
                ),
                snapshot.refreshTime
        );
    }

    private static void bindTemperature(
            Context context,
            RemoteViews views,
            Snapshot snapshot,
            WidgetSize size,
            int minWidth
    ) {
        TemperatureSizing sizing = temperatureSizing(context, snapshot, size, minWidth);
        setTextBitmap(
                views,
                R.id.widget_current_temperature,
                WidgetTextRenderer.line(
                        context,
                        snapshot.currentTemperature,
                        R.font.suite_heavy,
                        sizing.textSizeDp,
                        TEXT_PRIMARY,
                        sizing.currentWidthDp
                ),
                snapshot.currentTemperature
        );
        if (size != WidgetSize.SMALL) {
            float labelSize = size == WidgetSize.MEDIUM ? 10 : 11;
            setTextBitmap(
                    views,
                    R.id.widget_current_label,
                    WidgetTextRenderer.line(
                            context,
                            "현재",
                            R.font.suite_regular,
                            labelSize,
                            TEXT_SECONDARY,
                            40
                    ),
                    "현재"
            );
            setTextBitmap(
                    views,
                    R.id.widget_apparent_label,
                    WidgetTextRenderer.line(
                            context,
                            "체감",
                            R.font.suite_regular,
                            labelSize,
                            TEXT_SECONDARY,
                            40
                    ),
                    "체감"
            );
            setTextBitmap(
                    views,
                    R.id.widget_apparent_temperature,
                    WidgetTextRenderer.line(
                            context,
                            snapshot.apparentTemperature,
                            R.font.suite_heavy,
                            sizing.textSizeDp,
                            TEXT_PRIMARY,
                            sizing.apparentWidthDp
                    ),
                    snapshot.apparentTemperature
            );
        }
        views.setImageViewBitmap(
                R.id.widget_weather_icon,
                WidgetIconRenderer.weather(context, snapshot.condition, sizing.iconSizeDp, false)
        );
        views.setContentDescription(
                R.id.widget_weather_icon,
                WidgetIconRenderer.weatherDescription(snapshot.condition)
        );
    }

    private static TemperatureSizing temperatureSizing(
            Context context,
            Snapshot snapshot,
            WidgetSize size,
            int minWidth
    ) {
        // 각 레이아웃의 루트 좌우 패딩과 온도 행에서 아이콘 외에 고정으로 쓰는 간격이다.
        int horizontalPadding = size == WidgetSize.SMALL ? 28
                : size == WidgetSize.MEDIUM ? 32 : 36;
        int fixedRowWidth = size == WidgetSize.SMALL ? 10
                : size == WidgetSize.MEDIUM ? 45 : 51;
        int iconSize = size == WidgetSize.SMALL ? 64
                : size == WidgetSize.MEDIUM ? 58 : 72;
        float textSize = size == WidgetSize.MEDIUM ? 34 : 38;
        int availableWidth = Math.max(1, minWidth - horizontalPadding);

        while (temperatureRowWidth(context, snapshot, size, iconSize, textSize,
                fixedRowWidth) > availableWidth
                && (iconSize > 24 || textSize > 16)) {
            if (iconSize > 24) iconSize--;
            if (textSize > 16) textSize -= 0.5f;
        }

        int currentWidth = Math.max(1, (int) Math.ceil(
                WidgetTextRenderer.lineWidthDp(
                        context,
                        snapshot.currentTemperature,
                        R.font.suite_heavy,
                        textSize
                )
        ));
        int apparentWidth = size == WidgetSize.SMALL ? 1 : Math.max(1, (int) Math.ceil(
                WidgetTextRenderer.lineWidthDp(
                        context,
                        snapshot.apparentTemperature,
                        R.font.suite_heavy,
                        textSize
                )
        ));
        return new TemperatureSizing(textSize, iconSize, currentWidth, apparentWidth);
    }

    private static float temperatureRowWidth(
            Context context,
            Snapshot snapshot,
            WidgetSize size,
            int iconSize,
            float textSize,
            int fixedRowWidth
    ) {
        float currentWidth = WidgetTextRenderer.lineWidthDp(
                context,
                snapshot.currentTemperature,
                R.font.suite_heavy,
                textSize
        );
        if (size == WidgetSize.SMALL) {
            return fixedRowWidth + iconSize + currentWidth;
        }

        float labelSize = size == WidgetSize.MEDIUM ? 10 : 11;
        currentWidth = Math.max(
                currentWidth,
                WidgetTextRenderer.lineWidthDp(
                        context,
                        "현재",
                        R.font.suite_regular,
                        labelSize
                )
        );
        float apparentWidth = Math.max(
                WidgetTextRenderer.lineWidthDp(
                        context,
                        snapshot.apparentTemperature,
                        R.font.suite_heavy,
                        textSize
                ),
                WidgetTextRenderer.lineWidthDp(
                        context,
                        "체감",
                        R.font.suite_regular,
                        labelSize
                )
        );
        return fixedRowWidth + iconSize + currentWidth + apparentWidth;
    }

    private static void bindLargeContent(
            Context context,
            RemoteViews views,
            Snapshot snapshot,
            int minWidth
    ) {
        int contentWidth = Math.max(180, minWidth - 72);
        setTextBitmap(
                views,
                R.id.widget_brief,
                WidgetTextRenderer.paragraph(
                        context,
                        snapshot.brief,
                        R.font.suite_extra_bold,
                        14,
                        TEXT_PRIMARY,
                        contentWidth,
                        2,
                        2,
                        2
                ),
                snapshot.brief
        );
        setTextBitmap(
                views,
                R.id.widget_next_title,
                WidgetTextRenderer.line(
                        context,
                        "다음 시간 예보",
                        R.font.suite_extra_bold,
                        12,
                        TEXT_PRIMARY,
                        100
                ),
                "다음 시간 예보"
        );
        setTextBitmap(
                views,
                R.id.widget_next_time,
                WidgetTextRenderer.line(
                        context,
                        snapshot.nextTime,
                        R.font.suite_regular,
                        12,
                        TEXT_PRIMARY,
                        100
                ),
                snapshot.nextTime
        );
        setTextBitmap(
                views,
                R.id.widget_next_temperature,
                WidgetTextRenderer.line(
                        context,
                        snapshot.nextTemperature,
                        R.font.suite_heavy,
                        17,
                        TEXT_PRIMARY,
                        60
                ),
                snapshot.nextTemperature
        );
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
            setTextBitmap(
                    views,
                    labels[index],
                    WidgetTextRenderer.line(
                            context,
                            preparation.label,
                            R.font.suite_extra_bold,
                            12,
                            TEXT_PRIMARY,
                            90
                    ),
                    preparation.label
            );
            views.setImageViewBitmap(
                    icons[index],
                    WidgetIconRenderer.preparation(context, preparation.type, 36)
            );
            views.setContentDescription(icons[index], preparation.label);
        }
    }

    private static void bindMinMax(
            Context context,
            RemoteViews views,
            Snapshot snapshot,
            WidgetSize size
    ) {
        String minimumPrefix = "최저 ";
        String divider = "   최고 ";
        String description = minimumPrefix + snapshot.minimumTemperature
                + divider + snapshot.maximumTemperature;
        float textSize = size == WidgetSize.MEDIUM ? 12 : 13;
        int maxWidth = size == WidgetSize.MEDIUM ? 160 : 190;
        setTextBitmap(
                views,
                R.id.widget_min_max,
                WidgetTextRenderer.mixedLine(
                        context,
                        textSize,
                        TEXT_MIN_MAX,
                        maxWidth,
                        WidgetTextRenderer.part(minimumPrefix, R.font.suite_regular),
                        WidgetTextRenderer.part(
                                snapshot.minimumTemperature,
                                R.font.suite_extra_bold
                        ),
                        WidgetTextRenderer.part(divider, R.font.suite_regular),
                        WidgetTextRenderer.part(
                                snapshot.maximumTemperature,
                                R.font.suite_extra_bold
                        )
                ),
                description
        );
    }

    private static void setTextBitmap(
            RemoteViews views,
            int viewId,
            Bitmap bitmap,
            String contentDescription
    ) {
        views.setImageViewBitmap(viewId, bitmap);
        views.setContentDescription(viewId, contentDescription);
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

    private record TemperatureSizing(
            float textSizeDp,
            int iconSizeDp,
            int currentWidthDp,
            int apparentWidthDp
    ) { }

    private record Preparation(String type, String label) { }

    private record BriefingEntry(
            String briefingId,
            String sceneId,
            long validFrom,
            long validUntil,
            String shortMessage,
            String longMessage,
            Set<String> recommendedItems
    ) {
        boolean activeAt(long now) {
            return validFrom <= now && now < validUntil;
        }

        static BriefingEntry fromJson(JSONObject json) {
            JSONArray rawItems = json.optJSONArray("recommendedItems");
            Set<String> items = new HashSet<>();
            if (rawItems != null) {
                for (int index = 0; index < rawItems.length(); index++) {
                    String item = rawItems.optString(index, "").trim();
                    if (!item.isEmpty()) items.add(item);
                }
            }
            return new BriefingEntry(
                    Snapshot.text(json, "briefingId", ""),
                    Snapshot.text(json, "sceneId", "UNAVAILABLE"),
                    instant(json.optString("validFrom", "")),
                    instant(json.optString("validUntil", "")),
                    Snapshot.text(json, "shortMessage", "최신 날씨를 확인해 주세요."),
                    Snapshot.text(json, "longMessage", "최신 날씨를 확인해 주세요."),
                    items
            );
        }
    }

    private static final class Snapshot {
        final String briefingId;
        final String sceneId;
        final long validFrom;
        final long validUntil;
        final long nextBriefingBoundary;
        final long dataFreshUntil;
        final List<BriefingEntry> briefingTimeline;
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
                String briefingId,
                String sceneId,
                long validFrom,
                long validUntil,
                long nextBriefingBoundary,
                long dataFreshUntil,
                List<BriefingEntry> briefingTimeline,
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
            this.briefingId = briefingId;
            this.sceneId = sceneId;
            this.validFrom = validFrom;
            this.validUntil = validUntil;
            this.nextBriefingBoundary = nextBriefingBoundary;
            this.dataFreshUntil = dataFreshUntil;
            this.briefingTimeline = briefingTimeline;
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
            JSONArray rawTimeline = json.optJSONArray("briefingTimeline");
            List<BriefingEntry> timeline = new ArrayList<>();
            if (rawTimeline != null) {
                for (int index = 0; index < rawTimeline.length(); index++) {
                    JSONObject item = rawTimeline.optJSONObject(index);
                    if (item == null) continue;
                    BriefingEntry entry = BriefingEntry.fromJson(item);
                    if (entry.validFrom() > 0 && entry.validUntil() > entry.validFrom()) {
                        timeline.add(entry);
                    }
                }
            }
            JSONArray rawPreparations = json.optJSONArray("preparationCatalog");
            if (rawPreparations == null) {
                rawPreparations = json.optJSONArray("preparations");
            }
            List<Preparation> preparations = new ArrayList<>();
            if (rawPreparations != null) {
                for (int index = 0; index < rawPreparations.length(); index++) {
                    JSONObject item = rawPreparations.optJSONObject(index);
                    if (item == null) continue;
                    preparations.add(new Preparation(
                            text(item, "type", ""),
                            text(item, "label", "")
                    ));
                }
            }
            return new Snapshot(
                    text(json, "briefingId", ""),
                    text(json, "sceneId", "UNAVAILABLE"),
                    instant(json.optString("validFrom", "")),
                    instant(json.optString("validUntil", "")),
                    instant(json.optString("nextBriefingBoundary", "")),
                    instant(json.optString("dataFreshUntil", "")),
                    timeline,
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

        Snapshot forTime(long now) {
            BriefingEntry active = null;
            for (BriefingEntry entry : briefingTimeline) {
                if (entry.activeAt(now)) {
                    active = entry;
                    break;
                }
            }
            if (briefingTimeline.isEmpty()) {
                boolean valid = validUntil <= 0 || now < validUntil;
                return valid ? this : withBriefing(
                        "", "UNAVAILABLE", "최신 날씨를 확인해 주세요.",
                        "최신 날씨를 확인해 주세요.", List.of()
                );
            }
            if (active == null || dataFreshUntil > 0 && now >= dataFreshUntil) {
                return withBriefing(
                        "", "UNAVAILABLE", "최신 날씨를 확인해 주세요.",
                        "최신 날씨를 확인해 주세요.", List.of()
                );
            }
            BriefingEntry selected = active;
            List<Preparation> matching = new ArrayList<>();
            for (Preparation item : preparations) {
                if (selected.recommendedItems().contains(item.type())) {
                    matching.add(item);
                    if (matching.size() == 3) break;
                }
            }
            return withBriefing(
                    active.briefingId(),
                    active.sceneId(),
                    active.shortMessage(),
                    active.longMessage(),
                    matching
            );
        }

        long nextBoundaryAfter(long now) {
            long closest = Long.MAX_VALUE;
            for (BriefingEntry entry : briefingTimeline) {
                if (entry.validFrom() > now) closest = Math.min(closest, entry.validFrom());
                if (entry.validUntil() > now) closest = Math.min(closest, entry.validUntil());
            }
            if (nextBriefingBoundary > now) {
                closest = Math.min(closest, nextBriefingBoundary);
            }
            if (dataFreshUntil > now) closest = Math.min(closest, dataFreshUntil);
            return closest == Long.MAX_VALUE ? 0 : closest;
        }

        private Snapshot withBriefing(
                String briefingId,
                String sceneId,
                String shortMessage,
                String brief,
                List<Preparation> preparations
        ) {
            return new Snapshot(
                    briefingId,
                    sceneId,
                    validFrom,
                    validUntil,
                    nextBriefingBoundary,
                    dataFreshUntil,
                    briefingTimeline,
                    region,
                    refreshTime,
                    condition,
                    currentTemperature,
                    apparentTemperature,
                    minimumTemperature,
                    maximumTemperature,
                    shortMessage,
                    brief,
                    nextTime,
                    nextCondition,
                    nextTemperature,
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

    private static long instant(String value) {
        try {
            return Instant.parse(value).toEpochMilli();
        } catch (DateTimeParseException ignored) {
            return 0;
        }
    }
}
