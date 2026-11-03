package com.codesoha.weathercare

import android.content.Context
import android.util.Log
import androidx.compose.runtime.mutableStateOf
import androidx.work.*
import com.codesoha.weathercare.wearbridge.WearContract
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.*
import java.nio.charset.StandardCharsets
import java.util.concurrent.TimeUnit

class WatchRepository private constructor(private val context: Context) {
    private val preferences = context.getSharedPreferences("watch_weather", Context.MODE_PRIVATE)
    private val state = mutableStateOf(restoreSnapshot())

    private fun restoreSnapshot(): WatchSnapshot {
        context.deleteSharedPreferences("watch_cloud_link")
        val cached = WatchSnapshot.parse(preferences.getString("snapshot", "")!!) ?: return WatchSnapshot.EMPTY
        if (!cached.json.has("_serverClockOffsetMs")) return cached
        preferences.edit().remove("snapshot").remove("requested_at").apply()
        return WatchSnapshot.EMPTY
    }

    val value get() = state.value
    init {
        // 앱을 열지 않고 위젯/수신 서비스만 사용해도 보조 갱신을 등록한다.
        WorkManager.getInstance(context).enqueueUniquePeriodicWork("watch-weather-periodic", ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<WatchRefreshWorker>(30, TimeUnit.MINUTES).setInitialDelay(30, TimeUnit.MINUTES).build())
    }

    @Synchronized fun accept(raw: String): Boolean {
        if (raw.toByteArray(StandardCharsets.UTF_8).size > WearContract.MAX_BYTES) return false
        val next = WatchSnapshot.parse(raw) ?: return false
        val previous = value
        if (next.publishedAt <= previous.publishedAt) return false
        // 디스크 저장 후 표시를 바꿔 재시작 때도 같은 revision을 읽는다.
        if (!preferences.edit().putString("snapshot", raw).commit()) return false
        state.value = next
        WatchUpdates.request(context)
        WatchExpiryWorker.schedule(context, next)
        Log.i("WeatherCareWear", "accepted revision=${next.revision}")
        return true
    }

    fun checked(type: String, snapshot: WatchSnapshot = value) =
        preferences.getBoolean(snapshot.checkKey(type), false)

    fun toggle(type: String, snapshot: WatchSnapshot = value): Boolean {
        val key = snapshot.checkKey(type)
        val checked = !preferences.getBoolean(key, false)
        // 지난날 키만 정리하고 같은 날 다른 구역의 체크는 유지한다.
        val editor = preferences.edit()
        val day = key.substringBeforeLast('|').substringAfterLast('|')
        preferences.all.keys.filter { it.contains('|') && !it.substringBeforeLast('|').endsWith("|$day") }.forEach(editor::remove)
        editor.putBoolean(key, checked).apply()
        return checked
    }

    @Synchronized fun requestRefresh(force: Boolean = false): Boolean {
        val now = System.currentTimeMillis()
        if (!force && now - preferences.getLong("requested_at", 0) < 60_000) return false
        preferences.edit().putLong("requested_at", now).apply()
        WorkManager.getInstance(context).enqueueUniqueWork("watch-weather-refresh",
            if (force) ExistingWorkPolicy.REPLACE else ExistingWorkPolicy.KEEP,
            OneTimeWorkRequestBuilder<WatchRefreshWorker>().build())
        return true
    }

    companion object {
        @Volatile private var instance: WatchRepository? = null
        fun get(context: Context): WatchRepository = instance ?: synchronized(this) {
            instance ?: WatchRepository(context.applicationContext).also { instance = it }
        }
    }
}

class WatchDataService : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) if (event.type == DataEvent.TYPE_CHANGED && event.dataItem.uri.path == WearContract.SNAPSHOT_PATH) {
            runCatching { DataMapItem.fromDataItem(event.dataItem).dataMap.getString(WearContract.PAYLOAD_KEY) }
                .getOrNull()?.let { WatchRepository.get(this).accept(it) }
        }
    }
}

class WatchRefreshWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result = try {
        val client = Wearable.getDataClient(applicationContext)
        Tasks.await(client.dataItems, 15, TimeUnit.SECONDS).use { items ->
            for (item in items) if (item.uri.path == WearContract.SNAPSHOT_PATH) {
                DataMapItem.fromDataItem(item).dataMap.getString(WearContract.PAYLOAD_KEY)?.let { WatchRepository.get(applicationContext).accept(it) }
            }
        }
        val nodes = Tasks.await(Wearable.getNodeClient(applicationContext).connectedNodes, 15, TimeUnit.SECONDS)
        if (nodes.isEmpty()) return Result.retry()
        for (node in nodes) Tasks.await(Wearable.getMessageClient(applicationContext).sendMessage(node.id, WearContract.REQUEST_PATH, byteArrayOf()), 15, TimeUnit.SECONDS)
        WatchUpdates.request(applicationContext)
        Result.success()
    } catch (error: Exception) {
        Log.w("WeatherCareWear", "phone refresh unavailable", error)
        if (runAttemptCount < 3) Result.retry() else Result.failure()
    }
}

/** 브리핑 경계·자료 만료 뒤에도 앱을 열지 않고 표시 갱신을 요청한다. 실행은 OS가 지연할 수 있다. */
class WatchExpiryWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        WatchUpdates.request(applicationContext)
        schedule(applicationContext, WatchRepository.get(applicationContext).value)
        return Result.success()
    }
    companion object {
        fun schedule(context: Context, snapshot: WatchSnapshot) {
            val now = snapshot.now()
            val boundaries = snapshot.widget.optJSONArray("briefingTimeline").objects().flatMap {
                listOfNotNull(instant(it.optString("validFrom")), instant(it.optString("validUntil")))
            } + listOfNotNull(snapshot.generatedAt?.plusSeconds(3 * 3600))
            val next = boundaries.filter { it.isAfter(now.plusSeconds(1)) }.minOrNull()
            if (next == null) {
                WorkManager.getInstance(context).cancelUniqueWork("watch-weather-expiry")
                return
            }
            WorkManager.getInstance(context).enqueueUniqueWork("watch-weather-expiry", ExistingWorkPolicy.REPLACE,
                OneTimeWorkRequestBuilder<WatchExpiryWorker>().setInitialDelay(java.time.Duration.between(now, next).toMillis() + 1000, TimeUnit.MILLISECONDS).build())
        }
    }
}
