package com.codesoha.weathercare;

import android.Manifest;
import android.app.Activity;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.AtomicFile;

import androidx.work.BackoffPolicy;
import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.ExistingWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;

import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingRequest;
import com.google.android.gms.location.LocationServices;

import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Opt-in movement monitoring without a continuously running service. */
final class BackgroundLocationManager {
    static final Object LOCK = new Object();
    static final String WORK = "weather-care-background-location";
    static final String GEOFENCE_WORK = WORK + "-geofence";
    private static final String KEY = "weather_care_background_location_v1";

    private static PendingIntent intent(Context context, boolean geofence) {
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 31) flags |= PendingIntent.FLAG_MUTABLE;
        return PendingIntent.getBroadcast(context, geofence ? 732 : 731,
                new Intent(context, BackgroundLocationReceiver.class)
                        .setAction(geofence ? GEOFENCE_WORK : WORK), flags);
    }

    static boolean permitted(Context context) {
        boolean foreground = context.checkSelfPermission(
                Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        return foreground && (Build.VERSION.SDK_INT < 29 || context.checkSelfPermission(
                Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED);
    }

    static boolean requestPermission(Activity activity, boolean initial) {
        boolean foreground = activity.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        if (permitted(activity) || (initial && !foreground)) return false;
        if (activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            boolean requestedFine = activity.getPreferences(Context.MODE_PRIVATE).getBoolean("geofence_fine_requested", false);
            if (!requestedFine || activity.shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_FINE_LOCATION)) {
                activity.getPreferences(Context.MODE_PRIVATE).edit().putBoolean("geofence_fine_requested", true).apply();
                activity.requestPermissions(new String[]{Manifest.permission.ACCESS_COARSE_LOCATION,
                        Manifest.permission.ACCESS_FINE_LOCATION}, 731);
                return true;
            }
            if (!initial) activity.startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:" + activity.getPackageName())));
            return false;
        }
        boolean requested = activity.getPreferences(Context.MODE_PRIVATE).getBoolean("background_location_requested", false);
        if (foreground && Build.VERSION.SDK_INT >= 29 &&
                (!requested || activity.shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_BACKGROUND_LOCATION))) {
            activity.getPreferences(Context.MODE_PRIVATE).edit().putBoolean("background_location_requested", true).apply();
            activity.requestPermissions(new String[]{Manifest.permission.ACCESS_BACKGROUND_LOCATION}, 731);
            return true;
        }
        if (!initial) {
            activity.startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:" + activity.getPackageName())));
        }
        return false;
    }

    static void configure(Context context, Map<?, ?> values) throws Exception {
        JSONObject config = new JSONObject();
        for (String field : new String[]{"url", "authorization", "revision", "testAccessKey"}) {
            if (values.get(field) instanceof String) config.put(field, values.get(field));
        }
        Uri url = Uri.parse(config.getString("url"));
        boolean debug = (context.getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        if (!("https".equals(url.getScheme()) || (debug && "http".equals(url.getScheme()))) ||
                !config.getString("authorization").matches("Bearer [0-9a-f]{64}") ||
                !config.getString("revision").matches("[0-9a-fA-F-]{36}")) {
            throw new IllegalArgumentException("Invalid background location configuration");
        }
        synchronized (LOCK) {
            JSONObject previous = read(context);
            if (previous != null && config.optString("url").equals(previous.optString("url")) &&
                    config.optString("authorization").equals(previous.optString("authorization")) &&
                    previous.has("geofenceLatitude") && previous.has("geofenceLongitude")) {
                config.put("geofenceLatitude", previous.getDouble("geofenceLatitude"))
                        .put("geofenceLongitude", previous.getDouble("geofenceLongitude"));
            }
            unregister(context);
            WorkManager.getInstance(context).cancelUniqueWork(GEOFENCE_WORK);
            write(context, config);
        }
        resume(context);
    }

    static void resume(Context context) {
        // Remove the old service channel only; the weather push channel is separate.
        NotificationManager notifications = context.getSystemService(NotificationManager.class);
        if (notifications != null) {
            notifications.cancel(1731);
            notifications.deleteNotificationChannel("weather_care_background_location");
        }
        LocationServices.getFusedLocationProviderClient(context).removeLocationUpdates(intent(context, false));
        synchronized (LOCK) {
            JSONObject config = read(context);
            if (config == null || !permitted(context)) return;
            scheduleGeofence(context, config, ExistingWorkPolicy.KEEP);
            if (config.has("pending")) enqueue(context);
        }
    }

    static void exit(Context context, String revision, Location location) {
        synchronized (LOCK) {
            JSONObject config = read(context);
            if (config == null || !revision.equals(config.optString("revision")) || !permitted(context)) return;
            try {
                if (usable(location, System.currentTimeMillis())) {
                    JSONObject event = config.optJSONObject("geofenceEvent");
                    if (event == null || event.optLong("measuredAt") < location.getTime()) {
                        config.put("geofenceEvent", new JSONObject().put("latitude", location.getLatitude())
                                .put("longitude", location.getLongitude()).put("accuracy", location.getAccuracy())
                                .put("measuredAt", location.getTime()));
                        write(context, config);
                    }
                }
                scheduleGeofence(context, config, ExistingWorkPolicy.APPEND_OR_REPLACE);
            } catch (Exception error) {
                setError(context, revision, true);
            }
        }
    }

    private static void scheduleGeofence(Context context, JSONObject config, ExistingWorkPolicy policy) {
        WorkManager.getInstance(context).enqueueUniqueWork(GEOFENCE_WORK, policy,
                new OneTimeWorkRequest.Builder(BackgroundGeofenceWorker.class)
                        .setInputData(new Data.Builder().putString("revision", config.optString("revision")).build())
                        .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build());
    }

    static GeofencingRequest geofenceRequest(String revision, double latitude, double longitude) {
        return new GeofencingRequest.Builder().setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_EXIT)
                .addGeofence(new Geofence.Builder().setRequestId(revision)
                        .setCircularRegion(latitude, longitude, 1000)
                        .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_EXIT)
                        .setNotificationResponsiveness(120_000).setExpirationDuration(Geofence.NEVER_EXPIRE).build())
                .build();
    }

    static PendingIntent geofenceIntent(Context context) { return intent(context, true); }

    static void stop(Context context) {
        synchronized (LOCK) {
            store(context).delete();
            unregister(context);
            WorkManager.getInstance(context).cancelUniqueWork(GEOFENCE_WORK);
            WorkManager.getInstance(context).cancelUniqueWork(WORK);
        }
    }

    static void unregister(Context context) {
        LocationServices.getFusedLocationProviderClient(context).removeLocationUpdates(intent(context, false));
        LocationServices.getGeofencingClient(context).removeGeofences(geofenceIntent(context));
    }

    static void receive(Context context, Location location) {
        if (!permitted(context) || !usable(location, System.currentTimeMillis())) return;
        synchronized (LOCK) {
            JSONObject config = read(context);
            if (config == null) return;
            try {
                long last = config.optLong("measuredMillis", 0);
                if (location.getTime() <= last) return;
                if (config.has("lastLatitude") && config.has("lastLongitude") && !moved(
                        config.getDouble("lastLatitude"), config.getDouble("lastLongitude"),
                        location.getLatitude(), location.getLongitude()) && !needsFreshRetry(
                        last, config.optLong("syncedMeasuredMillis"), config.has("pending"),
                        System.currentTimeMillis())) return;
                JSONObject pending = new JSONObject()
                        .put("revision", config.getString("revision"))
                        .put("latitude", location.getLatitude()).put("longitude", location.getLongitude())
                        .put("accuracy", location.getAccuracy())
                        .put("precise", context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                                == PackageManager.PERMISSION_GRANTED && location.getAccuracy() <= 500)
                        .put("measuredAt", Instant.ofEpochMilli(location.getTime()).toString());
                config.put("pending", pending).put("measuredMillis", location.getTime())
                        .put("lastLatitude", location.getLatitude()).put("lastLongitude", location.getLongitude());
                write(context, config);
                enqueue(context);
            } catch (Exception error) { setError(context, config.optString("revision"), true); }
        }
    }

    static boolean moved(double previousLatitude, double previousLongitude, double latitude, double longitude) {
        double lat = Math.toRadians(latitude - previousLatitude), lon = Math.toRadians(longitude - previousLongitude);
        double a = Math.pow(Math.sin(lat / 2), 2) + Math.cos(Math.toRadians(previousLatitude)) *
                Math.cos(Math.toRadians(latitude)) * Math.pow(Math.sin(lon / 2), 2);
        return 2 * 6371008.77 * Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a))) >= 1000;
    }

    static boolean needsFreshRetry(long measured, long synced, boolean pending, long now) {
        return measured > synced && (!pending || now - measured > TimeUnit.MINUTES.toMillis(15));
    }

    static boolean usable(Location location, long now) {
        return location != null && location.hasAccuracy() && usableSample(location.getLatitude(),
                location.getLongitude(), location.getAccuracy(), location.getTime(), now);
    }

    static boolean usableSample(double latitude, double longitude, float accuracy, long measuredAt, long now) {
        return accuracy > 0 && accuracy <= 5000 && Double.isFinite(latitude) && Double.isFinite(longitude) &&
                latitude >= 30 && latitude <= 44 && longitude >= 120 && longitude <= 134 &&
                now - measuredAt <= TimeUnit.MINUTES.toMillis(15) && now - measuredAt >= -60_000;
    }

    private static void enqueue(Context context) {
        WorkManager.getInstance(context).enqueueUniqueWork(WORK, ExistingWorkPolicy.APPEND_OR_REPLACE,
                new OneTimeWorkRequest.Builder(BackgroundLocationWorker.class)
                        .setConstraints(new Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                        .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build());
    }

    static Map<String, Object> status(Context context) {
        synchronized (LOCK) {
            JSONObject config = read(context);
            Map<String, Object> result = new HashMap<>();
            LocationManager manager = context.getSystemService(LocationManager.class);
            String state = config == null ? "disabled" : !permitted(context) ? "permissionRequired" :
                    manager != null && !androidx.core.location.LocationManagerCompat.isLocationEnabled(manager)
                            ? "locationDisabled" : config.optBoolean("error") ? "error" :
                            config.has("geofenceLatitude") ? "active" : "starting";
            result.put("status", state);
            if (config != null) {
                if (config.has("measuredMillis")) result.put("measuredAt", Instant.ofEpochMilli(config.optLong("measuredMillis")).toString());
                if (config.has("syncedAt")) result.put("syncedAt", config.optString("syncedAt"));
            }
            return result;
        }
    }

    static void setError(Context context, String revision, boolean error) {
        synchronized (LOCK) {
            JSONObject config = read(context);
            if (config == null || !revision.equals(config.optString("revision"))) return;
            try { config.put("error", error); write(context, config); } catch (Exception ignored) { }
        }
    }

    private static AtomicFile store(Context context) {
        return new AtomicFile(new File(context.getNoBackupFilesDir(), "background-location.enc"));
    }

    private static SecretKey key() throws Exception {
        KeyStore keys = KeyStore.getInstance("AndroidKeyStore");
        keys.load(null);
        if (!keys.containsAlias(KEY)) {
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(KEY,
                    KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
            generator.generateKey();
        }
        return (SecretKey) keys.getKey(KEY, null);
    }

    static JSONObject read(Context context) {
        try {
            byte[] stored = store(context).readFully();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128, stored, 0, 12));
            return new JSONObject(new String(cipher.doFinal(stored, 12, stored.length - 12), StandardCharsets.UTF_8));
        } catch (Exception ignored) { return null; }
    }

    static void write(Context context, JSONObject value) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, key());
        AtomicFile file = store(context);
        FileOutputStream stream = file.startWrite();
        try {
            stream.write(cipher.getIV());
            stream.write(cipher.doFinal(value.toString().getBytes(StandardCharsets.UTF_8)));
            file.finishWrite(stream);
        } catch (Exception error) { file.failWrite(stream); throw error; }
    }
}
