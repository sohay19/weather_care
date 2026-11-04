package com.codesoha.weathercare

import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.DimensionBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.MoreExecutors
import java.util.concurrent.Executors

class WeatherTileService : TileService() {
    private val io = MoreExecutors.listeningDecorator(Executors.newSingleThreadExecutor())
    override fun onDestroy() { io.shutdown(); super.onDestroy() }

    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> {
        val data = WatchRepository.get(this).value
        WatchRepository.get(this).requestRefresh()
        return io.submit<TileBuilders.Tile> {
            val device = requestParams.deviceConfiguration
            val width = device.screenWidthDp.takeIf { it > 0 } ?: resources.configuration.screenWidthDp
            val height = device.screenHeightDp.takeIf { it > 0 } ?: resources.configuration.screenHeightDp
            val density = device.screenDensity.takeIf { it > 0 } ?: resources.displayMetrics.density
            val rendered = NanumSquareNeoTileRenderer(this).render(data, width, height, density)
            val version = TileImageStore(this).save(rendered.bitmap)
            rendered.bitmap.recycle()
            val action = ActionBuilders.LaunchAction.Builder().setAndroidActivity(ActionBuilders.AndroidActivity.Builder()
                .setPackageName(packageName).setClassName(WatchActivity::class.java.name)
                .addKeyToExtraMapping("screen", ActionBuilders.AndroidStringExtra.Builder().setValue("weather").build()).build()).build()
            // 타일 전체가 하나의 버튼이다. 그림 속 정보를 중복 없이 한 번 읽는다.
            val modifiers = ModifiersBuilders.Modifiers.Builder()
                .setClickable(ModifiersBuilders.Clickable.Builder().setId("weather").setOnClick(action).build())
                .setSemantics(ModifiersBuilders.Semantics.Builder().setContentDescription(rendered.description).build()).build()
            val root = LayoutElementBuilders.Image.Builder().setResourceId(TileImageStore.IMAGE_ID)
                .setWidth(DimensionBuilders.dp(width.toFloat())).setHeight(DimensionBuilders.dp(height.toFloat()))
                .setModifiers(modifiers).build()
            TileBuilders.Tile.Builder().setResourcesVersion(version).setFreshnessIntervalMillis(60_000)
                .setTileTimeline(TimelineBuilders.Timeline.Builder().addTimelineEntry(TimelineBuilders.TimelineEntry.Builder()
                    .setLayout(LayoutElementBuilders.Layout.Builder().setRoot(root).build()).build()).build()).build()
        }
    }

    override fun onTileResourcesRequest(requestParams: RequestBuilders.ResourcesRequest): ListenableFuture<ResourceBuilders.Resources> =
        io.submit<ResourceBuilders.Resources> { TileImageStore(this).load(requestParams.version) }
}
