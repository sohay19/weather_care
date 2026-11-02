package com.codesoha.weathercare

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** 사용자가 폰 없이 UI를 살펴보도록 명시적으로 실행하는 시험 자료 준비 도구. 일반 APK에는 포함되지 않는다. */
@RunWith(AndroidJUnit4::class)
class WatchPreviewTest {
    @Test fun prepareUiPreviewForUser() {
        val repository = WatchRepository.get(InstrumentationRegistry.getInstrumentation().targetContext)
        val stamp = maxOf(System.currentTimeMillis(), repository.value.publishedAt + 1)
        val payload = JSONObject(WatchDeviceTest.fixture(stamp, 1, "UI 시험 자료"))
        val widget = payload.getJSONObject("widget")
        val now = Instant.now().atZone(ZoneId.systemDefault())
        widget.put("refreshTime", now.format(DateTimeFormatter.ofPattern("HH:mm")))
        val details = payload.getJSONObject("details")
        val values = listOf("9°", "72%", "3 보통", "2.4m/s", "좋음", "보통", "12km", "낮음", "0mm", "0cm")
        val metrics = details.getJSONArray("metrics")
        for (index in values.indices) metrics.getJSONObject(index)
            .put("value", values[index]).put("basis", "UI 시험 자료 · ${widget.getString("refreshTime")} 기준")
        val hours = details.getJSONArray("hours")
        for (index in 0 until hours.length()) {
            val at = now.plusHours(index + 1L).withMinute(0).withSecond(0).withNano(0)
            hours.getJSONObject(index).put("at", at.toInstant().toString()).put("label", "${at.hour}시")
        }
        details.put("preparationReasons", JSONObject()
            .put("UMBRELLA", "UI 확인용 시험 자료예요. 오후 비에 대비해 우산을 챙겨요.")
            .put("OUTERWEAR", "UI 확인용 시험 자료예요. 쌀쌀한 시간에 입을 겉옷을 챙겨요.")
            .put("SUNSCREEN", "UI 확인용 시험 자료예요. 낮 자외선에 대비해 선크림을 챙겨요."))
        assertTrue(repository.accept(payload.toString()))
        assertTrue(repository.value.hasData)
        // Instrumentation 종료가 갱신 요청을 중단하지 않도록 호스트 전달까지 기다린다.
        kotlinx.coroutines.runBlocking { WeatherWidget().triggerUpdateAll(InstrumentationRegistry.getInstrumentation().targetContext) }
        android.os.SystemClock.sleep(2500)
    }
}
