// 서버 폴더에서: node --import ./node_modules/tsx/dist/loader.mjs ../docs/전국_API_예산_계산_20261004.mjs
// 실제 운영 수집 계획을 10분마다 실행해 중복 원본을 제거한다. GB=10억 바이트.
import { nationwideForecastPlan } from '../weather_care_server/src/providers/weather/kmaNationwideForecastProvider.ts';

const gridBytes = 341297;
const day = 86400000;
const step = 600000;
const sum = rows => rows.reduce((a, b) => ({ calls: a.calls + b.calls, bytes: a.bytes + b.bytes }), { calls: 0, bytes: 0 });
const key = r => `${r.issue}:${r.valid}:${r.variable}`;
function forecastUsage(date) {
  const base = Date.parse(date + 'T00:00:00+09:00');
  const seen = new Set();
  const daily = [];
  let steady = 0;
  for (let time = base - 2 * day; time < base + day; time += step) {
    const plan = nationwideForecastPlan(new Date(time));
    if (time >= base) daily.push(plan.map(key));
    for (const request of plan) {
      const id = key(request);
      if (!seen.has(id) && time >= base) steady++;
      seen.add(id);
    }
  }
  // 하루 중 어느 시각에 빈 DB로 시작하더라도 그 KST 일자에 필요한 최대 원본 수.
  let coldMax = 0;
  for (let start = 0; start < daily.length; start++) {
    const cold = new Set(daily.slice(start).flat());
    coldMax = Math.max(coldMax, cold.size);
  }
  return { steady, coldMax };
}
const common = [
  { name: '10분 실황 6변수×144회차', calls: 864, bytes: 864 * gridBytes },
  { name: '특보 30분·구역 목록 하루 1회', calls: 49, bytes: 48 * 256000 + 1000000 },
  { name: 'ASOS 시정 전용 1파일×24회', calls: 24, bytes: 24 * 128000 },
  { name: 'AWS 독립 일 관측 4지표 (실황 대체 아님)', calls: 4, bytes: 4 * 512000 },
  { name: '중기예보 전국 176기온·10육상×하루2회', calls: 372, bytes: 372 * 8192 },
  { name: '전국 강수분석·레이더 2파일×30분', calls: 96, bytes: 48 * 30075022 },
];
const winterRoad = { name: '겨울 도로살얼음 12파일×30분', calls: 576, bytes: 576 * 2100000 };
const history = { calls: 432, bytes: 432 * gridBytes };
const profiles = [false, true].map(winter => {
  const forecast = forecastUsage(winter ? '2026-12-04' : '2026-10-04');
  const sources = [...common, ...(winter ? [winterRoad] : []),
    { name: winter ? '전국 단기예보: 가까운24h 3시간·먼기간 하루1회' : '전국 단기예보: 가까운24h 3시간·먼기간 하루2회', calls: forecast.steady, bytes: forecast.steady * gridBytes }];
  const essential = sum(sources);
  // 10%는 계획 가정이며 실측 실패율이 아니다. 모든 작업의 재시도는 400MB를 공유한다.
  const retries = { calls: Math.ceil(essential.calls * 0.1), bytes: Math.ceil(essential.bytes * 0.1) };
  const coldExtra = { calls: forecast.coldMax - forecast.steady + history.calls + 188,
    bytes: (forecast.coldMax - forecast.steady) * gridBytes + history.bytes + 6 * 512000 * 4 + 186 * 8192 + 30075022 };
  const initial = sum([essential, coldExtra]);
  return { season: winter ? '겨울(11월15일~3월15일)' : '비겨울', forecast, sources, essential, retries,
    total: sum([essential, retries]), bootstrapExtra: coldExtra, bootstrapEssential: initial,
    bootstrapWithRetryByteCap: initial.bytes + 100000000,
    note: '초기 추가에는 이전 발표 예보·어제 동시각 432파일·과거 일 관측 7일 범위·이전 중기186파일·초기 강수분석/레이더2파일을 포함. 첫 24시간 재시도 100MB, 이후 400MB. 성공 응답 실수신량 정산, 실패·중단은 예약 상한 유지.' };
});
console.log(JSON.stringify({ limits: { officialDailyCalls: 20000, officialDailyBytes: 5000000000,
  internalDailyCalls: 18000, internalDailyBytes: 4500000000, retryDailyBytes: 400000000, bootstrapRetryDailyBytes: 100000000 },
  gridBytes, profiles,
  otherProviders: {
    airKorea: { essential: 425, retries: 86, total: 511, limit: '운영계정 신청 전제로 문제없음', retryAssumption: '20% (실측 아님)' },
    its: { essential: 144, retries: 29, total: 173, limit: '사용자 전제로 문제없음', retryAssumption: '20% (실측 아님)' },
    kmaPortalUv: { essential: 32, retries: 7, total: 39, note: '3,851지역/1,000행=4페이지×8회차. APIHub 합계에 포함하지 않음. 운영계정 전제.' },
  }, excluded: { awsMinuteFallback: 0, separateReadinessRequest: 0, requestTriggeredWeatherFetch: 0, representativePointPrecipitationFallback: 0 },
  assumptions: ['파일 341,297B는 2026-10-04 실측, 모든 발표의 최대 용량을 증명하지 않음.',
    '그 외 크기는 보수적인 기존 설계 표본. 실제 용량 증가와 타임아웃 미정산은 내부 상한으로 차단됨.',
    '동일 키의 수동 호출·다른 프로그램 호출은 실제 계정 한도에 포함되나 서버 내부 장부에는 자동 반영되지 않음.',
    '전국 격자를 제거해 절약하지 않고 먼 기간의 갱신 주기와 큰 전국 원본의 주기를 조절함.'] }, null, 2));
