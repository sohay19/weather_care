const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { chromium } = require('playwright');
const root = path.join(__dirname, 'public');
const server = http.createServer((req, res) => {
  const file = ({
    '/': 'index.html',
    '/data-deletion': 'data-deletion.html',
    '/data-deletion.html': 'data-deletion.html',
    '/styles.css': 'styles.css',
  })[req.url];
  res.writeHead(file ? 200 : 404, { 'Content-Type': file === 'styles.css' ? 'text/css; charset=utf-8' : 'text/html; charset=utf-8' });
  res.end(fs.readFileSync(path.join(root, file || '404.html')));
});
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({ channel: 'chrome', headless: true });
    fs.mkdirSync(path.join(__dirname, '.qa'), { recursive: true });
    for (const target of [
      { path: '/', name: 'privacy' },
      { path: '/data-deletion', name: 'deletion' },
    ]) {
      for (const width of [360, 1280]) {
        const page = await browser.newPage({ viewport: { width, height: 900 } });
        const response = await page.goto(`http://127.0.0.1:${server.address().port}${target.path}`);
        assert.equal(response.status(), 200);
        assert.equal(await page.locator('h1').count(), 1);
        assert.equal(await page.locator('script,iframe,form').count(), 0);
        assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
        for (const href of await page.locator('a[href^="#"]').evaluateAll(nodes => nodes.map(n => n.getAttribute('href')))) {
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
            text.includes('Google LLC') &&
            text.includes('처리 종료 후 1년'));
        } else {
          assert.ok(normalizedText.includes('날씨챙겨 데이터 삭제 요청') &&
            text.includes('코드소하') &&
            text.includes('회원 계정 없이 이용하는 앱') &&
            text.includes('데이터 삭제 요청 이메일 보내기') &&
            text.includes('설치 인증키, 비밀번호, FCM 토큰') &&
            text.includes('최대 7일'));
          assert.equal(await page.locator('a[href^="mailto:sy40222@gmail.com"]').count() >= 1, true);
        }
        await page.screenshot({ path: path.join(__dirname, '.qa', `${target.name}-${width}.png`), fullPage: true });
        await page.close();
      }
    }
    console.log('PASS: privacy and deletion pages, mobile/desktop layout, links, final content, no scripts/forms');
  } finally {
    if (browser) await browser.close();
    server.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
