const { chromium } = require('C:/Users/idp20/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const path = require('path');
const fs = require('fs');
(async () => {
  const browser = await chromium.launch({headless:true, executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
  const page = await browser.newPage({viewport:{width:1600,height:1000}, deviceScaleFactor:1});
  const failures = [];
  const isolated = await browser.newPage({viewport:{width:438,height:438}, deviceScaleFactor:1});
  page.on('pageerror', error => failures.push(error.message));
  await page.goto('file:///' + path.join(__dirname,'index.html').replaceAll('\\','/'));
  await page.evaluate(() => document.fonts.ready);
  const styles = await page.locator('style').textContent();
  async function isolatedScreen(svg, name) {
    const content = await svg.evaluate(el => el.outerHTML);
    const dims = await svg.evaluate(el => {const v=el.viewBox.baseVal;return el.classList.contains('widget-card-svg')?[v.width*2,v.height*2]:[438,438]});
    await isolated.setViewportSize({width:dims[0],height:dims[1]});
    await isolated.setContent('<html lang="ko"><head><meta charset="utf-8"><style>'+styles+'</style></head><body style="margin:0;background:#F6F7F8"><div style="width:'+dims[0]+'px;height:'+dims[1]+'px">'+content+'</div></body></html>');
    await isolated.evaluate(() => document.fonts.ready);
    await isolated.locator('svg').evaluate((el,dims) => {el.style.width=dims[0]+'px';el.style.height=dims[1]+'px'},dims);
    await isolated.locator('svg').screenshot({path:path.join(__dirname,'screens',name+'.png')});
  }
  await page.locator('#overview-board').screenshot({path:path.join(__dirname,'overview.png')});
  await page.locator('#widgets-board').screenshot({path:path.join(__dirname,'widgets.png')});
  await page.screenshot({path:path.join(__dirname,'prototype.png')});
  const checks = [];
  async function check(name, expected) {
    const actual = await page.locator('#screen-title').textContent();
    if (actual !== expected) throw Error(name + ': ' + actual);
    checks.push(name);
  }
  await check('첫 화면 챙겨요','챙겨요');
  const cb = page.locator('#preview [data-check="우산"]');
  if (await cb.getAttribute('aria-checked') !== 'false') throw Error('초기 체크박스');
  await cb.click();
  if (await cb.getAttribute('aria-checked') !== 'true') throw Error('챙김 체크');
  await check('우측 체크만 변경, 상세로 이동하지 않음','챙겨요');
  await page.locator('.nav [data-screen="home"]').click();
  if (!(await page.locator('#preview').textContent()).includes('어제보다 2° 낮아요')) throw Error('어제 비교');
  if (!(await page.locator('#preview').textContent()).includes('체감 상 어제보다 3° 낮아요')) throw Error('체감 어제 비교 누락');
  if ((await page.locator('#preview').textContent()).includes('흐림 → 비')) throw Error('어제 날씨 상태 문구 잔존');
  checks.push('어제 기온 비교 아래 체감 비교, 날씨 상태 비교 제거');
  if ((await page.locator('#preview').textContent()).includes('우산 챙겨요')) throw Error('구 브리핑 미제거');
  checks.push('현재 날씨의 작은 어제 비교 영역');
  const homeAligned = await page.locator('#preview [data-home-weather-row]').evaluate(g => {
    const text=g.querySelector('text'),icon=g.querySelector('image');
    return text.getAttribute('dominant-baseline')==='central' && Math.abs(Number(text.getAttribute('y'))-Number(icon.getAttribute('y'))-Number(icon.getAttribute('height'))/2)<1;
  });
  if (!homeAligned) throw Error('현재 날씨 기온/아이콘 중앙 정렬');
  checks.push('현재 날씨 기온·날씨 아이콘 세로 중앙');
  await page.locator('.nav [data-screen="prepare"]').click();
  if (await page.locator('#preview [data-check="우산"]').getAttribute('aria-checked') !== 'true') throw Error('체크 상태 미보존');
  await page.locator('#preview [data-check="우산"]').click();
  if (await page.locator('#preview [data-check="우산"]').getAttribute('aria-checked') !== 'false') throw Error('체크 해제');
  checks.push('화면 이동 후 체크 유지와 해제');
  if (!(await page.locator('#preview').textContent()).includes('총 3개 · 아래로')) throw Error('챙겨요 총개수 문구');
  await page.locator('#preview [data-screen="detail"]').click(); await check('우산 상세 이동','준비물 상세');
  await page.locator('#preview [data-screen="prepare"]').click(); await check('상세에서 목록 복귀','챙겨요');
  await page.locator('#more').click(); await check('준비물 다음 구간','준비물 더 보기');
  await page.locator('.nav [data-screen="hourly"]').click(); await check('명칭 변경과 시각·상태·기온·확률 유지','타임라인');
  for (const text of ['10시','11°','20%']) if (!(await page.locator('#preview').textContent()).includes(text)) throw Error('타임라인 내부 형식');
  await page.locator('.nav [data-screen="alerts"]').click();
  if (await page.locator('#preview [data-screen^="metric-"]').count() !== 4) throw Error('2열 첫 구간');
  await page.locator('#preview [data-screen="metric-1"]').click(); await check('기상생활 항목 상세 데이터','습도 상세');
  if (!(await page.locator('#preview').textContent()).includes('72%')) throw Error('상세 값');
  await page.locator('#back').click(); await check('지표 목록 복귀','기상/생활');
  await page.locator('#more').click(); await check('2열 지표 다음 구간','기상/생활 · 아래 구간');
  await page.locator('#more').click(); await check('2열 지표 마지막 구간','기상/생활 · 마지막 구간');
  for (const text of ['강수량','적설량']) if (!(await page.locator('#preview').textContent()).includes(text)) throw Error('지표 목록 누락');
  if (!(await page.locator('#preview').textContent()).includes('총 10개 · 아래로')) throw Error('기상생활 총개수 문구');
  checks.push('챙겨요·기상생활 총 n개 문구');
  const small = page.locator('#widgets-board .figure').nth(0);
  if (await small.locator('image:not([data-weather])').count()) throw Error('소형에 준비물 잔존');
  for (const text of ['09:35 기준','체감','9°','최저 8°','최고 14°']) if (!(await small.textContent()).includes(text)) throw Error('소형 정보 누락');
  const large = page.locator('#widgets-board .figure').nth(1);
  if (await large.locator('[data-preparation] image').count() !== 3) throw Error('대형 준비물 3개');
  if (await large.locator('[data-preparation] circle').count() !== 3) throw Error('준비물별 원형 배경');
  const expectedRain = 'data:image/png;base64,' + fs.readFileSync(path.resolve(__dirname,'../../icon-previews/weather-color/rain.png')).toString('base64');
  for (const panel of [small,large]) {
    if (await panel.locator('[data-panel]').count() !== 1) throw Error('날씨·체감 통합 배경박스');
    if (await panel.locator('[data-panel="weather-summary"] image[data-weather]').getAttribute('href') !== expectedRain) throw Error('위젯 날씨 아이콘 불일치');
    if (await panel.locator('[data-panel="weather-summary"] > rect').getAttribute('fill') !== '#253747') throw Error('정보박스 이전 위젯 바탕색');
    if (await panel.locator('[data-widget-background]').getAttribute('fill') !== '#000000') throw Error('위젯 검정 바탕');
    const swapped = await panel.locator('[data-panel="weather-summary"]').evaluate(g => {
      const temp=g.querySelector('[data-temperature]'), icon=g.querySelector('image'), dot=g.querySelector('[data-weather-separator]'), apparent=g.querySelector('[data-apparent-line]');
      return Number(temp.getAttribute('x')) < Number(icon.getAttribute('x')) && Number(icon.getAttribute('x'))+Number(icon.getAttribute('width')) < Number(dot.getAttribute('x')) && Number(dot.getAttribute('x')) < Number(apparent.getAttribute('x')) && dot.textContent==='·';
    });
    if (!swapped) throw Error('위젯 아이콘/기온 순서');
    if (Math.abs(Number(await panel.locator('[data-panel] image').getAttribute('width'))-22*2/3)>.01) throw Error('위젯 날씨 아이콘 2/3 축소');
    if (await panel.locator('[data-apparent-line]').count() !== 1) throw Error('체감 한줄');
    if (await panel.locator('[data-apparent-line] tspan').first().getAttribute('font-size') !== '9.5') throw Error('체감 라벨 크기 유지');
    const aligned = await panel.locator('[data-panel="weather-summary"]').evaluate(g => {
      const text=g.querySelector('[data-temperature]'), icon=g.querySelector('image');
      const ty=Number(text.getAttribute('y'));
      const iy=Number(icon.getAttribute('y'))+Number(icon.getAttribute('height'))/2;
      return text.getAttribute('dominant-baseline')==='central' && Math.abs(ty-iy)<=1;
    });
    if (!aligned) throw Error('기온·아이콘 세로 중앙 정렬');
  }
  if (await page.locator('#widgets-board .figure').nth(3).locator('image:not([data-weather])').count()) throw Error('페이스 준비물 잔존');
  checks.push('소형 준비물 제거·상하단 정보, 대형3아이콘, 페이스 날씨 아이콘');
  checks.push('소형·대형 기온+날씨아이콘·중간점·체감의 배경박스 통합');
  checks.push('대형 준비물별 원형 배경3개');
  checks.push('소형·대형 이전 바탕색 박스·2/3 아이콘 중앙 정렬·작은 체감 라벨 한줄');
  for (const circle of await large.locator('[data-preparation] circle').all()) if (await circle.getAttribute('fill') !== '#253747') throw Error('준비물 이전 위젯 바탕색');
  checks.push('검정 위젯 바탕, 이전 바탕색 정보·준비물 배경, 기온 다음 아이콘');
  const bounds = await page.locator('#spec-board [data-widget-content]').evaluateAll(groups => groups.map(g => {
    const w=Number(g.dataset.width),h=Number(g.dataset.height);
    const bad=[...g.children].map(el=>({tag:el.tagName,...{x:el.getBBox().x,y:el.getBBox().y,w:el.getBBox().width,h:el.getBBox().height}})).filter(b=>b.x<-.5||b.y<-.5||b.x+b.w>w+.5||b.y+b.h>h+.5);
    const footer=g.querySelector('[data-minmax]').getBBox();
    return {profile:g.closest('svg').dataset.profile,content:[w,h],outside:bad,footerInside:footer.y>=0&&footer.y+footer.height<=h+.5,footerCentered:Math.abs(footer.x+footer.width/2-w/2)<.5};
  }));
  if(bounds.length!==10||bounds.some(b=>b.outside.length||!b.footerInside||!b.footerCentered))throw Error('공식10규격 콘텐츠경계/최저최고: '+JSON.stringify(bounds));
  checks.push('공식 SDK10규격 콘텐츠경계 안에 전항목, 최저최고 안쪽 중앙하단');
  const tile = page.locator('#widgets-board .figure').nth(2);
  if (await tile.locator('[data-tile-weather-row] image').getAttribute('width') !== '44') throw Error('타일 아이콘 크기');
  if (await tile.locator('[data-tile-weather-row] text').getAttribute('font-size') !== '44') throw Error('타일 기온 크기');
  const tileOrder = await tile.locator('[data-tile-weather-row]').evaluate(g => Number(g.querySelector('image').getAttribute('x')) < Number(g.querySelector('text').getAttribute('x')));
  if (!tileOrder) throw Error('기존 타일 좌측 날씨아이콘·우측 기온');
  if (await tile.locator('text').filter({hasText:'오후 비, 우산 챙겨요'}).getAttribute('y') !== '130') throw Error('타일 중앙 브리핑');
  for (const text of ['서울 중구 · 09:35 기준','최저 8°','최고 14°']) if (!(await tile.textContent()).includes(text)) throw Error('타일 지역·기준·최저최고 누락');
  checks.push('타일 제목 아래 지역·기준 시각, 하단 최저·최고');
  const tileCentered = await tile.locator('[data-tile-main]').evaluate(g => {
    const box=g.getBBox();const shift=g.transform.baseVal.consolidate().matrix.f;
    return Math.abs(box.y+box.height/2+shift-((54+187)/2-8))<1;
  });
  if (!tileCentered) throw Error('타일 주요 묶음 상향 위치');
  checks.push('타일 기온·아이콘·브리핑 묶음 직전 시안보다8dp 상향');
  await tile.locator('[data-screen="home"]').click(); await check('기존 타일 탭은 워치앱 현재 날씨 진입','현재 날씨');
  await page.locator('[data-scene="dry"]').click();
  await page.locator('.nav [data-screen="prepare"]').click();
  if (!(await page.locator('#preview').textContent()).includes('립밤')) throw Error('건조 상황 전환 실패');
  checks.push('건조 상황 보습 준비물');
  await page.locator('[data-scene="stale"]').click(); await check('만료 상황 안내','자료 만료');
  await page.locator('[data-scene="rain"]').click();
  await page.locator('.nav [data-screen="setup"]').click();
  await page.locator('#preview [data-screen="prepare"]').click(); await check('연결 시안 완료 이동','챙겨요');
  fs.mkdirSync(path.join(__dirname,'screens'),{recursive:true});
  for (const name of ['prepare','home','hourly','alerts','prepare-checked','alerts-more','alerts-last','metric-1','offline','setup']) {
    await page.evaluate(name => {ready['우산'] = name==='prepare-checked'},name);
    await page.evaluate(name => show(name,false),name);
    await page.locator('#preview .watch').evaluate(el => {el.style.width='466px';el.style.height='466px';el.style.padding='11px'});
    await isolatedScreen(page.locator('#preview .screen-svg'), name);
  }
  for (const [i,name] of ['small','large','tile','complication'].entries()) {
    const svg = page.locator('#widgets-board .figure .screen-svg').nth(i);
    await isolatedScreen(svg, name);
  }
  await page.setViewportSize({width:390,height:844});
  await page.evaluate(() => show('home',false));
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth);
  if (overflow) throw Error('좁은 시안 페이지 가로 넘침');
  checks.push('390px 페이지 가로 넘침 없음');
  await page.screenshot({path:path.join(__dirname,'mobile-preview.png')});
  if (failures.length) throw Error(failures.join('\n'));
  fs.writeFileSync(path.join(__dirname,'verification.json'),JSON.stringify({결과:'통과',검사:checks,공식규격경계검사:bounds,브라우저오류:failures,기기설치:false,주의:'공식 SDK 프리뷰의 수치에 맞춘 웹 시안 검증. Native SDK 렌더링/기기 호스트 실측은 아님'},null,2));
  await browser.close();
  console.log(JSON.stringify({passed:true,checks:checks.length,jsErrors:failures.length}));
})().catch(e=>{console.error(e);process.exit(1)});
