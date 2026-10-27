package com.codesoha.weathercare;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;
import org.json.JSONObject;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.time.Instant;

public final class BackgroundLocationWorker extends Worker {
    public BackgroundLocationWorker(@NonNull Context context, @NonNull WorkerParameters params) { super(context, params); }

    @NonNull @Override public Result doWork() {
        Context context = getApplicationContext();
        JSONObject config;
        JSONObject pending;
        synchronized (BackgroundLocationManager.LOCK) {
            config = BackgroundLocationManager.read(context);
            if (config == null || !BackgroundLocationManager.permitted(context)) return Result.success();
            pending = config.optJSONObject("pending");
        }
        if (pending == null || isStopped()) return Result.success();
        HttpURLConnection connection = null;
        try {
            long age = System.currentTimeMillis() - Instant.parse(pending.getString("measuredAt")).toEpochMilli();
            if (age > 15 * 60_000 || age < -60_000) {
                finish(context, config, pending, false);
                BackgroundLocationManager.resume(context);
                return Result.success();
            }
            connection = (HttpURLConnection) new URL(config.getString("url")).openConnection();
            connection.setInstanceFollowRedirects(false);
            connection.setRequestMethod("PUT");
            connection.setConnectTimeout(8000); connection.setReadTimeout(8000);
            connection.setRequestProperty("Authorization", config.getString("authorization"));
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            if ("weather-test-api.codesoha.com".equals(connection.getURL().getHost()) && config.has("testAccessKey")) {
                connection.setRequestProperty("X-Weather-Care-Test-Key", config.getString("testAccessKey"));
            }
            connection.setDoOutput(true);
            try (var stream = connection.getOutputStream()) { stream.write(pending.toString().getBytes(StandardCharsets.UTF_8)); }
            int code = connection.getResponseCode();
            if (code >= 200 && code < 300) {
                finish(context, config, pending, true);
                BackgroundWidgetLocation.follow(context, pending, config.optString("revision"));
                return Result.success();
            }
            if (code == 401 || code == 409 || code == 410) {
                synchronized (BackgroundLocationManager.LOCK) {
                    JSONObject current = BackgroundLocationManager.read(context);
                    if (current != null && config.optString("revision").equals(current.optString("revision"))) {
                        BackgroundLocationManager.stop(context);
                    }
                }
                return Result.success();
            }
            if (code >= 400 && code < 500 && code != 429) {
                finish(context, config, pending, false);
                return Result.success();
            }
        } catch (Exception ignored) { /* Retry only the latest, unexpired sample. */ }
        finally { if (connection != null) connection.disconnect(); }
        BackgroundLocationManager.setError(context, config.optString("revision"), true);
        return Result.retry();
    }

    private void finish(Context context, JSONObject original, JSONObject sent, boolean success) throws Exception {
        synchronized (BackgroundLocationManager.LOCK) {
            JSONObject current = BackgroundLocationManager.read(context);
            if (current == null || !original.optString("revision").equals(current.optString("revision"))) return;
            JSONObject pending = current.optJSONObject("pending");
            if (pending != null && sent.optString("measuredAt").equals(pending.optString("measuredAt"))) current.remove("pending");
            current.put("error", !success);
            if (success) {
                current.put("syncedAt", Instant.now().toString());
                current.put("syncedMeasuredMillis", Math.max(current.optLong("syncedMeasuredMillis"),
                        Instant.parse(sent.getString("measuredAt")).toEpochMilli()));
            }
            BackgroundLocationManager.write(context, current);
        }
    }
}
