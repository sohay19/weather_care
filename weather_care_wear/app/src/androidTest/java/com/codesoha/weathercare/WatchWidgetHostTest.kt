package com.codesoha.weathercare

import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** 삼성 호스트에 소형·대형을 추가한 뒤 실행. 실제 자료 대신 시험 payload임을 명시한다. */
@RunWith(AndroidJUnit4::class)
class WatchWidgetHostTest {
    @Test fun hostUpdatesWhileWatchAppIsClosedAndTapOpensWeather() {
        val inst=InstrumentationRegistry.getInstrumentation();val context=inst.targetContext
        val device=UiDevice.getInstance(inst);val repo=WatchRepository.get(context)
        val original=context.getSharedPreferences("watch_weather",0).getString("snapshot",null)
        val base=System.currentTimeMillis()+1000
        val folder=File(context.getExternalFilesDir(null),"device-test").apply{mkdirs()}
        fun capture(name:String){device.waitForIdle();android.os.SystemClock.sleep(600);device.takeScreenshot(File(folder,name+".png"))}
        try {
            device.pressHome();android.os.SystemClock.sleep(500)
            assertTrue(repo.accept(WatchDeviceTest.fixture(base,10,"시험 중구")))
            // 앱 Activity를 열지 않고 Data Layer 수신과 동일한 채택/갱신 경로를 실행한다.
            for(i in 0..6) {
                if(device.hasObject(By.descContains("날씨챙겨")))break
                device.swipe(370,219,50,219,20);device.waitForIdle()
                device.wait(Until.hasObject(By.descContains("날씨챙겨")),500)
            }
            android.os.SystemClock.sleep(2000)
            capture("host-fixture-small-and-large")
            device.dumpWindowHierarchy(File(folder,"host-fixture-hierarchy.xml"))
            assertTrue(device.hasObject(By.descContains("날씨챙겨")))
            device.swipe(219,365,219,140,20);capture("host-fixture-large")
            // 현재 화면에 보이는 우리 카드의 중심을 눌러 실제 앱 진입을 확인한다.
            val card=device.findObjects(By.descContains("날씨챙겨")).firstOrNull { it.visibleBounds.width()>150 && !it.contentDescription.startsWith("삭제") }
            assertNotNull(card);card!!.click()
            assertTrue(device.wait(Until.hasObject(By.text("시험 중구")),10000))
            capture("host-tap-current-weather")
            File(folder,"widget-host-checks.json").writeText(JSONObject().put("result","통과").put("fixture",true)
                .put("checks","실제 삼성 호스트의 소형·대형 표시, Activity 미진입 채택 후 갱신, 카드 탭 현재날씨 진입").toString(2))
        } finally {
            val restore=if(original==null)JSONObject().put("schemaVersion",1).put("cleared",true).put("widget",JSONObject()) else JSONObject(original)
            restore.put("revision",base+100).put("publishedAt",base+100)
            repo.accept(restore.toString())
        }
    }
}
