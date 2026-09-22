# 날씨챙겨 공개 페이지

Cloudflare Pages 정적 사이트다. 하나의 `weather-care` 프로젝트에서 다음 주소를 제공한다.

- `https://weather-care.pages.dev/`: 개인정보처리방침
- `https://weather-care.pages.dev/data-deletion`: 데이터 삭제 요청 안내
- `https://weather-care.pages.dev/weather-map`: 날씨 판단 구역 지도
- `https://weather-care.pages.dev/weather-map/select`: 앱 WebView용 예보 구역 선택 지도

배포 대상은 `public`이며 Pages Functions와 서버 바인딩은 사용하지 않는다. `/weather-map`만 네이버 Web Dynamic Map 스크립트와 지도 타일을 사용하고, 나머지 페이지는 외부 스크립트를 불러오지 않는다. 기존 날씨 API Worker와도 분리되어 있다.

## 지도 데이터

`build-grid-data.cjs`는 앱의 `assets/data/kma_regions.json`을 읽어 동일한 기상청 단기예보 `nx·ny`를 사용하는 지역을 묶고, 약 5km 격자 폴리곤을 생성한다. 생성 결과는 `public/weather-map/data/grid-areas.json`이며 배포 전에 반드시 다시 만든다.

지도에서는 웹페이지와 앱의 수동 지역 선택이 같은 `nx·ny`에서 공유하는 현재 날씨·초단기예보·단기예보와, 행정지역·관측소·GPS·사용자 설정에 따라 달라질 수 있는 나머지 항목을 구분해 설명한다. 네이버 지도는 행정지역명·도로·지형을 보여주고, 반투명 격자 도형은 이 세 가지 격자 자료의 판단 단위다. Web Dynamic Map의 브라우저용 Client ID는 공개 값이며 Client Secret은 소스에 넣지 않는다. 네이버 클라우드의 Web 서비스 URL에는 `weather-care.pages.dev`가 등록되어 있어야 한다.

`/weather-map/select`는 공개 설명 페이지를 포함하지 않고 지도·검색·색상 범례·선택 패널만 표시한다. 앱은 `WeatherGridSelection` JavaScript 채널로 받은 `gridId`, `nx`, `ny`를 로컬 지역 카탈로그와 다시 대조한 뒤에만 저장한다. 이 경로는 검색엔진에 노출하지 않는다.

## 검증과 배포

서버 프로젝트에 설치된 Wrangler를 사용한다. 이 폴더에서 실행한다.

```powershell
npm run verify
node ../weather_care_server/node_modules/wrangler/bin/wrangler.js pages dev public
node ../weather_care_server/node_modules/wrangler/bin/wrangler.js pages deploy public --project-name weather-care --branch master
```

`npm run verify`는 지도 데이터를 생성한 뒤 개인정보처리방침·삭제 안내·지도를 모바일과 데스크톱 크기에서 검사하고 `.qa`에 스크린샷을 만든다. `.qa`는 배포하지 않는다.

개인정보처리방침을 변경할 때는 본문, 개정 이력과 시행일을 함께 수정한다. 현재 공고일·시행일은 2026-09-14이다. 운영 광고는 비활성 상태이며 활성화 전에 실제 처리와 동의 흐름을 검증해 방침을 개정한다.
