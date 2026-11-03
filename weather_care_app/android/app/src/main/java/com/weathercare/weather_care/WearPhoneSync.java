package com.codesoha.weathercare;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;
import com.codesoha.weathercare.wearbridge.WearContract;
import com.google.android.gms.tasks.Tasks;
import com.google.android.gms.wearable.PutDataMapRequest;
import com.google.android.gms.wearable.Wearable;
import org.json.JSONObject;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;

/** 폰의 채택된 자료만 발행한다. 실패 시 최신 payload를 보관하고 재연결 때 재전송한다. */
final class WearPhoneSync {
    private static final ExecutorService IO = Executors.newSingleThreadExecutor();
    private static final String PREFS = "weather_care_wear_sync";
    private WearPhoneSync() { }

    static synchronized void publish(Context context, String snapshot, JSONObject details) {
        Context app = context.getApplicationContext();
        try {
            SharedPreferences saved = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            JSONObject widget = snapshot == null ? new JSONObject() : new JSONObject(snapshot);
            JSONObject payload = new JSONObject().put("schemaVersion", 1)
                    .put("revision", saved.getLong("revision", 0) + 1)
                    .put("publishedAt", Math.max(System.currentTimeMillis(), saved.getLong("publishedAt", 0) + 1))
                    .put("widget", widget).put("cleared", snapshot == null);
            if (details != null) payload.put("details", details);
            String raw = payload.toString();
            if (raw.getBytes(StandardCharsets.UTF_8).length > WearContract.MAX_BYTES) return;
            saved.edit().putLong("revision", payload.getLong("revision"))
                    .putLong("publishedAt", payload.getLong("publishedAt"))
                    .putString("payload", raw).apply();
            sendLatest(app);
        } catch (Exception error) { Log.w("WeatherCareWear", "snapshot preparation failed", error); }
    }

    static void sendLatest(Context context) {
        Context app = context.getApplicationContext();
        IO.execute(() -> {
            String raw = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("payload", null);
            if (raw == null) return;
            try {
                PutDataMapRequest request = PutDataMapRequest.create(WearContract.SNAPSHOT_PATH);
                request.getDataMap().putString(WearContract.PAYLOAD_KEY, raw);
                Tasks.await(Wearable.getDataClient(app).putDataItem(request.asPutDataRequest().setUrgent()), 15, TimeUnit.SECONDS);
            } catch (Exception error) { Log.w("WeatherCareWear", "snapshot pending until reconnect", error); }
        });
    }

    static void publishFromBackground(Context context, String snapshot, String rawUrl, String key, String selection) {
        Context app = context.getApplicationContext();
        // 기본 기온·지역은 먼저 보내고 상세 조회가 기존 폰 위젯 갱신을 지연하지 않게 한다.
        publish(app, snapshot, null);
        IO.execute(() -> {
            try {
                if (Tasks.await(Wearable.getNodeClient(app).getConnectedNodes(), 5, TimeUnit.SECONDS).isEmpty()) return;
                JSONObject details = WearDetailsLoader.load(rawUrl, key);
                synchronized (MainActivity.WIDGET_LOCK) {
                    var saved = app.getSharedPreferences(MainActivity.WIDGET_PREFERENCES, Context.MODE_PRIVATE);
                    if (!java.util.Objects.equals(selection, saved.getString(MainActivity.REVISION_KEY, null)) ||
                            !snapshot.equals(saved.getString(MainActivity.SNAPSHOT_KEY, null))) return;
                    publish(app, snapshot, details);
                }
            } catch (Exception error) { Log.w("WeatherCareWear", "details unavailable; base weather retained", error); }
        });
    }
}
