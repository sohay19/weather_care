package com.codesoha.weathercare;

import android.Manifest;
import android.app.Activity;
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
import androidx.work.ExistingWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;

import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.CurrentLocationRequest;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;

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

/** GPS-capable monitoring owned by a visible, user-controlled location service. */
final class BackgroundLocationManager {
    static final Object LOCK = new Object();
    static final String WORK = "weather-care-background-location";
    private static final String KEY = "weather_care_background_location_v1";

    private static PendingIntent intent(Context context) {
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 31) flags |= PendingIntent.FLAG_MUTABLE;
        return PendingIntent.getBroadcast(context, 731,
                new Intent(context, BackgroundLocationReceiver.class).setAction(WORK), flags);
    }

    static boolean permitted(Context context) {
        boolean foreground = context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                == PackageManager.PERMISSION_GRANTED || context.checkSelfPermission(
                Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        return foreground && (Build.VERSION.SDK_INT < 29 || context.checkSelfPermission(
                Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED);
    }

    static boolean requestPermission(Activity activity, boolean initial) {
        boolean foreground = activity.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        if (permitted(activity) || (initial && !foreground)) return false;
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
        synchronized (LOCK) { write(context, config); }
        resume(context);
    }

    static void resume(Context context) {
        synchronized (LOCK) {
            JSONObject config = read(context);
            if (config == null || !permitted(context)) return;
            try { context.startForegroundService(new Intent(context, BackgroundLocationService.class)); }
            catch (RuntimeException error) { setError(context, config.optString("revision"), true); }
        }
    }

    static void register(Context context) {
        synchronized (LOCK) {
            JSONObject config = read(context);
            if (config == null || !permitted(context)) return;
            LocationRequest request = monitoringRequest();
            try {
                LocationServices.getFusedLocationProviderClient(context)
                        .requestLocationUpdates(request, intent(context))
                        .addOnSuccessListener(unused -> setError(context, config.optString("revision"), false))
                        .addOnFailureListener(error -> setError(context, config.optString("revision"), true));
                if (config.has("pending")) enqueue(context);
            } catch (SecurityException error) { setError(context, config.optString("revision"), true); }
        }
    }

    static LocationRequest monitoringRequest() {
        // Balanced mode may never activate GNSS when network fixes are unavailable.
        return new LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, TimeUnit.MINUTES.toMillis(5))
                .setMinUpdateIntervalMillis(TimeUnit.MINUTES.toMillis(1))
                .setMinUpdateDistanceMeters(1000).setMaxUpdateAgeMillis(0)
                .setWaitForAccurateLocation(false).build();
    }

    static CurrentLocationRequest freshLocationRequest() {
        return new CurrentLocationRequest.Builder().setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                .setMaxUpdateAgeMillis(0).setDurationMillis(20_000).build();
    }

    static void stop(Context context) {
        synchronized (LOCK) {
            store(context).delete();
            unregister(context);
            context.stopService(new Intent(context, BackgroundLocationService.class));
            WorkManager.getInstance(context).cancelUniqueWork(WORK);
        }
    }

    static void unregister(Context context) {
        LocationServices.getFusedLocationProviderClient(context).removeLocationUpdates(intent(context));
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
                            ? "locationDisabled" : config.optBoolean("error") ? "error" : "active";
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
