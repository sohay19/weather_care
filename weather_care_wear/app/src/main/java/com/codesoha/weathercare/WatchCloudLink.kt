package com.codesoha.weathercare

import android.content.Context
import com.codesoha.weathercare.wearbridge.WearCloudHttp
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

data class CloudLinkState(val code: String = "", val linked: Boolean = false, val busy: Boolean = false, val message: String = "")

/** 블루투스 페어링 없는 워치를 위한 별도 서버 읽기 권한. */
class WatchCloudLink private constructor(private val context: Context) {
    private val saved = context.getSharedPreferences("watch_cloud_link", Context.MODE_PRIVATE)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val state = MutableStateFlow(CloudLinkState(saved.getString("code", "")!!, saved.getBoolean("linked", false)))
    val status = state.asStateFlow()
    val configured get() = !saved.getString("token", "").isNullOrEmpty()

    fun open() { if (!configured) newCode() else scope.launch { runCatching { refresh() } } }

    fun newCode() {
        if (state.value.busy || state.value.linked) return
        state.value = state.value.copy(busy = true, message = "")
        scope.launch { synchronized(this@WatchCloudLink) {
            try {
                val token = saved.getString("token", "")!!.ifEmpty { WearCloudHttp.newToken() }
                if (!saved.edit().putString("token", token).commit()) error("저장 실패")
                val response = WearCloudHttp.request("POST", "pair", token, null)
                val code = response.getString("code")
                if (!saved.edit().putString("code", code).putBoolean("linked", false).commit()) error("저장 실패")
                WatchRepository.get(context).clear()
                WatchRepository.get(context).requestRefresh(true)
                state.value = CloudLinkState(code = code)
            } catch (error: Exception) {
                if (error is WearCloudHttp.Failure && error.status == 409) {
                    state.value = state.value.copy(busy = false)
                    runCatching { refresh() }
                }
                state.value = state.value.copy(busy = false, message = if (state.value.linked) "연결되어 있어요" else "코드를 만들지 못했어요. 다시 시도해 주세요")
            }
        } }
    }

    @Synchronized fun refresh(): Boolean {
        if (state.value.busy) return false
        val token = saved.getString("token", "")!!.ifEmpty { return false }
        try {
            val response = WearCloudHttp.request("GET", "snapshot", token, null)
            val linked = response.optBoolean("linked")
            saved.edit().putBoolean("linked", linked).apply()
            state.value = state.value.copy(linked = linked, message = "")
            val payload = response.optJSONObject("payload")
            if (linked && payload != null) {
                // 리모트랩 시계가 달라도 서버 시각으로 자료 유효성을 판단한다.
                val offset = response.getLong("serverTime") - System.currentTimeMillis()
                payload.put("_serverClockOffsetMs", offset)
                val repository = WatchRepository.get(context)
                repository.accept(payload.toString())
                repository.updateServerClock(payload.getLong("publishedAt"), offset)
            }
            return linked
        } catch (error: WearCloudHttp.Failure) {
            if (error.status == 404) {
                saved.edit().clear().commit()
                state.value = CloudLinkState(message = "연결이 해제됐어요. 새 코드를 만들어 주세요")
                WatchRepository.get(context).clear()
                return false
            }
            throw error
        }
    }

    fun disconnect() {
        if (state.value.busy) return
        state.value = state.value.copy(busy = true)
        scope.launch { synchronized(this@WatchCloudLink) {
            try {
                saved.getString("token", "")!!.takeIf { it.isNotEmpty() }?.let { WearCloudHttp.request("DELETE", "link", it, null) }
                saved.edit().clear().commit()
                state.value = CloudLinkState()
                WatchRepository.get(context).clear()
            } catch (_: Exception) { state.value = state.value.copy(busy = false, message = "연결 해제를 다시 시도해 주세요") }
        } }
    }
    companion object {
        @Volatile private var instance: WatchCloudLink? = null
        fun get(context: Context): WatchCloudLink = instance ?: synchronized(this) {
            instance ?: WatchCloudLink(context.applicationContext).also { instance = it }
        }
    }
}
