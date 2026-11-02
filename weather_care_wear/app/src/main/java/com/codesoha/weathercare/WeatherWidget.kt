package com.codesoha.weathercare

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.compose.remote.creation.compose.action.pendingIntentAction
import androidx.compose.remote.creation.compose.layout.*
import androidx.compose.remote.creation.compose.modifier.*
import androidx.compose.remote.creation.compose.shapes.RemoteRoundedCornerShape
import androidx.compose.remote.creation.compose.state.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.glance.wear.*
import androidx.glance.wear.core.WearWidgetParams
import androidx.glance.wear.core.ContainerInfo

@AssociateWithGlanceWearWidget(WeatherWidget::class)
class WeatherWidgetService : GlanceWearWidgetService() {
    override val widget: GlanceWearWidget = WeatherWidget()
}

class WeatherWidget : GlanceWearWidget() {
    override suspend fun provideWidgetData(context: Context, params: WearWidgetParams): WearWidgetData {
        val repository = WatchRepository.get(context)
        val snapshot = repository.value
        repository.requestRefresh()
        Log.i("WeatherCareWear", "widget type=${params.containerType} content=${params.widthDp}x${params.heightDp} padding=${params.horizontalPaddingDp},${params.verticalPaddingDp} revision=${snapshot.revision}")
        return WearWidgetDocument(background = WearWidgetBrush.color(Color.Black.rc)) {
            WidgetContent(context, snapshot, params.heightDp, params.containerType == ContainerInfo.CONTAINER_TYPE_LARGE)
        }
    }
}

@Composable @RemoteComposable
private fun WidgetContent(context: Context, snapshot: WatchSnapshot, height: Float, large: Boolean) {
    val rowHeight = if (large) 32f else (height - 32f).coerceAtLeast(20f)
    val numberSize = minOf(24f, rowHeight * .8f)
    val iconSize = minOf(22f, rowHeight - 2f) * 2f / 3f
    val tap = pendingIntentAction { WatchIntents.open(it) }
    val weather = RemoteImageBitmap(WidgetIconRenderer.weather(context, snapshot.condition, 32, false).asImageBitmap())
    RemoteColumn(RemoteModifier.fillMaxSize().clickable(tap), verticalArrangement = RemoteArrangement.SpaceBetween, horizontalAlignment = RemoteAlignment.CenterHorizontally) {
        RemoteRow(RemoteModifier.fillMaxWidth().height(13.rdp), horizontalArrangement = RemoteArrangement.SpaceBetween, verticalAlignment = RemoteAlignment.CenterVertically) {
            RemoteText(snapshot.region.rs, modifier = RemoteModifier.weight(1.rf), fontSize = 9.5f.rsp, fontWeight = FontWeight.Normal, color = Accent.rc, maxLines = 1, overflow = TextOverflow.Ellipsis)
            RemoteText((snapshot.time + if (!snapshot.hasData) "" else if (snapshot.stale()) " 오래됨" else " 기준").rs, fontSize = 9.rsp, fontWeight = FontWeight.Normal, color = Muted.rc, maxLines = 1)
        }
        RemoteRow(RemoteModifier.fillMaxWidth().height(rowHeight.rdp).clip(RemoteRoundedCornerShape(10.rdp)).background(Panel.rc),
            horizontalArrangement = RemoteArrangement.Center, verticalAlignment = RemoteAlignment.CenterVertically) {
            RemoteText(compactTemperature(snapshot.temperature).rs, color = Ink.rc, fontSize = numberSize.rsp, fontWeight = FontWeight.Bold, maxLines = 1)
            RemoteBox(RemoteModifier.width(6.rdp)) { }
            RemoteImage(weather, "현재 날씨".rs, RemoteModifier.size(iconSize.rdp))
            RemoteText("  ·  ".rs, color = Accent.rc, fontSize = 12.rsp, fontWeight = FontWeight.Normal)
            RemoteText("체감 ".rs, color = Accent.rc, fontSize = 9.5f.rsp, fontWeight = FontWeight.Normal)
            RemoteText(compactTemperature(snapshot.apparent).rs, color = Ink.rc, fontSize = minOf(17f, rowHeight * .72f).rsp, fontWeight = FontWeight.Bold, maxLines = 1)
        }
        if (large) RemoteRow(horizontalArrangement = RemoteArrangement.spacedBy(13.rdp), verticalAlignment = RemoteAlignment.CenterVertically) {
            for (prep in snapshot.preparations().take(3)) {
                RemoteBox(RemoteModifier.size(26.rdp).clip(RemoteRoundedCornerShape(13.rdp)).background(Panel.rc), contentAlignment = RemoteAlignment.Center) {
                    RemoteImage(RemoteImageBitmap(WatchIcons.preparation(context, prep.type, 24).asImageBitmap()), prep.label.rs, RemoteModifier.size(20.rdp))
                }
            }
        }
        RemoteText("최저 ${compactTemperature(snapshot.minimum)}  ·  최고 ${compactTemperature(snapshot.maximum)}".rs, color = Accent.rc, fontSize = 11.rsp, fontWeight = FontWeight.Normal, maxLines = 1)
    }
}

internal object WatchIntents {
    fun open(context: Context): PendingIntent = PendingIntent.getActivity(context, 7,
        Intent(context, WatchActivity::class.java).putExtra("screen", "weather"),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
}

internal object WatchIcons {
    fun preparation(context: Context, type: String, size: Int): android.graphics.Bitmap {
        val original = WidgetIconRenderer.preparation(context, type, size)
        val output = android.graphics.Bitmap.createBitmap(original.width, original.height, android.graphics.Bitmap.Config.ARGB_8888)
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            colorFilter = android.graphics.PorterDuffColorFilter(android.graphics.Color.rgb(157, 189, 216), android.graphics.PorterDuff.Mode.SRC_IN)
        }
        android.graphics.Canvas(output).drawBitmap(original, 0f, 0f, paint)
        original.recycle()
        return output
    }
}
