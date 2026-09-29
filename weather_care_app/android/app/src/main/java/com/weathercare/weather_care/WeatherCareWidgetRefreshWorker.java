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
        WeatherCareWidgetProvider.setRefreshInProgress(context, true);
        SharedPreferences preferences = context.getSharedPreferences(
                MainActivity.WIDGET_PREFERENCES,
                Context.MODE_PRIVATE
        );
        String rawUrl = preferences.getString(MainActivity.REFRESH_URL_KEY, null);
        HttpURLConnection connection = null;
        try {
            if (!isAllowedUrl(rawUrl)) return Result.failure();
            connection = (HttpURLConnection) new URL(rawUrl).openConnection();
            connection.setRequestMethod("GET");
            connection.setRequestProperty("Accept", "application/json");
            connection.setConnectTimeout(10_000);
            connection.setReadTimeout(20_000);
            connection.setUseCaches(false);
            int status = connection.getResponseCode();
            if (status < 200 || status >= 300) {
                return status >= 500 && getRunAttemptCount() < 2
                        ? Result.retry()
                        : Result.failure();
            }
            String body = readResponse(connection.getInputStream());
            body = MainActivity.preserveSpecificWidgetRegion(
                    body,
                    preferences.getString(MainActivity.SNAPSHOT_KEY, null)
            );
            JSONObject snapshot = new JSONObject(body);
            if (snapshot.optInt("schemaVersion", 0) != 3 ||
                    !snapshot.has("region") || !snapshot.has("refreshTime")) {
                return Result.failure();
            }
            preferences.edit().putString(MainActivity.SNAPSHOT_KEY, body).apply();
            return Result.success();
        } catch (Exception ignored) {
            return getRunAttemptCount() < 2 ? Result.retry() : Result.failure();
        } finally {
            if (connection != null) connection.disconnect();
            WeatherCareWidgetProvider.setRefreshInProgress(context, false);
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
