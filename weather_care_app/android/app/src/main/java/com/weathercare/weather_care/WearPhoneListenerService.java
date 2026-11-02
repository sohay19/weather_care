package com.codesoha.weathercare;

import com.codesoha.weathercare.wearbridge.WearContract;
import com.google.android.gms.wearable.MessageEvent;
import com.google.android.gms.wearable.Node;
import com.google.android.gms.wearable.WearableListenerService;

public final class WearPhoneListenerService extends WearableListenerService {
    @Override public void onMessageReceived(MessageEvent event) {
        if (!WearContract.REQUEST_PATH.equals(event.getPath())) return;
        WearPhoneSync.sendLatest(this);
        var saved = getSharedPreferences("weather_care_wear_sync", MODE_PRIVATE);
        long now = System.currentTimeMillis();
        if (now - saved.getLong("refresh_requested_at", 0) < 60_000) return;
        saved.edit().putLong("refresh_requested_at", now).apply();
        WeatherCareWidgetProvider.enqueueRefresh(this);
    }
    @Override public void onPeerConnected(Node peer) { WearPhoneSync.sendLatest(this); }
}
