# 날씨챙겨 개인정보 페이지

Cloudflare Pages 정적 사이트. 배포 대상은 `public`만이며 서버 바인딩/Functions/외부 스크립트가 없다. 기존 API Worker와 분리한다.

현재 **운영 개인정보처리방침**이다. 공고일·시행일은 2026-09-14이며 검색엔진 차단 표시는 제거했다. 정식 주소는 `https://weather-care-privacy.pages.dev/`이다.

서버 프로젝트에 설치된 Wrangler를 사용한다(이 폴더 기준):

```powershell
node ../weather_care_server/node_modules/wrangler/bin/wrangler.js pages dev public --cwd D:/IdeaProjects/weather_care/weather_care_privacy
node ../weather_care_server/node_modules/wrangler/bin/wrangler.js pages deploy public --cwd D:/IdeaProjects/weather_care/weather_care_privacy --project-name weather-care-privacy --branch master
```

변경 시 본문과 개정 이력·시행일을 함께 수정하고 검증한 뒤 production branch `master`에 배포한다. 기존 preview 배포도 별도 공개 사본이므로 개인정보나 비밀값을 넣지 않는다.

확인: 반응형 레이아웃, 목차 이동, 문의 mailto, 외부 링크, HTTP 200/CSP/404, 스크립트 없는 출력. 이용 대상은 만 14세 이상이고 문의 기록은 처리 종료 후 1년, 운영 변경용 수동 DB 백업은 최대 7일로 확정했다. 운영 광고는 비활성 상태이며 활성화 전에 실제 처리와 동의 흐름을 검증해 방침을 개정한다.

`npm install` 후 `npm run verify`를 실행하면 Playwright와 설치된 Chrome으로 정적 페이지를 검증한다. `.qa` 스크린샷은 배포하지 않는다. Wrangler 실행 시 기존 서버 설정을 잘못 읽지 않도록 이 프로젝트의 절대 `--cwd`를 명시한다.
