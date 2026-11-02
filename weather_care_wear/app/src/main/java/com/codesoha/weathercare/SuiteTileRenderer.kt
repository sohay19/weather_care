package com.codesoha.weathercare

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** 타일 호스트의 시스템 폰트 대신 앱에 포함된 SUITE로 실제 해상도에서 그린다. */
internal class SuiteTileRenderer(private val context: Context) {
    data class Rendered(val bitmap: Bitmap, val description: String)
    private val regular = context.resources.getFont(R.font.suite_regular)
    private val bold = context.resources.getFont(R.font.suite_bold)

    fun render(data: WatchSnapshot, width: Int, height: Int, density: Float): Rendered {
        require(width > 0 && height > 0 && density > 0 && density.isFinite())
        val bitmap = Bitmap.createBitmap((width * density).roundToInt().coerceAtLeast(1),
            (height * density).roundToInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.BLACK)
        canvas.scale(density, density)
        val briefing = data.briefing()
        val location = "${data.region} · ${data.time} 기준"
        val extremes = "최저 ${data.minimum}  ·  최고 ${data.maximum}"
        val white = 0xFFEDF2F6.toInt()
        val blue = 0xFF9DBDD8.toInt()
        val muted = 0xFFAAB7C3.toInt()
        var iconSize = 44f
        var rowGap = 12f

        fun text(value: String, size: Float, color: Int, maxWidth: Float, lines: Int = 1, strong: Boolean = false, fit: Boolean = false): StaticLayout {
            val layoutWidth = maxWidth.toInt().coerceAtLeast(1)
            val paint = TextPaint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
                typeface = if (strong) bold else regular
                // Android의 글자 크기 설정(비선형 확대 포함)을 반영한다.
                textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, size, context.resources.displayMetrics) /
                    context.resources.displayMetrics.density
                this.color = color
                if (fit && measureText(value) > layoutWidth - 1) textSize *= (layoutWidth - 1).coerceAtLeast(1) / measureText(value)
            }
            return StaticLayout.Builder.obtain(value, 0, value.length, paint, layoutWidth)
                .setAlignment(Layout.Alignment.ALIGN_CENTER).setIncludePad(true)
                .setMaxLines(lines).setEllipsize(TextUtils.TruncateAt.END).build()
        }
        var title = text("날씨챙겨", 13f, blue, width * .58f, strong = true)
        var region = text(location, 10f, muted, width * .82f)
        val naturalTemperature = text(data.temperature, 44f, white, width.toFloat(), strong = true)
        if (naturalTemperature.getLineWidth(0) + iconSize + rowGap > width * .9f) {
            rowGap = 8f
            iconSize = (width * .9f - naturalTemperature.getLineWidth(0) - rowGap).coerceIn(24f, 44f)
        }
        // 기온은 말줄임하지 않는다. 긴 음수는 아이콘을 먼저 줄이고 남는 폭에 맞춘다.
        val temperature = text(data.temperature, 44f, white, width * .9f - iconSize - rowGap, strong = true, fit = true)
        var summary = text(briefing, 11f, white, width * .84f, lines = 2)
        fun extremes(maxWidth: Float): StaticLayout {
            val singleLine = text(extremes, 11f, blue, maxWidth)
            return if (singleLine.getEllipsisCount(0) == 0) singleLine
            else text("최저 ${data.minimum}\n최고 ${data.maximum}", 11f, blue, maxWidth, lines = 2)
        }
        var minMax = extremes(width * .72f)
        val rowHeight = max(iconSize, temperature.height.toFloat())
        val originalGaps = listOf(5f, 13f, 5f, 20f)
        fun gapScale(): Float {
            val textHeight = title.height + region.height + rowHeight + summary.height + minMax.height
            return ((height * .82f - textHeight) / originalGaps.sum()).coerceIn(0f, 1f)
        }
        // 원형 화면의 위·아래에서도 글자가 잘리지 않도록 각 행의 유효 폭을 구한다.
        fun safeWidth(y: Float, blockHeight: Int): Float {
            if (!context.resources.configuration.isScreenRound) return width * .9f
            val distance = max(kotlin.math.abs(y - height / 2f), kotlin.math.abs(y + blockHeight - height / 2f))
            val ratio = (distance / (height / 2f)).coerceAtMost(.98f)
            return (width * sqrt(1f - ratio * ratio) - 12f).coerceAtLeast(width * .4f)
        }
        // 폭 조정으로 브리핑 줄 수가 바뀔 수 있어 높이를 다시 계산한다.
        repeat(2) {
            val gaps = originalGaps.map { it * gapScale() }
            var y = (height - title.height - region.height - rowHeight - summary.height - minMax.height - gaps.sum()) / 2f
            title = text("날씨챙겨", 13f, blue, minOf(width * .58f, safeWidth(y, title.height)), strong = true)
            y += title.height + gaps[0]
            region = text(location, 10f, muted, minOf(width * .82f, safeWidth(y, region.height)))
            y += region.height + gaps[1] + rowHeight + gaps[2]
            summary = text(briefing, 11f, white, minOf(width * .84f, safeWidth(y, summary.height)), lines = 2)
            y += summary.height + gaps[3]
            minMax = extremes(minOf(width * .72f, safeWidth(y, minMax.height)))
        }
        val gaps = originalGaps.map { it * gapScale() }
        var y = (height - title.height - region.height - rowHeight - summary.height - minMax.height - gaps.sum()) / 2f
        fun draw(layout: StaticLayout) {
            canvas.save()
            canvas.translate((width - layout.width) / 2f, y)
            layout.draw(canvas)
            canvas.restore()
            y += layout.height
        }
        draw(title); y += gaps[0]
        draw(region); y += gaps[1]
        val tempWidth = (0 until temperature.lineCount).maxOf { temperature.getLineWidth(it) }
        val rowLeft = (width - iconSize - rowGap - tempWidth) / 2f
        val icon = WidgetIconRenderer.weather(context, data.condition, iconSize.toInt(), false)
        val iconTop = y + (rowHeight - iconSize) / 2f
        canvas.drawBitmap(icon, null, RectF(rowLeft, iconTop, rowLeft + iconSize, iconTop + iconSize), Paint(Paint.FILTER_BITMAP_FLAG))
        icon.recycle()
        canvas.save()
        canvas.translate(rowLeft + iconSize + rowGap - (temperature.width - tempWidth) / 2f,
            y + (rowHeight - temperature.height) / 2f)
        temperature.draw(canvas)
        canvas.restore()
        y += rowHeight + gaps[2]
        draw(summary); y += gaps[3]
        draw(minMax)
        val description = "날씨챙겨. ${data.region}. ${data.time} 기준. 기온 ${data.temperature}. " +
            "$briefing. 최저 ${data.minimum}. 최고 ${data.maximum}. 누르면 현재 날씨를 엽니다."
        return Rendered(bitmap, description)
    }
}
