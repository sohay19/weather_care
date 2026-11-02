package com.codesoha.weathercare

import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId

data class Preparation(val type: String, val label: String, val reason: String)
data class WatchMetric(val name: String, val value: String, val basis: String, val description: String)
data class WatchHour(val at: Instant, val label: String, val temperature: String, val condition: String, val rain: String)

/** 화면·위젯·타일이 같은 시각에 같은 자료와 브리핑 구간을 선택한다. */
class WatchSnapshot(val json: JSONObject) {
    val revision = json.optLong("revision")
    val publishedAt = json.optLong("publishedAt")
    val widget = json.optJSONObject("widget") ?: JSONObject()
    private val details = json.optJSONObject("details") ?: JSONObject()
    val region: String get() = widget.text("region", "휴대전화 연결 필요")
    val locationKey: String get() = widget.text("locationKey", "none")
    val generatedAt = instant(widget.optString("generatedAt"))
    val hasData get() = widget.has("currentTemperature")
    val temperature get() = widget.text("currentTemperature", "--")
    val apparent get() = widget.text("apparentTemperature", "--")
    val condition get() = widget.text("condition", "unknown")
    val minimum get() = widget.text("minimumTemperature", "--")
    val maximum get() = widget.text("maximumTemperature", "--")
    val time get() = widget.text("refreshTime", "--:--").removeSuffix(" 기준").trim()

    fun now(): Instant = Instant.now().plusMillis(json.optLong("_serverClockOffsetMs", 0))

    fun stale(now: Instant = now()): Boolean = generatedAt == null ||
        generatedAt.isAfter(now.plusSeconds(300)) || generatedAt.plusSeconds(3 * 3600).isBefore(now)

    private fun active(now: Instant): JSONObject? = widget.optJSONArray("briefingTimeline").objects().firstOrNull {
        val from = instant(it.optString("validFrom")); val until = instant(it.optString("validUntil"))
        from != null && until != null && !now.isBefore(from) && now.isBefore(until)
    }

    fun briefing(now: Instant = now()): String {
        if (!hasData) return "휴대전화에서 날씨를 연결해 주세요"
        if (stale(now)) return "오래된 자료 · 다시 확인해 주세요"
        val entry = active(now)
        if (entry != null) return entry.text("shortMessage", "최신 날씨를 확인해 주세요")
        val until = instant(widget.optString("validUntil"))
        return if (until != null && now.isBefore(until)) widget.text("shortMessage", "최신 날씨를 확인해 주세요")
        else "최신 날씨를 확인해 주세요"
    }

    fun preparations(now: Instant = now()): List<Preparation> {
        if (stale(now)) return emptyList()
        val entry = active(now)
        val catalog = (widget.optJSONArray("preparationCatalog") ?: widget.optJSONArray("preparations")).objects()
        val selected = if (entry != null) {
            val types = entry.optJSONArray("recommendedItems")
            (0 until (types?.length() ?: 0)).map { types!!.optString(it) }.mapNotNull { type -> catalog.firstOrNull { it.optString("type") == type } }
        } else {
            val until = instant(widget.optString("validUntil"))
            if (until == null || !now.isBefore(until)) emptyList() else widget.optJSONArray("preparations").objects()
        }
        val reasons = details.optJSONObject("preparationReasons") ?: JSONObject()
        return selected.distinctBy { it.optString("type") }.map { Preparation(it.optString("type"), it.text("label", "준비물"), reasons.text(it.optString("type"), "현재 브리핑에서 추천한 준비물이에요.")) }
    }

    fun hours(now: Instant = now()): List<WatchHour> = if (stale(now)) emptyList() else
        details.optJSONArray("hours").objects().mapNotNull {
            val at = instant(it.optString("at")) ?: return@mapNotNull null
            if (!at.isAfter(now)) return@mapNotNull null
            WatchHour(at, it.text("label", "--시"), it.text("temperature", "--"), it.text("condition", "unknown"), it.text("rain", "--"))
        }.sortedBy { it.at }.take(12)

    val metrics: List<WatchMetric> get() = METRIC_DESCRIPTIONS.map { (name, description) ->
        val raw = details.optJSONArray("metrics").objects().firstOrNull { it.optString("name") == name }
        WatchMetric(name, raw?.text("value", "자료 없음") ?: "자료 없음", raw?.text("basis", "기준 시각 없음") ?: "기준 시각 없음", raw?.text("description", description) ?: description)
    }
    val comparison get() = details.text("temperatureComparison", "어제 비교 자료 없음")
    val apparentComparison get() = details.text("apparentComparison", "체감 비교 자료 없음")

    fun checkKey(type: String, now: Instant = now()) = "$locationKey|${now.atZone(ZoneId.of("Asia/Seoul")).toLocalDate()}|$type"

    companion object {
        fun parse(raw: String): WatchSnapshot? = runCatching {
            val obj = JSONObject(raw)
            require(obj.optInt("schemaVersion") == 1)
            require(obj.optLong("revision") > 0 && obj.optLong("publishedAt") > 0)
            val widget = obj.optJSONObject("widget") ?: error("widget")
            require(obj.optBoolean("cleared") || widget.has("locationKey") && widget.has("generatedAt"))
            WatchSnapshot(obj)
        }.getOrNull()
        val EMPTY get() = WatchSnapshot(JSONObject())
        val METRIC_DESCRIPTIONS = linkedMapOf(
            "체감온도" to "기온·바람·습도를 반영한 체감온도예요.",
            "습도" to "현재 상대습도예요. 낮으면 보습 준비물을 챙겨요.",
            "자외선" to "자료가 제공되는 시각의 자외선 지수예요.",
            "바람" to "현재 풍속과 풍향을 확인해요.",
            "대기질" to "미세먼지·초미세먼지 관측 자료예요.",
            "대기정체" to "대기 순환 예측 단계이며 미세먼지 농도와 달라요.",
            "가시거리" to "현재 수평 가시거리 관측 자료예요.",
            "꽃가루" to "제공 기간의 꽃가루 위험 예측이에요.",
            "강수량" to "최근 강수 관측이며 미래 강수확률과 달라요.",
            "적설량" to "현재 관측 적설이며 예보 신적설과 달라요."
        )
    }
}

internal fun JSONObject.text(key: String, fallback: String): String = optString(key).takeIf { it.isNotBlank() && it != "null" } ?: fallback
internal fun JSONArray?.objects(): List<JSONObject> = (0 until (this?.length() ?: 0)).mapNotNull { this?.optJSONObject(it) }
internal fun instant(value: String?): Instant? = runCatching { Instant.parse(value) }.getOrNull()
internal fun compactTemperature(value: String): String = value.removeSuffix("°").toDoubleOrNull()?.takeIf { it.isFinite() }?.let {
    "${(kotlin.math.sign(it) * kotlin.math.floor(kotlin.math.abs(it) + .5)).toInt()}°"
} ?: value
