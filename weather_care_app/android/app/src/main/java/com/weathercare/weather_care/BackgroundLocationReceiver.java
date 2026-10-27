package com.codesoha.weathercare;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingEvent;

public final class BackgroundLocationReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction()) ||
                Intent.ACTION_MY_PACKAGE_REPLACED.equals(intent.getAction())) {
            BackgroundLocationManager.resume(context);
            return;
        }
        if (!BackgroundLocationManager.GEOFENCE_WORK.equals(intent.getAction())) return;
        GeofencingEvent event = GeofencingEvent.fromIntent(intent);
        if (event == null) return;
        if (event.hasError()) {
            synchronized (BackgroundLocationManager.LOCK) {
                var config = BackgroundLocationManager.read(context);
                if (config != null) {
                    BackgroundLocationManager.setError(context, config.optString("revision"), true);
                    BackgroundLocationManager.resume(context);
                }
            }
            return;
        }
        if (event.getGeofenceTransition() != Geofence.GEOFENCE_TRANSITION_EXIT || event.getTriggeringGeofences() == null) return;
        for (Geofence fence : event.getTriggeringGeofences()) {
            BackgroundLocationManager.exit(context, fence.getRequestId(), event.getTriggeringLocation());
        }
    }
}
