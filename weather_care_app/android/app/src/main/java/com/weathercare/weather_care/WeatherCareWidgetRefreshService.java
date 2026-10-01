package com.codesoha.weathercare;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.location.Address;
import android.location.Geocoder;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.IBinder;
import android.os.Looper;
import android.os.SystemClock;

import androidx.annotation.Nullable;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

public final class WeatherCareWidgetRefreshService extends Service {
    private static final String CHANNEL_ID = "weather_care_widget_refresh";
    private static final int NOTIFICATION_ID = 1704;
    private static final long LOCATION_TIMEOUT_SECONDS = 8;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private boolean running;

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (running) return START_NOT_STICKY;
        running = true;
        try {
            startLocationForeground();
        } catch (RuntimeException ignored) {
            WeatherCareWidgetProvider.showLocationUnavailable(this);
            stopSelf();
            return START_NOT_STICKY;
        }
        WeatherCareWidgetProvider.setRefreshInProgress(this, true);
        executor.execute(() -> {
            try {
                SharedPreferences preferences = getSharedPreferences(
                        MainActivity.WIDGET_PREFERENCES, Context.MODE_PRIVATE
                );
                Location location = currentLocation();
                if (location == null) {
                    WeatherCareWidgetProvider.showLocationUnavailable(this);
                    return;
                }
                String url = refreshUrl(
                        preferences.getString(MainActivity.REFRESH_URL_KEY, null), location
                );
                if (url == null) {
                    WeatherCareWidgetProvider.showLocationUnavailable(this);
                    return;
                }
                WeatherCareWidgetRefreshWorker.refresh(this, url, false);
            } catch (Exception ignored) {
                // Keep the last weather snapshot when the server is unavailable.
            } finally {
                WeatherCareWidgetProvider.setRefreshInProgress(this, false);
                stopSelf();
            }
        });
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        executor.shutdownNow();
        super.onDestroy();
    }

    private void startLocationForeground() {
        NotificationManager manager = getSystemService(NotificationManager.class);
        manager.createNotificationChannel(new NotificationChannel(
                CHANNEL_ID, "위젯 위치 새로고침", NotificationManager.IMPORTANCE_LOW
        ));
        PendingIntent openApp = PendingIntent.getActivity(
                this, 0, new Intent(this, MainActivity.class),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        Notification notification = new Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_popup_sync)
                .setContentTitle("날씨챙겨 위젯 새로고침")
                .setContentText("현재 위치의 날씨를 확인하고 있어요")
                .setContentIntent(openApp)
                .setOngoing(true)
                .build();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                    NOTIFICATION_ID, notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            );
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
    }

    @Nullable
    private Location currentLocation() throws InterruptedException {
        boolean fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;
        boolean coarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;
        if (!fine && !coarse) return null;
        LocationManager manager = getSystemService(LocationManager.class);
        if (manager == null) return null;
        long startedAt = SystemClock.elapsedRealtimeNanos();
        AtomicReference<Location> best = new AtomicReference<>();
        CountDownLatch ready = new CountDownLatch(1);
        LocationListener listener = new LocationListener() {
            @Override
            public void onLocationChanged(Location location) {
                if (!usable(location, startedAt)) return;
                Location previous = best.get();
                if (previous == null || location.getAccuracy() < previous.getAccuracy()) {
                    best.set(location);
                }
                if (!fine || location.getAccuracy() <= 500) ready.countDown();
            }

            @Override
            public void onStatusChanged(String provider, int status, Bundle extras) {}

            @Override
            public void onProviderEnabled(String provider) {}

            @Override
            public void onProviderDisabled(String provider) {}
        };
        boolean registered = false;
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                registered |= requestProvider(manager, LocationManager.FUSED_PROVIDER, listener);
            }
            if (coarse || fine) {
                registered |= requestProvider(manager, LocationManager.NETWORK_PROVIDER, listener);
            }
            if (fine) {
                registered |= requestProvider(manager, LocationManager.GPS_PROVIDER, listener);
            }
            if (!registered) return null;
            ready.await(LOCATION_TIMEOUT_SECONDS, TimeUnit.SECONDS);
            return best.get();
        } finally {
            manager.removeUpdates(listener);
        }
    }

    private boolean requestProvider(
            LocationManager manager, String provider, LocationListener listener
    ) {
        try {
            if (!manager.isProviderEnabled(provider)) return false;
            manager.requestLocationUpdates(provider, 0, 0, listener, Looper.getMainLooper());
            return true;
        } catch (RuntimeException ignored) {
            return false;
        }
    }

    private static boolean usable(Location location, long startedAt) {
        long age = SystemClock.elapsedRealtimeNanos() - location.getElapsedRealtimeNanos();
        return location.hasAccuracy() && location.getAccuracy() > 0 &&
                Double.isFinite(location.getLatitude()) &&
                Double.isFinite(location.getLongitude()) &&
                location.getLatitude() >= 30 && location.getLatitude() <= 44 &&
                location.getLongitude() >= 120 && location.getLongitude() <= 134 &&
                age >= -TimeUnit.MINUTES.toNanos(1) &&
                age <= TimeUnit.MINUTES.toNanos(2) &&
                location.getElapsedRealtimeNanos() >=
                        startedAt - TimeUnit.SECONDS.toNanos(10);
    }

    @Nullable
    private String refreshUrl(String rawUrl, Location location) {
        if (rawUrl == null || rawUrl.isBlank()) return null;
        int[] grid = gridFor(location.getLatitude(), location.getLongitude());
        if (grid == null) return null;
        Uri saved = Uri.parse(rawUrl);
        Uri.Builder builder = saved.buildUpon().clearQuery();
        for (String name : saved.getQueryParameterNames()) {
            if (Set.of("nx", "ny", "latitude", "longitude", "regionCode", "regionName")
                    .contains(name)) continue;
            for (String value : saved.getQueryParameters(name)) {
                builder.appendQueryParameter(name, value);
            }
        }
        builder.appendQueryParameter("nx", String.valueOf(grid[0]));
        builder.appendQueryParameter("ny", String.valueOf(grid[1]));
        String regionName = regionName(location);
        if (regionName != null) builder.appendQueryParameter("regionName", regionName);
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED &&
                location.getAccuracy() <= 500) {
            builder.appendQueryParameter("latitude", String.valueOf(location.getLatitude()));
            builder.appendQueryParameter("longitude", String.valueOf(location.getLongitude()));
        }
        return builder.build().toString();
    }

    @Nullable
    private String regionName(Location location) {
        if (!Geocoder.isPresent()) return null;
        try {
            List<Address> addresses = new Geocoder(this, Locale.KOREA).getFromLocation(
                    location.getLatitude(), location.getLongitude(), 1
            );
            if (addresses == null || addresses.isEmpty()) return null;
            Address address = addresses.get(0);
            if (!"KR".equalsIgnoreCase(address.getCountryCode())) return null;
            String topLevel = address.getAdminArea();
            Set<String> parts = new LinkedHashSet<>();
            String shortTopLevel = switch (topLevel == null ? "" : topLevel) {
                case "서울특별시" -> "서울";
                case "부산광역시" -> "부산";
                case "대구광역시" -> "대구";
                case "인천광역시" -> "인천";
                case "광주광역시" -> "광주";
                case "대전광역시" -> "대전";
                case "울산광역시" -> "울산";
                case "세종특별자치시" -> "세종시";
                default -> null;
            };
            if (shortTopLevel != null) parts.add(shortTopLevel);
            for (String value : new String[] {
                    address.getLocality(), address.getSubAdminArea(), address.getSubLocality()
            }) {
                if (value == null || value.isBlank() || value.equals(topLevel)) continue;
                parts.add(value.trim());
            }
            if (parts.isEmpty() && topLevel != null && !topLevel.isBlank()) {
                parts.add(topLevel.trim());
            }
            return parts.isEmpty() ? null : String.join(" ", parts);
        } catch (Exception ignored) {
            return null;
        }
    }

    @Nullable
    static int[] gridFor(double latitude, double longitude) {
        if (!Double.isFinite(latitude) || !Double.isFinite(longitude) ||
                latitude < 30 || latitude > 44 || longitude < 120 || longitude > 134) {
            return null;
        }
        double radians = Math.PI / 180;
        double radius = 6371.00877 / 5.0;
        double first = 30.0 * radians;
        double second = 60.0 * radians;
        double originLatitude = 38.0 * radians;
        double originLongitude = 126.0 * radians;
        double cone = Math.log(Math.cos(first) / Math.cos(second)) /
                Math.log(Math.tan(Math.PI * 0.25 + second * 0.5) /
                        Math.tan(Math.PI * 0.25 + first * 0.5));
        double scale = Math.pow(Math.tan(Math.PI * 0.25 + first * 0.5), cone) *
                Math.cos(first) / cone;
        double originRadius = radius * scale /
                Math.pow(Math.tan(Math.PI * 0.25 + originLatitude * 0.5), cone);
        double targetRadius = radius * scale /
                Math.pow(Math.tan(Math.PI * 0.25 + latitude * radians * 0.5), cone);
        double angle = longitude * radians - originLongitude;
        if (angle > Math.PI) angle -= 2 * Math.PI;
        if (angle < -Math.PI) angle += 2 * Math.PI;
        angle *= cone;
        int nx = (int) Math.floor(targetRadius * Math.sin(angle) + 43.0 + 0.5);
        int ny = (int) Math.floor(originRadius - targetRadius * Math.cos(angle) + 136.0 + 0.5);
        return nx > 0 && nx <= 149 && ny > 0 && ny <= 253
                ? new int[] {nx, ny} : null;
    }
}
