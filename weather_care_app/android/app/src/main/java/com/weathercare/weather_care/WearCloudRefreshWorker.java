package com.codesoha.weathercare;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.work.*;
import java.util.concurrent.TimeUnit;

/** 폰 홈 위젯이 없어도 연결한 워치에 새 날씨를 보낸다. */
public final class WearCloudRefreshWorker extends Worker {
    private static final String PERIODIC = "wear-cloud-periodic";
    private static final String REFRESH = "wear-cloud-fetch-and-publish";
    public WearCloudRefreshWorker(@NonNull Context context, @NonNull WorkerParameters parameters) { super(context, parameters); }
    private static Constraints network() { return new Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build(); }
    static void schedule(Context context) {
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(PERIODIC, ExistingPeriodicWorkPolicy.KEEP,
                new PeriodicWorkRequest.Builder(WearCloudRefreshWorker.class, 30, TimeUnit.MINUTES)
                        .setInitialDelay(30, TimeUnit.MINUTES).setConstraints(network()).build());
    }
    static void refresh(Context context) {
        WorkManager.getInstance(context).beginUniqueWork(REFRESH, ExistingWorkPolicy.KEEP,
                new OneTimeWorkRequest.Builder(WeatherCareWidgetRefreshWorker.class).setConstraints(network()).build())
                .then(new OneTimeWorkRequest.Builder(WearCloudPublishWorker.class).setConstraints(network()).build()).enqueue();
    }
    static void cancel(Context context) {
        WorkManager.getInstance(context).cancelUniqueWork(PERIODIC);
        WorkManager.getInstance(context).cancelUniqueWork(REFRESH);
    }
    @NonNull @Override public Result doWork() {
        if (WearCloudSync.isLinked(getApplicationContext())) refresh(getApplicationContext());
        return Result.success();
    }
}
