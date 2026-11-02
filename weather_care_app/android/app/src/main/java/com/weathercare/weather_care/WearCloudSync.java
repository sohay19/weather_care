package com.codesoha.weathercare;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import com.codesoha.weathercare.wearbridge.WearCloudHttp;
import io.flutter.plugin.common.MethodChannel;
import org.json.JSONObject;
import java.util.concurrent.Executors;

/** 서버 연결 토큰은 설치 인증과 분리하며 백업하지 않는 앱 전용 저장소에 보관한다. */
final class WearCloudSync {
    private static final java.util.concurrent.ExecutorService IO = Executors.newSingleThreadExecutor();
    private static SharedPreferences saved(Context context) { return context.getSharedPreferences("weather_care_cloud_link", Context.MODE_PRIVATE); }
    static boolean isLinked(Context context) { return saved(context).getBoolean("linked", false); }

    static void handle(Activity activity, String method, Object arguments, MethodChannel.Result result) {
        IO.execute(() -> { synchronized (WearCloudSync.class) {
            try {
                SharedPreferences preferences = saved(activity);
                String token = preferences.getString("token", "");
                JSONObject response;
                if ("wearClaim".equals(method)) {
                    String code = String.valueOf(arguments).replaceAll("[\\s-]", "").toUpperCase(java.util.Locale.ROOT);
                    if (!code.matches("[A-HJ-NP-Z2-9]{8}")) throw new IllegalArgumentException("WEAR_INVALID_CODE");
                    if (preferences.getBoolean("linked", false)) throw new IllegalArgumentException("WEAR_ALREADY_LINKED");
                    if (!code.equals(preferences.getString("pending_code", "")) || token.isEmpty()) token = WearCloudHttp.newToken();
                    if (!preferences.edit().putString("token", token).putString("pending_code", code).commit()) throw new java.io.IOException();
                    response = WearCloudHttp.request("POST", "claim", token, new JSONObject().put("code", code));
                    if (!preferences.edit().putBoolean("linked", true).remove("pending_code").commit()) throw new java.io.IOException();
                    WearPhoneSync.sendLatest(activity);
                } else if ("wearUnlink".equals(method)) {
                    if (!token.isEmpty()) WearCloudHttp.request("DELETE", "link", token, null);
                    preferences.edit().clear().commit();
                    WearCloudRefreshWorker.cancel(activity);
                    response = new JSONObject().put("linked", false);
                } else if ("wearSend".equals(method)) {
                    WearCloudRefreshWorker.refresh(activity);
                    response = new JSONObject().put("linked", isLinked(activity));
                } else if (token.isEmpty()) {
                    response = new JSONObject().put("linked", false);
                } else {
                    try {
                        response = WearCloudHttp.request("GET", "status", token, null);
                        preferences.edit().putBoolean("linked", response.optBoolean("linked")).apply();
                    } catch (WearCloudHttp.Failure error) {
                        if (error.status != 404) throw error;
                        preferences.edit().clear().commit();
                        WearCloudRefreshWorker.cancel(activity);
                        response = new JSONObject().put("linked", false);
                    }
                }
                if (isLinked(activity)) WearCloudRefreshWorker.schedule(activity);
                String raw = response.toString();
                activity.runOnUiThread(() -> result.success(raw));
            } catch (Exception error) {
                String code = error instanceof WearCloudHttp.Failure failure ? failure.code :
                        error instanceof IllegalArgumentException ? error.getMessage() : "WEAR_NETWORK_ERROR";
                activity.runOnUiThread(() -> result.error(code, "워치 연결을 확인해 주세요.", null));
            }
        } });
    }

    static boolean publish(Context context, String payload) {
        final String token;
        synchronized (WearCloudSync.class) {
            if (!isLinked(context)) return true;
            token = saved(context).getString("token", "");
            WearCloudRefreshWorker.schedule(context);
        }
        try {
            WearCloudHttp.request("PUT", "snapshot", token, new JSONObject(payload));
            return true;
        } catch (WearCloudHttp.Failure error) {
            if (error.status == 404) {
                synchronized (WearCloudSync.class) {
                    if (token.equals(saved(context).getString("token", ""))) {
                        saved(context).edit().clear().commit();
                        WearCloudRefreshWorker.cancel(context);
                    }
                }
                return true;
            }
            return error.status == 409; // 더 새 자료가 먼저 도착한 경우.
        } catch (Exception ignored) { return false; }
    }
}
