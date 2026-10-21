package com.codesoha.weathercare;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;
import android.os.Handler;
import android.os.Looper;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.tasks.CancellationTokenSource;
import java.util.concurrent.TimeUnit;
import org.json.JSONObject;

/** Opt-in foreground monitoring requests its own GPS fixes. */
public final class BackgroundLocationService extends Service {
    static final String CHANNEL = "weather_care_background_location";
    private static final int NOTIFICATION = 1731;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable sample = this::sampleLocation;
    private CancellationTokenSource measurement;
    private String sessionRevision;

    @Override public IBinder onBind(Intent intent) { return null; }

    static void ensureNotificationChannel(Context context) {
        // Keep the channel ID so a user's hidden notification stays hidden.
        NotificationChannel channel = new NotificationChannel(
                CHANNEL, "백그라운드 위치 갱신", NotificationManager.IMPORTANCE_LOW);
        channel.setDescription("백그라운드 위치 갱신의 실행 알림이에요. 이 알림만 꺼도 위치 갱신은 유지돼요.");
        context.getSystemService(NotificationManager.class).createNotificationChannel(channel);
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        JSONObject config;
        synchronized (BackgroundLocationManager.LOCK) { config = BackgroundLocationManager.read(this); }
        if (config == null || !BackgroundLocationManager.permitted(this)) {
            stopSelf();
            return START_NOT_STICKY;
        }
        try {
            ensureNotificationChannel(this);
            PendingIntent open = PendingIntent.getActivity(this, 1731,
                    new Intent(this, MainActivity.class), PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            String message = "현재 위치·날씨 알림 지역·홈 위젯을 갱신해요.\n해당 기능은 설정에서 끌 수 있어요.";
            Notification notification = new Notification.Builder(this, CHANNEL)
                    .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                    .setContentTitle("백그라운드에서 위치 갱신 중")
                    .setContentText(message)
                    .setStyle(new Notification.BigTextStyle().bigText(message))
                    .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
                    .setCategory(Notification.CATEGORY_SERVICE).build();
            if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION);
            else startForeground(NOTIFICATION, notification);
            BackgroundLocationManager.register(this);
            if (!config.optString("revision").equals(sessionRevision)) {
                cancelMeasurement();
                sessionRevision = config.optString("revision");
                sampleLocation();
            }
            return START_STICKY;
        } catch (RuntimeException error) {
            BackgroundLocationManager.setError(this, config.optString("revision"), true);
            stopSelf();
            return START_NOT_STICKY;
        }
    }

    private void sampleLocation() {
        if (!BackgroundLocationManager.permitted(this)) { stopSelf(); return; }
        JSONObject config;
        synchronized (BackgroundLocationManager.LOCK) { config = BackgroundLocationManager.read(this); }
        if (config == null) { stopSelf(); return; }
        String revision = config.optString("revision");
        CancellationTokenSource token = new CancellationTokenSource();
        measurement = token;
        try {
            LocationServices.getFusedLocationProviderClient(this)
                    .getCurrentLocation(BackgroundLocationManager.freshLocationRequest(), token.getToken())
                    .addOnSuccessListener(location -> {
                        if (!isCurrent(revision, token)) return;
                        boolean usable = BackgroundLocationManager.usable(location, System.currentTimeMillis());
                        if (usable) BackgroundLocationManager.receive(this, location);
                        BackgroundLocationManager.setError(this, revision, !usable);
                    })
                    .addOnFailureListener(error -> {
                        if (isCurrent(revision, token)) BackgroundLocationManager.setError(this, revision, true);
                    })
                    .addOnCompleteListener(result -> {
                        if (measurement != token) return;
                        measurement = null;
                        handler.postDelayed(sample, TimeUnit.MINUTES.toMillis(5));
                    });
        } catch (RuntimeException error) {
            measurement = null;
            BackgroundLocationManager.setError(this, revision, true);
            handler.postDelayed(sample, TimeUnit.MINUTES.toMillis(5));
        }
    }

    private boolean isCurrent(String revision, CancellationTokenSource token) {
        if (measurement != token) return false;
        synchronized (BackgroundLocationManager.LOCK) {
            JSONObject config = BackgroundLocationManager.read(this);
            return config != null && revision.equals(config.optString("revision"));
        }
    }

    private void cancelMeasurement() {
        handler.removeCallbacks(sample);
        CancellationTokenSource previous = measurement;
        measurement = null;
        if (previous != null) previous.cancel();
    }

    @Override public void onDestroy() {
        cancelMeasurement();
        BackgroundLocationManager.unregister(this);
        super.onDestroy();
    }
}
