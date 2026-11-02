package com.codesoha.weathercare

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant

class WatchSnapshotTest {
    private val now = Instant.parse("2026-11-02T03:00:00Z")
    private fun snapshot(generated: String = "2026-11-02T02:30:00Z") = WatchSnapshot.parse("""{
        "schemaVersion":1,"revision":1,"publishedAt":1,
        "widget":{"locationKey":"60:121","generatedAt":"$generated","currentTemperature":"0°",
        "preparationCatalog":[{"type":"UMBRELLA","label":"우산"},{"type":"OUTERWEAR","label":"겉옷"}],
        "briefingTimeline":[
        {"validFrom":"2026-11-02T02:00:00Z","validUntil":"2026-11-02T03:00:00Z","shortMessage":"이전","recommendedItems":["UMBRELLA"]},
        {"validFrom":"2026-11-02T03:00:00Z","validUntil":"2026-11-02T04:00:00Z","shortMessage":"다음","recommendedItems":["OUTERWEAR"]}]}}
        """)!!
    @Test fun boundarySelectsNextBriefingAndPreparations() {
        val data=snapshot()
        assertEquals("다음",data.briefing(now))
        assertEquals(listOf("OUTERWEAR"),data.preparations(now).map{it.type})
        assertEquals("이전",data.briefing(now.minusMillis(1)))
    }
    @Test fun expiredBriefingDoesNotShowOldPreparations() {
        assertTrue(snapshot().preparations(now.plusSeconds(3600)).isEmpty())
        assertEquals("최신 날씨를 확인해 주세요",snapshot().briefing(now.plusSeconds(3600)))
    }
    @Test fun staleWeatherNeverRecommendsSupplies() {
        val data=snapshot("2026-11-01T00:00:00Z")
        assertTrue(data.stale(now));assertTrue(data.preparations(now).isEmpty())
    }
    @Test fun missingMetricIsNotZeroAndAllTenArePresent() {
        val data=snapshot();assertEquals(10,data.metrics.size)
        assertEquals("자료 없음",data.metrics[1].value);assertEquals("0°",data.temperature)
    }
    @Test fun checkScopeFollowsRegionAndKoreanDate() {
        assertNotEquals(snapshot().checkKey("UMBRELLA",now),snapshot().checkKey("UMBRELLA",now.plusSeconds(86400)))
        val other=snapshot();other.widget.put("locationKey","61:122")
        assertNotEquals(snapshot().checkKey("UMBRELLA",now),other.checkKey("UMBRELLA",now))
    }
    @Test fun malformedOrFutureSchemaIsRejected() {
        assertNull(WatchSnapshot.parse("bad"))
        assertNull(WatchSnapshot.parse(snapshot().json.put("schemaVersion",2).toString()))
        assertNull(WatchSnapshot.parse(JSONObject().put("schemaVersion",1).toString()))
    }
    @Test fun compactTemperaturesKeepSignZeroAndMissing() {
        assertEquals("-19°",compactTemperature("-18.5°"))
        assertEquals("0°",compactTemperature("0°"))
        assertEquals("--",compactTemperature("--"))
    }
    @Test fun serverClockMakesRemoteLabDatesComparable() {
        val data = snapshot(java.time.Instant.now().plusSeconds(60 * 86400).toString())
        data.json.put("_serverClockOffsetMs", 60L * 86400 * 1000)
        assertFalse(data.stale())
        data.json.put("_serverClockOffsetMs", 64L * 86400 * 1000)
        assertTrue(data.stale())
    }
    @Test fun phoneRefreshLabelDoesNotDuplicateBasisSuffix() {
        val data = snapshot()
        data.widget.put("refreshTime", "오후 3:48 기준")
        assertEquals("오후 3:48", data.time)
    }
}
