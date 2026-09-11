# 날씨챙겨 개인정보 페이지

Cloudflare Pages 정적 사이트. 배포 대상은 `public`만이며 서버 바인딩/Functions/외부 스크립트가 없다. 기존 API Worker와 분리한다.

현재 **검토용 초안**이다. 미확정 조건은 페이지에 명시하고 noindex를 적용한다. AdMob·앱스토어 최종 방침으로 등록하지 않는다. noindex는 접근 제어가 아니며 공개 페이지다.

서버 프로젝트에 설치된 Wrangler를 사용한다(이 폴더 기준):

```powershell
node ../weather_care_server/node_modules/wrangler/bin/wrangler.js pages dev public --cwd D:/IdeaProjects/weather_care/weather_care_privacy
node ../weather_care_server/node_modules/wrangler/bin/wrangler.js pages deploy public --cwd D:/IdeaProjects/weather_care/weather_care_privacy --project-name weather-care-privacy --branch review
```

검토 완료 후에만 시행일/최종 내용 확정, 초안 표시와 noindex 제거, production branch `master` 배포 및 앱·AdMob 연결을 수행한다. 기존 preview 배포도 별도 공개 사본이므로 개인정보나 비밀값을 넣지 않는다.

확인: 반응형 레이아웃, 목차 이동, 문의 mailto, 외부 링크, HTTP 200/CSP/404, 스크립트 없는 출력. 외부 계약·국외 이전 정보·책임자·대상 연령·문의 보관기간의 최종 확인은 기술 배포와 별개다.

`verify.cjs`는 Playwright와 설치된 Chrome을 사용해 정적 페이지를 로컬 검증한다. Playwright가 있는 환경에서 `node verify.cjs` 실행. `.qa` 스크린샷은 배포하지 않는다. Wrangler 실행 시 기존 서버 설정을 잘못 읽지 않도록 이 프로젝트의 절대 `--cwd`를 명시한다.
