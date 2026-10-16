package com.codesoha.weathercare;

import android.content.Context;
import android.content.SharedPreferences;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Objects;

public final class WeatherCareWidgetRefreshWorker extends Worker {
    private static final int MAX_RESPONSE_CHARS = 512 * 1024;

    public WeatherCareWidgetRefreshWorker(
            @NonNull Context context,
            @NonNull WorkerParameters parameters
    ) {
        super(context, parameters);
    }

    @NonNull
    @Override
    public Result doWork() {
        Context context = getApplicationContext();
        SharedPreferences preferences = context.getSharedPreferences(
                MainActivity.WIDGET_PREFERENCES,
                Context.MODE_PRIVATE
        );
        final String rawUrl;
        final String revision;
        synchronized (MainActivity.WIDGET_LOCK) {
            rawUrl = preferences.getString(MainActivity.REFRESH_URL_KEY, null);
            revision = preferences.getString(MainActivity.REVISION_KEY, null);
            if (!isAllowedUrl(rawUrl)) return Result.success();
            WeatherCareWidgetProvider.setRefreshInProgress(context, true);
        }
        try {
            int status = refresh(context, preferences, rawUrl, revision);
            synchronized (MainActivity.WIDGET_LOCK) {
                if (!isCurrentSelection(preferences, rawUrl, revision) ||
                        (status >= 200 && status < 300)) return Result.success();
                WeatherCareWidgetProvider.setRefreshStatus(context, "서버 연결 실패");
                return Result.failure();
            }
        } catch (Exception ignored) {
            synchronized (MainActivity.WIDGET_LOCK) {
                if (!isCurrentSelection(preferences, rawUrl, revision)) return Result.success();
                WeatherCareWidgetProvider.setRefreshStatus(context, "서버 연결 실패");
                return Result.failure();
            }
        } finally {
            synchronized (MainActivity.WIDGET_LOCK) {
                if (isCurrentSelection(preferences, rawUrl, revision)) {
                    WeatherCareWidgetProvider.setRefreshInProgress(context, false);
                }
            }
        }
    }

    private static boolean isCurrentSelection(
            SharedPreferences preferences, String rawUrl, String revision
    ) {
        return Objects.equals(revision, preferences.getString(MainActivity.REVISION_KEY, null)) &&
                Objects.equals(rawUrl, preferences.getString(MainActivity.REFRESH_URL_KEY, null));
    }

    private static int refresh(
            Context context, SharedPreferences preferences, String rawUrl, String revision
    ) throws Exception {
        if (!isAllowedUrl(rawUrl)) throw new IOException("Invalid widget refresh URL");
        HttpURLConnection connection = (HttpURLConnection) new URL(rawUrl).openConnection();
        try {
            connection.setRequestMethod("GET");
            connection.setRequestProperty("Accept", "application/json");
            connection.setConnectTimeout(10_000);
            connection.setReadTimeout(20_000);
            connection.setUseCaches(false);
            int status = connection.getResponseCode();
            if (status < 200 || status >= 300) return status;
            String body = readResponse(connection.getInputStream());
            JSONObject snapshot = new JSONObject(body);
            if (snapshot.optInt("schemaVersion", 0) != 3 ||
                    !snapshot.has("region") || !snapshot.has("refreshTime")) {
                throw new IOException("Invalid widget snapshot");
            }
            snapshot.put("receivedAt", Instant.now().toString());
            synchronized (MainActivity.WIDGET_LOCK) {
                // 구역 전환/삭제/앱 갱신 전의 늦은 응답은 저장하지 않는다.
                if (!isCurrentSelection(preferences, rawUrl, revision)) return status;
                String selectedSnapshot = MainActivity.preserveSpecificWidgetRegion(
                        snapshot.toString(),
                        preferences.getString(MainActivity.SNAPSHOT_KEY, null));
                preferences.edit()
                        .putString(MainActivity.SNAPSHOT_KEY, selectedSnapshot)
                        .remove(WeatherCareWidgetProvider.REFRESH_STATUS_KEY)
                        .apply();
            }
            return status;
        } finally {
            connection.disconnect();
        }
    }

    private static boolean isAllowedUrl(String rawUrl) {
        if (rawUrl == null || rawUrl.isBlank()) return false;
        Uri uri = Uri.parse(rawUrl);
        String scheme = uri.getScheme();
        return uri.getHost() != null &&
                ("https".equalsIgnoreCase(scheme) || "http".equalsIgnoreCase(scheme));
    }

    private static String readResponse(InputStream input) throws IOException {
        StringBuilder result = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(input, StandardCharsets.UTF_8))) {
            char[] buffer = new char[4096];
            int count;
            while ((count = reader.read(buffer)) >= 0) {
                if (result.length() + count > MAX_RESPONSE_CHARS) {
                    throw new IOException("Widget response is too large");
                }
                result.append(buffer, 0, count);
            }
        }
        return result.toString();
    }
}
