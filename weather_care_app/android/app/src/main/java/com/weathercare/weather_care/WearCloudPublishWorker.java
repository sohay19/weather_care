package com.codesoha.weathercare;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

/** 실제 날씨 갱신 작업 뒤 서버의 수신 완료까지 작업 수명을 유지한다. */
public final class WearCloudPublishWorker extends Worker {
    public WearCloudPublishWorker(@NonNull Context context, @NonNull WorkerParameters parameters) { super(context, parameters); }
    @NonNull @Override public Result doWork() {
        Context context = getApplicationContext();
        String payload = context.getSharedPreferences("weather_care_wear_sync", Context.MODE_PRIVATE).getString("payload", null);
        if (payload == null || !WearCloudSync.isLinked(context)) return Result.success();
        if (WearCloudSync.publish(context, payload)) return Result.success();
        return getRunAttemptCount() < 3 ? Result.retry() : Result.failure();
    }
}
