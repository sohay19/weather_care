package com.codesoha.weathercare

import android.content.ComponentName
import android.content.Context
import android.graphics.drawable.Icon
import android.util.Log
import androidx.wear.watchface.complications.data.*
import androidx.wear.watchface.complications.datasource.*
import androidx.wear.tiles.TileService
import kotlinx.coroutines.*
import java.time.Instant

abstract class BaseWeatherComplication : ComplicationDataSourceService() {
    override fun onComplicationRequest(request: ComplicationRequest, listener: ComplicationRequestListener) {
        val data = WatchRepository.get(this).value
        WatchRepository.get(this).requestRefresh()
        listener.onComplicationData(if (!data.hasData || data.stale()) NoDataComplicationData() else render(data))
    }
    override fun getPreviewData(type: ComplicationType): ComplicationData = render(WatchSnapshot.EMPTY)
    abstract fun render(snapshot: WatchSnapshot): ComplicationData
}
class TemperatureComplicationService : BaseWeatherComplication() {
    override fun render(snapshot: WatchSnapshot): ComplicationData = ShortTextComplicationData.Builder(
        PlainComplicationText.Builder(snapshot.temperature).build(), PlainComplicationText.Builder("현재 기온 ${snapshot.temperature}").build())
        .setTapAction(WatchIntents.open(this)).setValidTimeRange(snapshot.validRange()).build()
}
class WeatherComplicationService : BaseWeatherComplication() {
    override fun render(snapshot: WatchSnapshot): ComplicationData = SmallImageComplicationData.Builder(
        SmallImage.Builder(Icon.createWithBitmap(WidgetIconRenderer.weather(this, snapshot.condition, 36, false)), SmallImageType.ICON).build(),
        PlainComplicationText.Builder("현재 날씨 ${snapshot.condition}").build()).setTapAction(WatchIntents.open(this)).setValidTimeRange(snapshot.validRange()).build()
}
private fun WatchSnapshot.validRange() = generatedAt?.let { TimeRange.before(it.plusSeconds(3 * 3600)) } ?: TimeRange.ALWAYS
object WatchUpdates {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    fun request(context: Context) {
        val app = context.applicationContext
        scope.launch {
            runCatching { WeatherWidget().triggerUpdateAll(app) }.onFailure { Log.w("WeatherCareWear", "widget refresh unavailable", it) }
        }
        runCatching { TileService.getUpdater(app).requestUpdate(WeatherTileService::class.java) }
        for (service in listOf(TemperatureComplicationService::class.java, WeatherComplicationService::class.java)) {
            runCatching { ComplicationDataSourceUpdateRequester.create(app, ComponentName(app, service)).requestUpdateAll() }
        }
    }
}
