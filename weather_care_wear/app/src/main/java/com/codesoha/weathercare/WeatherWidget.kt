package com.codesoha.weathercare

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.text.TextPaint
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import androidx.compose.remote.creation.compose.action.pendingIntentAction
import androidx.compose.remote.creation.compose.layout.*
import androidx.compose.remote.creation.compose.modifier.*
import androidx.compose.remote.creation.compose.shapes.RemoteRoundedCornerShape
import androidx.compose.remote.creation.compose.state.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.glance.wear.*
import androidx.glance.wear.core.WearWidgetParams
import androidx.glance.wear.core.ContainerInfo
import kotlin.math.ceil

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
            WidgetContent(context, snapshot, params.widthDp, params.heightDp,
                params.containerType == ContainerInfo.CONTAINER_TYPE_LARGE)
        }
    }
}

@Composable @RemoteComposable
private fun WidgetContent(context: Context, snapshot: WatchSnapshot, width: Float, height: Float, large: Boolean) {
    val rowHeight = if (large) 32f else (height - 32f).coerceAtLeast(20f)
    val numberSize = minOf(24f, rowHeight * .8f)
    val iconSize = minOf(22f, rowHeight - 2f) * 2f / 3f
    val tap = pendingIntentAction { WatchIntents.open(it) }
    val weather = RemoteImageBitmap(WidgetIconRenderer.weather(context, snapshot.condition, 32, false).asImageBitmap())
    val text = WidgetTextRenderer(context)
    val timestamp = snapshot.time + if (!snapshot.hasData) "" else if (snapshot.stale()) " 오래됨" else " 기준"
    val time = text.render(timestamp, 9f, Muted, width * .55f, 13f)
    val region = text.render(snapshot.region, 9.5f, Accent, width - time.width - 2f, 13f)
    val temperatureWidth = (width - iconSize - 6f).coerceAtLeast(2f)
    RemoteColumn(RemoteModifier.fillMaxSize().clickable(tap), verticalArrangement = RemoteArrangement.SpaceBetween, horizontalAlignment = RemoteAlignment.CenterHorizontally) {
        RemoteRow(RemoteModifier.fillMaxWidth().height(13.rdp), horizontalArrangement = RemoteArrangement.SpaceBetween, verticalAlignment = RemoteAlignment.CenterVertically) {
            region.Show()
            time.Show()
        }
        RemoteRow(RemoteModifier.fillMaxWidth().height(rowHeight.rdp).clip(RemoteRoundedCornerShape(10.rdp)).background(Panel.rc),
            horizontalArrangement = RemoteArrangement.Center, verticalAlignment = RemoteAlignment.CenterVertically) {
            text.render(compactTemperature(snapshot.temperature), numberSize, Ink,
                temperatureWidth * .42f, rowHeight, bold = true).Show()
            RemoteBox(RemoteModifier.width(6.rdp)) { }
            RemoteImage(weather, "현재 날씨".rs, RemoteModifier.size(iconSize.rdp))
            text.render("  ·  체감 ", 9.5f, Accent, temperatureWidth * .23f, rowHeight).Show()
            text.render(compactTemperature(snapshot.apparent), minOf(17f, rowHeight * .72f),
                Ink, temperatureWidth * .35f, rowHeight, bold = true).Show()
        }
        if (large) RemoteRow(horizontalArrangement = RemoteArrangement.spacedBy(13.rdp), verticalAlignment = RemoteAlignment.CenterVertically) {
            for (prep in snapshot.preparations().take(3)) {
                RemoteBox(RemoteModifier.size(26.rdp).clip(RemoteRoundedCornerShape(13.rdp)).background(Panel.rc), contentAlignment = RemoteAlignment.Center) {
                    RemoteImage(RemoteImageBitmap(WatchIcons.preparation(context, prep.type, 24).asImageBitmap()), prep.label.rs, RemoteModifier.size(20.rdp))
                }
            }
        }
        text.render("최저 ${compactTemperature(snapshot.minimum)}  ·  최고 ${compactTemperature(snapshot.maximum)}",
            11f, Accent, width, 15f).Show()
    }
}

private class WidgetTextRenderer(context: Context) {
    private val metrics = context.resources.displayMetrics
    private val regular = context.resources.getFont(R.font.nanum_square_neo_regular)
    private val bold = context.resources.getFont(R.font.nanum_square_neo_bold)

    fun render(value: String, size: Float, color: Color, maxWidth: Float, maxHeight: Float, bold: Boolean = false): Label {
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            typeface = if (bold) this@WidgetTextRenderer.bold else regular
            textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, size, metrics)
            this.color = color.toArgb()
        }
        val widthLimit = (maxWidth * metrics.density).toInt().coerceAtLeast(1)
        val heightLimit = (maxHeight * metrics.density).toInt().coerceAtLeast(1)
        val lineHeight = paint.descent() - paint.ascent()
        if (lineHeight > heightLimit) paint.textSize *= heightLimit / lineHeight
        val textWidth = paint.measureText(value)
        if (bold && textWidth > widthLimit) paint.textSize *= widthLimit / textWidth
        val visible = TextUtils.ellipsize(value, paint, widthLimit.toFloat(), TextUtils.TruncateAt.END).toString()
        val width = ceil(paint.measureText(visible)).toInt().coerceIn(1, widthLimit)
        val height = ceil(paint.descent() - paint.ascent()).toInt().coerceIn(1, heightLimit)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        Canvas(bitmap).drawText(visible, 0f, -paint.ascent(), paint)
        return Label(bitmap, value, width / metrics.density, height / metrics.density)
    }

    data class Label(val bitmap: Bitmap, val description: String, val width: Float, val height: Float) {
        @Composable @RemoteComposable
        fun Show() {
            RemoteImage(RemoteImageBitmap(bitmap.asImageBitmap()), description.rs,
                RemoteModifier.width(width.rdp).height(height.rdp))
        }
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
