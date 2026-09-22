const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { chromium } = require('playwright');

const root = path.join(__dirname, 'public');
const dataPath = path.join(root, 'weather-map', 'data', 'grid-areas.json');
const naverMapStub = `
(() => {
  class LatLng {
    constructor(latitude, longitude) {
      this.latitude = latitude;
      this.longitude = longitude;
    }
  }
  class Feature {
    constructor(source) {
      this.id = String(source.id);
      this.properties = source.properties || {};
    }
    getProperty(name) { return this.properties[name]; }
  }
  class DataLayer {
    constructor() {
      this.features = new Map();
      this.listeners = {};
    }
    setStyle(style) { this.style = style; }
    addGeoJson(collection) {
      return collection.features.map((source) => {
        const feature = new Feature(source);
        this.features.set(feature.id, feature);
        return feature;
      });
    }
    addListener(name, listener) { this.listeners[name] = listener; }
    overrideStyle(feature, style) { feature.overrideStyle = style; }
    revertStyle(feature) { feature.overrideStyle = undefined; }
  }
  class NaverMap {
    constructor(element, options) {
      this.element = element;
      this.center = options.center;
      this.zoom = options.zoom;
      this.data = new DataLayer();
      element.dataset.zoomControl = String(options.zoomControl);
      element.dataset.zoomControlStyle = String(options.zoomControlOptions?.style);
      element.dataset.zoomControlPosition = String(options.zoomControlOptions?.position);
      element.dataset.mapTypeControl = String(options.mapTypeControl);
      element.dataset.mapTypeControlPosition = String(options.mapTypeControlOptions?.position);
      element.classList.add('naver-map-test-stub');
    }
    setCenter(center) { this.center = center; }
    setZoom(zoom) { this.zoom = zoom; }
    getZoom() { return this.zoom; }
  }
  class ZoomControl {
    constructor(options) {
      this.options = options;
      this.element = document.createElement('div');
    }
    setMap(map) {
      map.element.dataset.zoomControl = 'true';
      map.element.dataset.zoomControlStyle = String(this.options?.style);
      map.element.dataset.zoomControlPosition = String(this.options?.position);
      map.element.append(this.element);
    }
    getElement() { return this.element; }
  }
  window.naver = {
    maps: {
      Map: NaverMap,
      ZoomControl,
      LatLng,
      MapTypeId: { NORMAL: 'normal' },
      Position: {
        TOP_RIGHT: 'top-right',
        RIGHT_TOP: 'right-top',
        RIGHT_CENTER: 'right-center',
      },
      ZoomControlStyle: { LARGE: 'large' },
      Event: {
        once(target, name, listener) {
          queueMicrotask(listener);
        },
      },
    },
  };
  setTimeout(() => window.initNaverWeatherMap(), 0);
})();`;

function contentType(file) {
  if (file.endsWith('.css')) return 'text/css; charset=utf-8';
  if (file.endsWith('.js')) return 'text/javascript; charset=utf-8';
  if (file.endsWith('.json')) return 'application/json; charset=utf-8';
  if (file.endsWith('.png')) return 'image/png';
  if (file.endsWith('.ttf')) return 'font/ttf';
  return 'text/html; charset=utf-8';
}

const routes = {
  '/': 'index.html',
  '/index.html': 'index.html',
  '/data-deletion': 'data-deletion.html',
  '/data-deletion.html': 'data-deletion.html',
  '/styles.css': 'styles.css',
  '/app-icon.png': 'app-icon.png',
  '/assets/fonts/SUITE-Regular.ttf': 'assets/fonts/SUITE-Regular.ttf',
  '/assets/fonts/SUITE-SemiBold.ttf': 'assets/fonts/SUITE-SemiBold.ttf',
  '/assets/fonts/SUITE-ExtraBold.ttf': 'assets/fonts/SUITE-ExtraBold.ttf',
  '/assets/fonts/NeoHyundai-Bold.ttf': 'assets/fonts/NeoHyundai-Bold.ttf',
  '/weather-map': 'weather-map/index.html',
  '/weather-map/': 'weather-map/index.html',
  '/weather-map/map.css': 'weather-map/map.css',
  '/weather-map/map.js': 'weather-map/map.js',
  '/weather-map/data/grid-areas.json': 'weather-map/data/grid-areas.json',
  '/weather-map/select': 'weather-map/select/index.html',
  '/weather-map/select/': 'weather-map/select/index.html',
  '/weather-map/select/select.css': 'weather-map/select/select.css',
  '/weather-map/select/select.js': 'weather-map/select/select.js',
};

const server = http.createServer((request, response) => {
  const pathname = new URL(request.url, 'http://127.0.0.1').pathname;
  const file = routes[pathname];
  const result = file || '404.html';
  response.writeHead(file ? 200 : 404, { 'Content-Type': contentType(result) });
  response.end(fs.readFileSync(path.join(root, result)));
});

async function verifyStaticPage(browser, port, target, width) {
  const page = await browser.newPage({ viewport: { width, height: 900 } });
  const response = await page.goto(`http://127.0.0.1:${port}${target.path}`);
  assert.equal(response.status(), 200);
  assert.equal(await page.locator('h1').count(), 1);
  assert.equal(await page.locator('script,iframe,form').count(), 0);
  assert.equal(await page.locator('link[rel="icon"][href="/app-icon.png"]').count(), 1);
  assert.equal(await page.locator('.brand-icon').count(), 1);
  await page.evaluate(() => document.fonts.ready);
  assert.ok((await page.locator('body').evaluate((element) =>
    getComputedStyle(element).fontFamily)).includes('SUITE'));
  assert.ok((await page.locator('h1').evaluate((element) =>
    getComputedStyle(element).fontFamily)).includes('NeoHyundai'));
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  for (const href of await page.locator('a[href^="#"]').evaluateAll((nodes) =>
    nodes.map((node) => node.getAttribute('href')))) {
    assert.equal(await page.locator(href).count(), 1);
  }
  assert.equal(await page.locator('meta[name="robots"]').count(), 0);
  const text = await page.locator('body').innerText();
  const normalizedText = text.replace(/\s+/g, ' ');
  assert.ok(!text.includes('검토용 초안') && !text.includes('미확정'));
  if (target.name === 'privacy') {
    assert.ok(text.includes('시행일 2026년 9월 14일') &&
      text.includes('데이터 삭제 요청 방법 보기') &&
      text.includes('서버 내 나의 데이터 삭제') &&
      text.includes('만 14세 이상만 이용') &&
      text.includes('Cloudflare, Inc.') &&
      text.includes('네이버클라우드㈜') &&
      text.includes('Google LLC') &&
      text.includes('처리 종료 후 1년') &&
      text.includes('날씨 판단 구역 지도'));
  } else {
    assert.ok(normalizedText.includes('날씨챙겨 데이터 삭제 요청') &&
      text.includes('코드소하') &&
      text.includes('회원 계정 없이 이용하는 앱') &&
      text.includes('데이터 삭제 요청 이메일 보내기') &&
      text.includes('설치 인증키, 비밀번호, FCM 토큰') &&
      text.includes('최대 7일') &&
      text.includes('날씨 판단 구역 지도'));
    assert.equal(await page.locator('a[href^="mailto:sy40222@gmail.com"]').count() >= 1, true);
  }
  await page.screenshot({
    path: path.join(__dirname, '.qa', `${target.name}-${width}.png`),
    fullPage: true,
  });
  await page.close();
}

async function verifyMapPage(browser, port, width) {
  const page = await browser.newPage({ viewport: { width, height: 1000 } });
  await page.route('https://oapi.map.naver.com/**', (route) => route.fulfill({
    contentType: 'text/javascript; charset=utf-8',
    body: naverMapStub,
  }));
  const response = await page.goto(`http://127.0.0.1:${port}/weather-map`);
  assert.equal(response.status(), 200);
  assert.equal(await page.title(), "'날씨챙겨' 예보 구역 지도 | 날씨챙겨");
  assert.equal(await page.locator('h1').count(), 1);
  assert.equal(await page.locator('script').count(), 2);
  assert.equal(await page.locator('iframe,form').count(), 0);
  assert.equal(await page.locator('link[rel="icon"][href="/app-icon.png"]').count(), 1);
  assert.equal(await page.locator('.brand-icon').count(), 1);
  await page.evaluate(() => document.fonts.ready);
  assert.ok((await page.locator('body').evaluate((element) =>
    getComputedStyle(element).fontFamily)).includes('SUITE'));
  assert.ok((await page.locator('h1').evaluate((element) =>
    getComputedStyle(element).fontFamily)).includes('NeoHyundai'));
  await page.waitForFunction(() =>
    document.querySelector('#grid-map')?.dataset.gridCount === '1633');
  assert.equal(await page.locator('#grid-map').getAttribute('data-ready'), 'true');
  assert.equal(await page.locator('#grid-map').getAttribute('data-grid-count'), '1633');
  assert.equal(await page.locator('#grid-map').getAttribute('data-map-type-control'), 'true');
  assert.equal(await page.locator('#grid-map').getAttribute('data-map-type-control-position'), 'right-top');
  assert.equal(await page.locator('#grid-map').getAttribute('data-zoom-control'), 'true');
  assert.equal(await page.locator('#grid-map').getAttribute('data-zoom-control-style'), 'large');
  assert.equal(await page.locator('#grid-map').getAttribute('data-zoom-control-position'), 'right-top');
  assert.equal(await page.locator('.weather-map-zoom-control').count(), 1);
  assert.equal(await page.locator('.weather-map-zoom-control').evaluate(
    (element) => getComputedStyle(element).float,
  ), 'right');
  assert.equal(await page.locator('.weather-map-zoom-control').evaluate(
    (element) => getComputedStyle(element).clear,
  ), 'both');
  assert.equal(await page.locator('.stats').count(), 0);
  assert.equal(await page.locator('#map-status').isHidden(), true);
  assert.equal(await page.locator('.coordinate-note p').count(), 2);
  assert.equal(await page.evaluate(() =>
    document.querySelector('.legend').getBoundingClientRect().top <
      document.querySelector('#grid-map').getBoundingClientRect().top), true);
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  const text = await page.locator('body').innerText();
  assert.ok(text.includes("'날씨챙겨' 예보 구역 지도") &&
    text.includes('격자 별 공유/비공유 항목') &&
    text.includes('공유 항목') &&
    text.includes('비공유 항목') &&
    text.includes('실시간 레이더 강수') &&
    text.includes('자외선지수와 대기질') &&
    text.includes('격자 색상의 의미는?') &&
    text.includes('색상이 진할수록 같은 격자를 함께 사용하는 행정지역 항목이 많다는 것을 의미합니다') &&
    text.includes('수동 지역 선택은 격자 중심 좌표를 사용합니다') &&
    text.includes('네이버 지도를 확대하면'));
  assert.equal(text.includes('네이버 지도에 보이는 행정지역과 별개로'), false);
  assert.equal(text.includes('네이버 지도 위에 예보 격자 1,633개를 표시했습니다'), false);
  if (width === 1280) {
    assert.equal(await page.locator('.intro > p:last-child').evaluate((element) =>
      getComputedStyle(element).whiteSpace), 'nowrap');
    assert.equal(await page.locator('.intro > p:last-child').evaluate((element) =>
      element.scrollWidth <= element.clientWidth), true);
    await page.locator('#region-search').fill('관악구');
    await page.locator('#search-results button').first().click();
    await page.waitForFunction(() =>
      document.querySelector('#selection-title').textContent.includes('nx'));
    assert.ok((await page.locator('#selection-regions').innerText()).includes('관악구'));
    assert.equal(new URL(page.url()).searchParams.has('grid'), true);
  }
  await page.screenshot({
    path: path.join(__dirname, '.qa', `map-${width}.png`),
    fullPage: true,
  });
  await page.close();
}

async function verifySelectorPage(browser, port, width) {
  const page = await browser.newPage({ viewport: { width, height: 820 } });
  await page.addInitScript(() => {
    window.WeatherGridSelection = {
      postMessage(message) { window.receivedGridSelection = message; },
    };
  });
  await page.route('https://oapi.map.naver.com/**', (route) => route.fulfill({
    contentType: 'text/javascript; charset=utf-8',
    body: naverMapStub,
  }));
  const response = await page.goto(
    `http://127.0.0.1:${port}/weather-map/select?grid=28_8`,
  );
  assert.equal(response.status(), 200);
  assert.equal(await page.title(), '예보 구역 선택 | 날씨챙겨');
  assert.equal(await page.locator('meta[name="robots"][content="noindex,nofollow"]').count(), 1);
  assert.equal(await page.locator('.site-header, footer, .meaning').count(), 0);
  assert.equal(await page.locator('.legend-scale i').count(), 4);
  await page.waitForFunction(() =>
    document.querySelector('#grid-map')?.dataset.gridCount === '1633');
  assert.equal(await page.locator('#map-status').isHidden(), true);
  assert.equal(await page.locator('#grid-map').getAttribute('data-zoom-control'), 'true');
  assert.equal(await page.locator('#grid-map').getAttribute('data-zoom-control-style'), 'large');
  assert.equal(await page.locator('#grid-map').getAttribute('data-zoom-control-position'), 'right-center');
  assert.equal(await page.locator('#confirm-grid').isEnabled(), false);
  assert.equal(await page.locator('input[name="display-region"]').count(), 1);
  const text = await page.locator('body').innerText();
  assert.ok(text.includes('1개') &&
    text.includes('2–4개') &&
    text.includes('5–9개') &&
    text.includes('10개 이상') &&
    text.includes('날씨 위험도를 뜻하지 않습니다') &&
    text.includes('nx 28 · ny 8') &&
    text.includes('1개 표시명') &&
    text.includes('Main에 표시할 지역명을 골라주세요') &&
    text.includes('선택한 지역명으로 사용'));
  const regionChoice = page.locator('input[name="display-region"]').first();
  const regionKey = await regionChoice.getAttribute('value');
  await regionChoice.check();
  assert.equal(await page.locator('#confirm-grid').isEnabled(), true);
  assert.equal(new URL(page.url()).searchParams.get('region'), regionKey);
  await page.reload();
  await page.waitForFunction(() =>
    document.querySelector('#grid-map')?.dataset.gridCount === '1633');
  assert.equal(await page.locator('input[name="display-region"]').first().isChecked(), true);
  assert.equal(await page.locator('#confirm-grid').isEnabled(), true);
  await page.locator('#confirm-grid').click();
  await page.waitForFunction(() => window.receivedGridSelection);
  assert.deepEqual(
    JSON.parse(await page.evaluate(() => window.receivedGridSelection)),
    {
      type: 'weather-grid-selection',
      gridId: '28_8',
      nx: 28,
      ny: 8,
      regionKey,
    },
  );
  await page.locator('#region-search').fill('구로1동');
  const normalizedRegion = page.locator('#search-results button').first();
  await normalizedRegion.waitFor();
  assert.ok((await normalizedRegion.innerText()).includes('서울특별시 구로구 구로1동'));
  assert.equal((await normalizedRegion.innerText()).includes('구로제1동'), false);
  await normalizedRegion.click();
  assert.equal(await page.locator('#region-search').inputValue(), '서울특별시 구로구 구로1동');
  const selectedNames = await page.locator('#selection-regions').innerText();
  assert.ok(selectedNames.includes('서울특별시 구로구 구로1동'));
  assert.equal(selectedNames.includes('구로제1동'), false);
  assert.equal(
    await page.locator('input[value="1153052000|구로제1동|58|125"]').isChecked(),
    true,
  );
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  assert.equal(await page.locator('#grid-map').evaluate((element) =>
    element.getBoundingClientRect().height >= 260), true);
  await page.screenshot({
    path: path.join(__dirname, '.qa', `map-selector-${width}.png`),
    fullPage: true,
  });
  await page.close();
}

(async () => {
  const gridData = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
  assert.equal(gridData.meta.regionCount, 3838);
  assert.equal(gridData.meta.gridCount, 1633);
  assert.equal(gridData.meta.sharedGridCount, 475);
  assert.equal(gridData.meta.maxRegionCount, 38);
  assert.equal(gridData.grids.length, gridData.meta.gridCount);
  assert.ok(gridData.grids.every((grid) =>
    grid.polygon.length === 5 && grid.regions.length === grid.count));

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({ channel: 'chrome', headless: true });
    fs.mkdirSync(path.join(__dirname, '.qa'), { recursive: true });
    const port = server.address().port;
    for (const target of [
      { path: '/', name: 'privacy' },
      { path: '/data-deletion', name: 'deletion' },
    ]) {
      for (const width of [360, 1280]) {
        await verifyStaticPage(browser, port, target, width);
      }
    }
    for (const width of [360, 1280]) {
      await verifyMapPage(browser, port, width);
    }
    for (const width of [360, 800]) {
      await verifySelectorPage(browser, port, width);
    }
    console.log('PASS: 개인정보·삭제 안내·공개 지도·앱용 지도 선택, 모바일/데스크톱 레이아웃과 1,633개 격자');
  } finally {
    if (browser) await browser.close();
    server.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
