// 공식 Rectangular 프리뷰 규격의 안전 여백을 포함한 선택기 자산을 생성한다.
const {chromium} = require('C:/Users/idp20/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const path = require('path');
const fs = require('fs');
(async()=>{
  const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
  try {
    const page=await browser.newPage();
    await page.goto('file:///'+path.resolve(__dirname,'../../docs/design/watch-20261102/index.html').replaceAll('\\','/'));
    await page.evaluate(()=>document.fonts.ready);
    const styles=await page.locator('style').textContent();
    const isolated=await browser.newPage();
    for(const kind of ['small','large']) {
      const svg=page.locator(`#spec-board svg[data-profile="rectangular-${kind}-1"]`);
      const html=await svg.evaluate(el=>el.outerHTML);
      const dimensions=await svg.evaluate(el=>[el.viewBox.baseVal.width*2,el.viewBox.baseVal.height*2]);
      await isolated.setViewportSize({width:dimensions[0],height:dimensions[1]});
      await isolated.setContent(`<html lang="ko"><head><meta charset="utf-8"><style>${styles}</style></head><body style="margin:0;background:black">${html}</body></html>`);
      await isolated.evaluate(()=>document.fonts.ready);
      await isolated.locator('svg').evaluate((el,d)=>{el.style.width=d[0]+'px';el.style.height=d[1]+'px'},dimensions);
      await isolated.locator('svg').screenshot({path:path.resolve(__dirname,`../app/src/main/res/drawable-nodpi/widget_preview_${kind}.png`)});
      console.log(JSON.stringify({종류:kind,크기:dimensions,성격:'선택기용 합성 시안, 실제 날씨 아님'}));
    }
  } finally {await browser.close()}
})().catch(error=>{console.error(error);process.exit(1)});
