package com.codesoha.weathercare

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.wear.compose.material.Checkbox
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import androidx.wear.compose.material.SwipeToDismissBox
import androidx.wear.compose.foundation.rememberSwipeToDismissBoxState
import androidx.wear.compose.foundation.edgeSwipeToDismiss
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal val Panel = Color(0xFF253747)
internal val Ink = Color(0xFFEDF2F6)
internal val Muted = Color(0xFFAAB7C3)
internal val Accent = Color(0xFF9DBDD8)

class WatchActivity : ComponentActivity() {
    private var requestedPage by mutableIntStateOf(0)
    private var requestRevision by mutableLongStateOf(0)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestedPage = if (intent.getStringExtra("screen") == "weather") 1 else 0
        val repository = WatchRepository.get(this)
        repository.requestRefresh()
        setContent { WatchApp(repository, requestedPage, requestRevision) }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        requestedPage = if (intent.getStringExtra("screen") == "weather") 1 else 0
        requestRevision++
    }
}

@Composable private fun WatchApp(repository: WatchRepository, requestedPage: Int, requestRevision: Long) {
    val snapshot by repository.snapshot.collectAsState()
    val context = LocalContext.current
    val cloud = remember(context) { WatchCloudLink.get(context) }
    val connection by cloud.status.collectAsState()
    var showConnection by remember { mutableStateOf(false) }
    var tick by remember { mutableLongStateOf(0) }
    LaunchedEffect(Unit) { while (true) { delay(30_000); tick++; repository.requestRefresh() } }
    LaunchedEffect(showConnection) {
        while (showConnection) {
            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { runCatching { cloud.refresh() } }
            delay(5000)
        }
    }
    LaunchedEffect(connection.linked, snapshot.publishedAt) {
        if (connection.linked && snapshot.hasData) showConnection = false
    }
    val pager = rememberPagerState(initialPage = requestedPage, pageCount = { 4 })
    var detail by remember { mutableStateOf<WatchMetric?>(null) }
    LaunchedEffect(requestedPage, requestRevision) { detail = null; pager.scrollToPage(requestedPage) }
    val scope = rememberCoroutineScope()
    val activity = LocalActivity.current
    val fonts = remember { FontFamily(Font(R.font.suite_regular), Font(R.font.suite_bold, FontWeight.Bold)) }
    MaterialTheme(colors = androidx.wear.compose.material.Colors(primary = Accent, secondary = Accent, background = Color.Black, surface = Panel),
        typography = androidx.wear.compose.material.Typography(defaultFontFamily = fonts)) {
        key(if (showConnection) "connection" else detail?.name ?: "pages") {
        val dismiss = rememberSwipeToDismissBoxState()
        SwipeToDismissBox(state = dismiss, onDismissed = { if (showConnection) showConnection = false else if (detail != null) detail = null else activity?.finish() }) { background ->
        if (background) Box(Modifier.fillMaxSize().background(Color.Black)) else
        Scaffold(timeText = { TimeText(timeTextStyle = MaterialTheme.typography.caption2.copy(color = Muted, fontSize = 10.sp)) }) {
            if (showConnection) {
                BackHandler { showConnection = false }
                WatchScroll {
                    Label("워치 연결", 17, Accent, true)
                    Label(if (connection.linked) "폰과 연결됐어요" else "폰의 설정 → 워치 연결에서\n아래 코드를 입력해 주세요", 12)
                    if (!connection.linked && connection.code.isNotEmpty()) {
                        Label(connection.code.chunked(4).joinToString("-"), 22, Ink, true)
                        Label("코드는 5분 동안 유효해요", 10, Muted)
                    }
                    if (connection.busy) Label("처리 중이에요", 12, Muted)
                    if (connection.message.isNotEmpty()) Label(connection.message, 11, Muted)
                    if (!connection.busy) {
                        if (connection.linked) {
                            WatchButton("날씨 새로고침") { repository.requestRefresh(true) }
                            WatchButton("연결 해제") { cloud.disconnect() }
                        } else {
                            WatchButton("새 코드 만들기") { cloud.newCode() }
                            WatchButton("서버 연결 취소") { cloud.disconnect() }
                        }
                    }
                    WatchButton("돌아가기") { showConnection = false }
                }
            } else if (detail != null) {
                BackHandler { detail = null }
                val item = detail!!
                WatchScroll {
                    Label(item.name, 18, Accent)
                    Spacer(Modifier.height(12.dp))
                    Label(item.value, 26, Ink, true)
                    Label(snapshot.region + " · " + snapshot.time, 10, Muted)
                    Label(item.basis, 11, Muted)
                    Spacer(Modifier.height(10.dp))
                    Label(item.description, 12)
                    WatchButton("목록으로") { detail = null }
                }
            } else if (!snapshot.hasData) {
                WatchScroll {
                    Label("휴대전화와 연결", 17, Accent, true)
                    Label("휴대전화의 날씨챙겨에서\n날씨를 한 번 확인해 주세요", 12)
                    WatchButton("연결 확인") { repository.requestRefresh(true) }
                    WatchButton("서버로 연결") { showConnection = true; cloud.open() }
                    Label("페어링 또는 연결 코드로\n폰의 날씨를 받을 수 있어요", 10, Muted)
                }
            } else {
                HorizontalPager(state = pager, modifier = Modifier.fillMaxSize().edgeSwipeToDismiss(dismiss)) { page ->
                    key(snapshot.publishedAt, tick) {
                        WatchScroll(active = pager.currentPage == page) {
                            when (page) {
                                0 -> {
                                    Label("챙겨요", 17, Ink, true)
                                    val items = snapshot.preparations()
                                    if (items.isEmpty()) Label(if (snapshot.stale()) "오래된 자료예요\n최신 날씨를 확인해 주세요" else "지금 챙길 물건이 없어요", 12, Muted)
                                    for (item in items) {
                                        var checked by remember(item.type) { mutableStateOf(repository.checked(item.type)) }
                                        Row(Modifier.fillMaxWidth().padding(vertical = 3.dp).background(Panel, RoundedCornerShape(14.dp)), verticalAlignment = Alignment.CenterVertically) {
                                            Row(Modifier.weight(1f).heightIn(min = 48.dp).clickable {
                                                detail = WatchMetric(item.label, "챙겨요", snapshot.time + " 기준", item.reason)
                                            }.padding(start = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                                                PrepIcon(item.type, 25)
                                                Text(item.label, fontSize = 13.sp, color = Ink, modifier = Modifier.padding(start = 5.dp))
                                            }
                                            Box(Modifier.size(48.dp), contentAlignment = Alignment.Center) {
                                                Checkbox(checked = checked, onCheckedChange = { checked = repository.toggle(item.type) }, modifier = Modifier.semantics { contentDescription = item.label + " 챙김" })
                                            }
                                        }
                                    }
                                    Label("총 ${items.size}개 · 아래로", 10, Muted)
                                }
                                1 -> {
                                    Label(snapshot.region, 13, Accent)
                                    Row(Modifier.fillMaxWidth().padding(vertical = 5.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                                        WeatherIcon(snapshot.condition, 38)
                                        Text(snapshot.temperature, color = Ink, fontSize = 44.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 7.dp))
                                    }
                                    Label("체감 ${snapshot.apparent} · 최저 ${snapshot.minimum} / 최고 ${snapshot.maximum}", 10, Muted)
                                    Column(Modifier.fillMaxWidth().padding(top = 8.dp).background(Panel, RoundedCornerShape(12.dp)).padding(vertical = 5.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                        Label(snapshot.comparison, 11, Accent)
                                        Label(snapshot.apparentComparison, 9, Muted)
                                    }
                                    Label(snapshot.time + if (snapshot.stale()) " 기준 · 오래됨" else " 기준", 10, Muted)
                                }
                                2 -> {
                                    Label("타임라인", 17, Ink, true)
                                    val hours = snapshot.hours()
                                    if (hours.isEmpty()) Label("시간별 자료 없음", 12, Muted)
                                    for (hour in hours) Row(Modifier.fillMaxWidth().padding(vertical = 3.dp).background(Panel, RoundedCornerShape(12.dp)).padding(7.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                        Text(hour.label, color = Ink, fontSize = 11.sp)
                                        WeatherIcon(hour.condition, 21)
                                        Text(hour.temperature, color = Ink, fontSize = 16.sp)
                                        Text(hour.rain, color = Accent, fontSize = 10.sp)
                                    }
                                    Label("시간별 예보 · 강수확률", 10, Muted)
                                }
                                else -> {
                                    Label("기상/생활", 17, Ink, true)
                                    for (row in snapshot.metrics.chunked(2)) Row(Modifier.fillMaxWidth().padding(vertical = 3.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                        for (item in row) Column(Modifier.weight(1f).heightIn(min = 50.dp).background(Panel, RoundedCornerShape(13.dp)).clickable { detail = item }.padding(4.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                                            Text(item.name, color = Muted, fontSize = 10.sp)
                                            Text(item.value, color = Ink, fontSize = 13.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                                        }
                                    }
                                    Label("총 ${snapshot.metrics.size}개 · 아래로", 10, Muted)
                                }
                            }
                            Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                listOf("챙김", "날씨", "시간", "생활").forEachIndexed { index, name ->
                                    Text(if (index == pager.currentPage) "●" else "○", color = Accent, fontSize = 10.sp,
                                        modifier = Modifier.sizeIn(minWidth = 24.dp, minHeight = 24.dp).clickable { scope.launch { pager.animateScrollToPage(index) } }.semantics { contentDescription = name + " 화면" })
                                }
                            }
                            WatchButton("새로고침") { repository.requestRefresh(true) }
                            WatchButton("워치 연결") { showConnection = true; cloud.open() }
                        }
                    }
                }
            }
        }
    }
}

}

}

@Composable private fun WatchScroll(active: Boolean = true, content: @Composable ColumnScope.() -> Unit) {
    val scroll = rememberScrollState()
    val focus = remember { FocusRequester() }
    val scope = rememberCoroutineScope()
    LaunchedEffect(active) { if (active) focus.requestFocus() }
    Column(Modifier.fillMaxSize().onRotaryScrollEvent {
        scope.launch { scroll.scrollTo((scroll.value + it.verticalScrollPixels).toInt()) }; true
    }.focusRequester(focus).focusable().verticalScroll(scroll).padding(horizontal = 23.dp, vertical = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally, content = content)
}

@Composable private fun Label(text: String, size: Int, color: Color = Ink, bold: Boolean = false) {
    Text(text, color = color, fontSize = size.sp, fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal, textAlign = TextAlign.Center, modifier = Modifier.padding(vertical = 3.dp))
}
@Composable private fun WatchButton(text: String, onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth().padding(top = 10.dp).heightIn(min = 48.dp).background(Panel, RoundedCornerShape(20.dp)).clickable(onClick = onClick), contentAlignment = Alignment.Center) { Label(text, 13) }
}
@Composable internal fun WeatherIcon(condition: String, size: Int) {
    val context = LocalContext.current
    val bitmap = remember(condition, size) { WidgetIconRenderer.weather(context, condition, size, false).asImageBitmap() }
    Image(bitmap, "날씨 $condition", Modifier.size(size.dp))
}
@Composable internal fun PrepIcon(type: String, size: Int) {
    val context = LocalContext.current
    val bitmap = remember(type, size) { WidgetIconRenderer.preparation(context, type, size).asImageBitmap() }
    Image(bitmap, null, Modifier.size(size.dp), colorFilter = ColorFilter.tint(Accent))
}
