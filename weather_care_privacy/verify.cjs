const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { chromium } = require('playwright');
const root = path.join(__dirname, 'public');
const server = http.createServer((req, res) => {
  const file = ({ '/': 'index.html', '/styles.css': 'styles.css' })[req.url];
  res.writeHead(file ? 200 : 404, { 'Content-Type': file === 'styles.css' ? 'text/css; charset=utf-8' : 'text/html; charset=utf-8' });
  res.end(fs.readFileSync(path.join(root, file || '404.html')));
});
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({ channel: 'chrome', headless: true });
    fs.mkdirSync(path.join(__dirname, '.qa'), { recursive: true });
    for (const width of [360, 1280]) {
      const page = await browser.newPage({ viewport: { width, height: 900 } });
      await page.goto(`http://127.0.0.1:${server.address().port}/`);
      assert.equal(await page.locator('h1').count(), 1);
      assert.equal(await page.locator('script,iframe,form').count(), 0);
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
      for (const href of await page.locator('a[href^="#"]').evaluateAll(nodes => nodes.map(n => n.getAttribute('href')))) {
        assert.equal(await page.locator(href).count(), 1);
      }
      assert.ok(await page.locator('body').innerText().then(t => t.includes('검토용 초안') && t.includes('서버 내 나의 데이터 삭제') && t.includes('만 14세 이상만 이용')));
      await page.screenshot({ path: path.join(__dirname, '.qa', `${width}.png`), fullPage: true });
      await page.close();
    }
    console.log('PASS: mobile/desktop layout, anchors, draft status, no scripts/forms');
  } finally {
    if (browser) await browser.close();
    server.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
