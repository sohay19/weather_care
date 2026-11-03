package com.codesoha.weathercare

import android.content.Intent
import android.graphics.Bitmap
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.Wearable
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.time.Instant
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class WatchDeviceTest {
    @Test fun watchAppCacheChecksDetailsAndDataLayerAvailability() {
        val inst=InstrumentationRegistry.getInstrumentation()
        val context=inst.targetContext
        val device=UiDevice.getInstance(inst)
        val repo=WatchRepository.get(context)
        val original=context.getSharedPreferences("watch_weather",0).getString("snapshot",null)
        val originalChecks=context.getSharedPreferences("watch_weather",0).all.filter { it.key.contains('|') && it.value is Boolean }
        val base=System.currentTimeMillis()+10
        val checks=mutableListOf<String>()
        val folder=File(context.getExternalFilesDir(null),"device-test").apply{mkdirs()}
        fun capture(name:String){device.waitForIdle();android.os.SystemClock.sleep(400);device.takeScreenshot(File(folder,"$name.png"))}
        fun start(weather:Boolean=false){context.startActivity(Intent(context,WatchActivity::class.java).putExtra("screen",if(weather)"weather" else "prepare").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP));device.waitForIdle()}
        try {
            val nodes=Tasks.await(Wearable.getNodeClient(context).connectedNodes,15,TimeUnit.SECONDS)
            File(folder,"data-layer.json").writeText(JSONObject().put("connectedNodes",nodes.size).put("names",JSONArray(nodes.map{it.displayName})).toString())
            checks.add("Data Layer API 정상 조회: 연결 노드 ${nodes.size}개")
            for(i in 1..3) assertTrue(repo.accept(fixture(base+i,i,"시험 ${i}구역")))
            assertFalse(repo.accept(fixture(base+1,1,"늦은 이전 구역")))
            assertEquals("시험 3구역",repo.value.region)
            if(repo.checked("UMBRELLA")) repo.toggle("UMBRELLA")
            checks.add("연속3회 구역 채택·늦은 이전 응답 거절")
            start()
            assertTrue(device.wait(Until.hasObject(By.text("오늘의 준비물")),10000))
            capture("fixture-prepare")
            val checkbox=device.wait(Until.findObject(By.descContains("우산 챙김")),5000)
            assertNotNull(checkbox)
            device.dumpWindowHierarchy(File(folder,"prepare-hierarchy.xml"))
            checkbox.click();device.waitForIdle()
            assertTrue(device.wait(Until.hasObject(By.descContains("우산 챙김").checked(true)),5000))
            capture("fixture-checked")
            device.dumpWindowHierarchy(File(folder,"checked-hierarchy.xml"))
            assertTrue(repo.checked("UMBRELLA"))
            checks.add("우측 체크박스 선택·상세 이동 분리")
            device.findObject(By.text("우산")).click()
            device.waitForIdle()
            capture("fixture-preparation-detail-top")
            device.swipe(220,340,220,120,20)
            assertTrue(device.wait(Until.hasObject(By.text("목록으로")),5000))
            capture("fixture-preparation-detail")
            device.swipe(5,219,410,219,30)
            capture("fixture-after-edge-back")
            device.dumpWindowHierarchy(File(folder,"after-edge-back.xml"))
            assertTrue(device.wait(Until.hasObject(By.descContains("우산 챙김")),5000))
            device.waitForIdle();assertTrue(repo.checked("UMBRELLA"))
            checks.add("준비물 상세·뒤로 이동·체크 보존")
            assertTrue(repo.accept(fixture(base+4,4,"시험 다른 구역")))
            assertFalse(repo.checked("UMBRELLA"));repo.toggle("UMBRELLA")
            assertTrue(repo.accept(fixture(base+5,5,"시험 3구역")))
            assertTrue(repo.checked("UMBRELLA"))
            checks.add("같은 날 구역을 오갔다 돌아와도 각 체크 보존")
            start(true)
            assertTrue(device.wait(Until.hasObject(By.text("시험 3구역")),5000))
            capture("fixture-current-weather")
            device.swipe(370,160,65,160,20);device.waitForIdle()
            assertTrue(device.wait(Until.hasObject(By.text("오늘의 준비물")),5000))
            device.swipe(370,160,65,160,20);device.waitForIdle()
            assertTrue(device.wait(Until.hasObject(By.text("시간별 예보 · 강수확률")),5000));capture("fixture-timeline")
            device.swipe(370,160,65,160,20);device.waitForIdle()
            assertTrue(device.wait(Until.hasObject(By.text("항목을 눌러 자세한 내용을 확인")),5000));capture("fixture-metrics")
            device.findObject(By.text("습도")).click()
            device.waitForIdle()
            capture("fixture-metric-detail-top")
            device.swipe(220,340,220,120,20)
            assertTrue(device.wait(Until.hasObject(By.text("목록으로")),5000));capture("fixture-metric-detail")
            checks.add("현재날씨·어제비교·타임라인·2열지표·습도상세 화면")
            assertTrue(repo.accept(fixture(base+6,6,"시험 만료구역",true)))
            assertTrue(repo.value.preparations().isEmpty());start(true);capture("fixture-stale")
            checks.add("오래된 자료 표시·만료 준비물 제거")
            device.swipe(5,219,410,219,30)
            assertTrue(device.wait(Until.gone(By.pkg(context.packageName)),5000))
            checks.add("상세 가장자리 뒤로 이동·최상위 가장자리 앱 종료")
            File(folder,"checks.json").writeText(JSONObject().put("result","통과").put("checks",JSONArray(checks)).put("fixture",true).toString(2))
        } finally {
            val restore=if(original==null)JSONObject().put("schemaVersion",1).put("cleared",true).put("widget",JSONObject()) else JSONObject(original)
            restore.put("revision",base+100).put("publishedAt",base+100)
            repo.accept(restore.toString())
            val saved=context.getSharedPreferences("watch_weather",0)
            val editor=saved.edit()
            saved.all.keys.filter{it.contains('|')}.forEach(editor::remove)
            originalChecks.forEach{(key,value)->editor.putBoolean(key,value as Boolean)}
            editor.commit()
            start(true)
        }
    }
    companion object {
        fun fixture(stamp:Long,revision:Int,region:String,stale:Boolean=false):String {
            val now=Instant.now()
            val from=now.minusSeconds(300).toString();val until=now.plusSeconds(3600).toString()
            val preparations=JSONArray().put(JSONObject().put("type","UMBRELLA").put("label","우산"))
                .put(JSONObject().put("type","OUTERWEAR").put("label","겉옷")).put(JSONObject().put("type","SUNSCREEN").put("label","선크림"))
            val widget=JSONObject().put("locationKey",region).put("region",region).put("generatedAt",if(stale)now.minusSeconds(86400).toString() else now.toString())
                .put("refreshTime","12:00").put("condition","rain").put("currentTemperature","11°").put("apparentTemperature","9°").put("minimumTemperature","8°").put("maximumTemperature","14°")
                .put("validUntil",until).put("shortMessage","오후 비, 우산 챙겨요").put("preparations",preparations).put("preparationCatalog",preparations)
                .put("briefingTimeline",JSONArray().put(JSONObject().put("validFrom",from).put("validUntil",until).put("shortMessage","오후 비, 우산 챙겨요").put("recommendedItems",JSONArray(listOf("UMBRELLA","OUTERWEAR","SUNSCREEN")))))
            val hours=JSONArray()
            for(i in 1..3) hours.put(JSONObject().put("at",now.plusSeconds(i*3600L).toString()).put("label","${12+i}시").put("temperature","${10+i}°").put("condition","rain").put("rain","${i*20}%"))
            val metrics=JSONArray()
            WatchSnapshot.METRIC_DESCRIPTIONS.forEach{(name,description)->metrics.put(JSONObject().put("name",name).put("value",if(name=="습도")"72%" else "보통").put("basis","시험 자료 · 12:00 기준").put("description",description))}
            return JSONObject().put("schemaVersion",1).put("revision",revision).put("publishedAt",stamp).put("widget",widget)
                .put("details",JSONObject().put("hours",hours).put("metrics",metrics).put("temperatureComparison","어제보다 2° 낮아요").put("apparentComparison","체감 상 어제보다 3° 낮아요")).toString()
        }
    }
}
