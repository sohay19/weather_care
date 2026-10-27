package com.codesoha.weathercare;

import android.content.Context;
import android.location.Location;
import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;
import com.google.android.gms.location.CurrentLocationRequest;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;
import com.google.android.gms.tasks.CancellationTokenSource;
import com.google.android.gms.tasks.Tasks;
import org.json.JSONObject;
import java.util.List;
import java.util.concurrent.TimeUnit;

/** Short, retryable work for initial registration and movement events. No foreground service. */
public final class BackgroundGeofenceWorker extends Worker {
    private final CancellationTokenSource measurement = new CancellationTokenSource();

    public BackgroundGeofenceWorker(@NonNull Context context, @NonNull WorkerParameters parameters) {
        super(context, parameters);
    }

    @NonNull @Override public Result doWork() {
        Context context = getApplicationContext();
        String revision = getInputData().getString("revision");
        JSONObject config;
        synchronized (BackgroundLocationManager.LOCK) {
            config = BackgroundLocationManager.read(context);
            if (!current(context, config, revision)) return Result.success();
        }
        try {
            Location location = eventLocation(config.optJSONObject("geofenceEvent"));
            if (!usableCenter(location, System.currentTimeMillis())) {
                try {
                    location = Tasks.await(LocationServices.getFusedLocationProviderClient(context)
                            .getCurrentLocation(new CurrentLocationRequest.Builder()
                                    .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                                    .setMaxUpdateAgeMillis(60_000).setDurationMillis(20_000).build(),
                                    measurement.getToken()), 25, TimeUnit.SECONDS);
                } catch (Exception unavailable) {
                    location = null;
                } finally { measurement.cancel(); }
            }
            if (isStopped()) return Result.success();
            if (!usableCenter(location, System.currentTimeMillis())) {
                // Restore the last fence after a reboot even when a new fix is unavailable.
                // INITIAL_TRIGGER_EXIT also catches movement that happened while the phone was off.
                if (getRunAttemptCount() == 0 && config.has("geofenceLatitude") && config.has("geofenceLongitude")) {
                    register(context, config, config.getDouble("geofenceLatitude"), config.getDouble("geofenceLongitude"));
                }
                BackgroundLocationManager.setError(context, revision, true);
                return Result.retry();
            }
            if (!register(context, config, location.getLatitude(), location.getLongitude())) return Result.success();
            synchronized (BackgroundLocationManager.LOCK) {
                if (current(context, BackgroundLocationManager.read(context), revision)) {
                    BackgroundLocationManager.receive(context, location);
                    JSONObject latest = BackgroundLocationManager.read(context);
                    JSONObject event = latest == null ? null : latest.optJSONObject("geofenceEvent");
                    if (event != null && event.optLong("measuredAt") <= location.getTime()) {
                        latest.remove("geofenceEvent");
                        BackgroundLocationManager.write(context, latest);
                    }
                }
            }
            return Result.success();
        } catch (Exception error) {
            BackgroundLocationManager.setError(context, revision, true);
            return isStopped() ? Result.success() : Result.retry();
        }
    }

    private boolean current(Context context, JSONObject config, String revision) {
        return !isStopped() && config != null && revision != null && revision.equals(config.optString("revision"))
                && BackgroundLocationManager.permitted(context);
    }

    private Location eventLocation(JSONObject event) {
        Location location = new Location("geofence");
        if (event == null) return location;
        location.setLatitude(event.optDouble("latitude", Double.NaN));
        location.setLongitude(event.optDouble("longitude", Double.NaN));
        location.setAccuracy((float) event.optDouble("accuracy", 0));
        location.setTime(event.optLong("measuredAt", 0));
        return location;
    }

    static boolean usableCenter(Location location, long now) {
        return location != null && location.hasAccuracy() && usableCenterSample(location.getLatitude(),
                location.getLongitude(), location.getAccuracy(), location.getTime(), now);
    }

    static boolean usableCenterSample(double latitude, double longitude, float accuracy, long measuredAt, long now) {
        return accuracy <= 1000 && BackgroundLocationManager.usableSample(latitude, longitude, accuracy, measuredAt, now);
    }

    private boolean register(Context context, JSONObject original, double latitude, double longitude) throws Exception {
        String revision = original.getString("revision");
        com.google.android.gms.tasks.Task<Void> registration;
        synchronized (BackgroundLocationManager.LOCK) {
            if (!current(context, BackgroundLocationManager.read(context), revision)) return false;
            registration = LocationServices.getGeofencingClient(context).addGeofences(
                    BackgroundLocationManager.geofenceRequest(revision, latitude, longitude),
                    BackgroundLocationManager.geofenceIntent(context));
        }
        // A late registration must never restore monitoring after opt-out or a new session.
        registration.addOnSuccessListener(Runnable::run, unused -> {
            synchronized (BackgroundLocationManager.LOCK) {
                JSONObject config = BackgroundLocationManager.read(context);
                if (config == null || !revision.equals(config.optString("revision")) || !BackgroundLocationManager.permitted(context)) {
                    LocationServices.getGeofencingClient(context).removeGeofences(List.of(revision));
                }
            }
        });
        Tasks.await(registration, 20, TimeUnit.SECONDS);
        synchronized (BackgroundLocationManager.LOCK) {
            JSONObject config = BackgroundLocationManager.read(context);
            if (!current(context, config, revision)) return false;
            config.put("geofenceLatitude", latitude).put("geofenceLongitude", longitude).put("error", false);
            BackgroundLocationManager.write(context, config);
        }
        return true;
    }

    @Override public void onStopped() { measurement.cancel(); }
}
