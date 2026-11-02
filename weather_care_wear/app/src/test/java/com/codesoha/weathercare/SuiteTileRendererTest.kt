package com.codesoha.weathercare

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.time.Instant

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SuiteTileRendererTest {
    private fun context(scale: Float = 1f): Context {
        val application = RuntimeEnvironment.getApplication()
        val configuration = Configuration(application.resources.configuration).apply {
            fontScale = scale
            screenLayout = (screenLayout and Configuration.SCREENLAYOUT_ROUND_MASK.inv()) or Configuration.SCREENLAYOUT_ROUND_YES
        }
        return application.createConfigurationContext(configuration)
    }

    private fun weather(region: String = "서울 구로동", temperature: String = "14.5°", message: String = "오후 비 예보 · 우산 챙겨요"): WatchSnapshot {
        val now = Instant.now()
        return WatchSnapshot(JSONObject().put("widget", JSONObject()
            .put("region", region).put("currentTemperature", temperature).put("condition", "clear")
            .put("minimumTemperature", "9°").put("maximumTemperature", "15°")
            .put("refreshTime", "오후 4:13 기준").put("generatedAt", now.toString())
            .put("validUntil", now.plusSeconds(3600).toString()).put("shortMessage", message)))
    }

    private fun foreground(bitmap: Bitmap): Int {
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        return pixels.count { it != Color.BLACK }
    }

    private fun export(name: String, bitmap: Bitmap) {
        val file = File("build/reports/suite-tile/$name.png")
        file.parentFile?.mkdirs()
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    @Test fun fontSizeSettingChangesPixelsAtTheSameOutputResolution() {
        val normal = SuiteTileRenderer(context()).render(weather(), 227, 227, 2f)
        val enlarged = SuiteTileRenderer(context(1.3f)).render(weather(), 227, 227, 2f)
        assertEquals(454, normal.bitmap.width)
        assertEquals(normal.bitmap.width, enlarged.bitmap.width)
        assertTrue("큰 글자 설정에서 글자 픽셀이 증가해야 한다", foreground(enlarged.bitmap) > foreground(normal.bitmap))
        export("normal", normal.bitmap)
        export("large-font", enlarged.bitmap)
    }

    @Test fun readableDescriptionPreservesFullTextAndAllWeatherValues() {
        val longRegion = "서울특별시 구로구 구로제삼동"
        val message = "오후부터 비와 강한 바람 예보가 있으니 우산과 겉옷을 챙겨요"
        val rendered = SuiteTileRenderer(context(1.3f)).render(weather(longRegion, "-12.5°", message), 192, 192, 2f)
        for (text in listOf(longRegion, "기온 -12.5°", message, "최저 9°", "최고 15°", "오후 4:13 기준", "현재 날씨를 엽니다")) {
            assertTrue(text, rendered.description.contains(text))
        }
        assertFalse(rendered.description.contains("기준 기준"))
        export("small-screen-long-text", rendered.bitmap)
    }

    @Test fun textStaysInsideRoundScreensAtSupportedFontSizes() {
        for (size in listOf(192, 227, 240)) for (scale in listOf(1f, 1.3f)) for (longText in listOf(false, true)) {
            val data = if (longText) weather("서울특별시 구로구 구로제삼동", "-12.5°", "오후부터 비와 강한 바람 예보가 있으니 우산과 겉옷을 챙겨요") else weather()
            val bitmap = SuiteTileRenderer(context(scale)).render(data, size, size, 2f).bitmap
            val radius = bitmap.width / 2f
            for (y in 0 until bitmap.height) for (x in 0 until bitmap.width) {
                if (bitmap.getPixel(x, y) == Color.BLACK) continue
                val distanceSquared = (x + .5f - radius) * (x + .5f - radius) + (y + .5f - radius) * (y + .5f - radius)
                assertTrue("${size}dp, 배율 $scale: ($x,$y)가 원형 화면 밖", distanceSquared < (radius - 2) * (radius - 2))
            }
            assertTrue(foreground(bitmap) > 1000)
            export("${size}dp-font-$scale${if (longText) "-long" else ""}", bitmap)
        }
    }

    @Test fun olderResourceRequestsKeepOriginalPixelsAfterWeatherChanges() {
        val application = context()
        val store = TileImageStore(application)
        val first = SuiteTileRenderer(application).render(weather(), 227, 227, 2f).bitmap
        val originalVersion = store.save(first)
        assertEquals(originalVersion, store.save(first))
        val changed = SuiteTileRenderer(application).render(weather(temperature = "20°"), 227, 227, 2f).bitmap
        val newVersion = store.save(changed)
        assertNotEquals(originalVersion, newVersion)
        val resources = TileImageStore(application).load(originalVersion)
        assertEquals(originalVersion, resources.version)
        val bytes = resources.idToImageMapping.getValue(TileImageStore.IMAGE_ID).inlineResource!!.data
        val restored = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        assertTrue("새 날씨를 받은 뒤에도 이전 레이아웃 리소스는 바뀌면 안 된다", first.sameAs(restored))
    }

    @Test fun noDataStillHasAVisibleConnectionPrompt() {
        val rendered = SuiteTileRenderer(context()).render(WatchSnapshot.EMPTY, 192, 192, 2f)
        assertTrue(rendered.description.contains("휴대전화에서 날씨를 연결해 주세요"))
        assertTrue(foreground(rendered.bitmap) > 1000)
        export("no-data", rendered.bitmap)
    }
}
