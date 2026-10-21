package com.codesoha.weathercare;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import com.google.android.gms.location.LocationResult;

public final class BackgroundLocationReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction()) ||
                Intent.ACTION_MY_PACKAGE_REPLACED.equals(intent.getAction())) {
            BackgroundLocationManager.resume(context);
            return;
        }
        LocationResult result = LocationResult.extractResult(intent);
        if (result != null) BackgroundLocationManager.receive(context, result.getLastLocation());
    }
}
