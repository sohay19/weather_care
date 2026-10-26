import type { WeatherForecast } from '../providers/weather/weatherProvider';
import { snapshotTime } from '../rules/timeWindows';
import { LifestyleInsightType, type PipeFreezeAssessment, type TodayWeatherResponse } from '../types';
import { formatWeatherNumber } from '../utils/weatherNumber';

const HOUR = 3_600_000;
const MAX_ISSUE_AGE = 8 * HOUR;
const SEOUL_GUIDE = 'https://news.seoul.go.kr/env/archives/565606?listPage=1';
const levels = { CHECK: '보온 점검', CAUTION: '주의', WARNING: '경계', DANGER: '심각' };

/** 서울시의 최저기온·이틀 기준을 참고한 앱 판단이다. 공식 동파 예보가 아니다. */
export function assessPipeFreeze(forecast: WeatherForecast, now: Date): PipeFreezeAssessment {
  const start = Math.floor(now.getTime() / HOUR) * HOUR;
  const end = start + 48 * HOUR;
  const baseIssue = /^\d{8}$/.test(forecast.baseDate) && /^\d{4}$/.test(forecast.baseTime)
    ? `${forecast.baseDate.slice(0, 4)}-${forecast.baseDate.slice(4, 6)}-${forecast.baseDate.slice(6)}T${forecast.baseTime.slice(0, 2)}:${forecast.baseTime.slice(2)}:00+09:00` : '';
  const slots = new Map<number, { temperature: number; issued: number }>();
  // 포털이 정각 30분 뒤 현재 시각을 hourly에서 제외해도 당일 타임라인의 실제 예보를 쓴다.
  for (const item of [...(forecast.timelineHourly ?? []), ...forecast.hourly]) {
    const time = Date.parse(snapshotTime(item));
    const issued = Date.parse(item.issuedAt ?? baseIssue);
    const age = now.getTime() - issued;
    if (item.dataRole === 'OBSERVATION' || !Number.isFinite(time) || time % HOUR !== 0 ||
        time < start || time >= end || !Number.isFinite(age) || age < 0 || age >= MAX_ISSUE_AGE ||
        typeof item.temperature !== 'number' || !Number.isFinite(item.temperature) ||
        item.temperature < -90 || item.temperature > 60) continue;
    if (issued >= (slots.get(time)?.issued ?? -Infinity)) {
      slots.set(time, { temperature: item.temperature, issued });
    }
  }
  const ordered = [...slots.entries()].sort((a, b) => a[0] - b[0]);
  const minimum = ordered.reduce<typeof ordered[number] | undefined>((best, row) =>
    !best || row[1].temperature < best[1].temperature ? row : best, undefined);
  const longestRun = (threshold: number) => {
    let longest = 0, run = 0;
    for (let hour = 0; hour < 48; hour++) {
      const temperature = slots.get(start + hour * HOUR)?.temperature;
      run = temperature !== undefined && temperature < threshold ? run + 1 : 0;
      longest = Math.max(longest, run);
    }
    return longest;
  };
  const complete = slots.size === 48;
  const minima = [0, 24].map((offset) => Math.min(...Array.from({ length: 24 }, (_, hour) =>
    slots.get(start + (offset + hour) * HOUR)?.temperature ?? Infinity)));
  const level = !complete ? undefined : minima.every((value) => value < -15) ? 'DANGER'
    : minima.every((value) => value < -10) ? 'WARNING'
    : minimum![1].temperature < -5 ? 'CAUTION' : 'CHECK';
  const issued = ordered.length ? Math.min(...ordered.map(([, row]) => row.issued)) : undefined;
  return { status: complete ? 'AVAILABLE' : ordered.length ? 'PARTIAL' : 'UNAVAILABLE',
    level, levelLabel: level ? levels[level] : '판단 자료 부족',
    periodStart: new Date(start).toISOString(), periodEnd: new Date(end).toISOString(),
    availableHours: slots.size, expectedHours: 48,
    minimumTemperature: minimum?.[1].temperature,
    minimumAt: minimum ? new Date(minimum[0]).toISOString() : undefined,
    forecastIssuedAt: issued === undefined ? undefined : new Date(issued).toISOString(),
    freezingHours: longestRun(0), belowMinus10Hours: longestRun(-10), belowMinus15Hours: longestRun(-15),
    validUntil: new Date(Math.min(start + HOUR, issued === undefined ? Infinity : issued + MAX_ISSUE_AGE)).toISOString(),
    ruleVersion: 'pipe-freeze-1', referenceUrl: SEOUL_GUIDE };
}

export function pipeFreezeMessage(assessment: PipeFreezeAssessment, regionName: string,
  now: Date): TodayWeatherResponse['lifestyleMessages'][number] {
  const complete = assessment.status === 'AVAILABLE';
  const intense = assessment.level === 'WARNING' || assessment.level === 'DANGER';
  const title = complete ? `수도관 동파 대비 · ${assessment.levelLabel}` : '수도관 동파 대비 · 판단 자료 부족';
  const action = intense
    ? '계량기함 보온재와 틈새·노출 수도관을 점검하세요. 장시간 집을 비운다면 보온 상태를 한 번 더 확인하세요.'
    : '계량기함의 젖거나 부족한 보온재와 틈새, 바깥에 노출된 수도관을 점검해 두세요.';
  const clock = (time: string) => new Date(Date.parse(time) + 9 * HOUR).toISOString().slice(5, 16).replace('T', ' ');
  const summary = `앱 참고 단계: ${assessment.levelLabel} · ${regionName} · ${clock(assessment.periodStart)}~${clock(assessment.periodEnd)} KST · 유효 기온 예보 ${assessment.availableHours}/48시간`;
  const parts: TodayWeatherResponse['lifestyleMessages'][number]['parts'] = [
    { role: 'APP_SUGGESTION', text: action, source: '날씨챙겨 동파 대비 참고 안내', validUntil: assessment.validUntil },
    { role: 'CALCULATED_FACT', text: summary, source: '날씨챙겨', validUntil: assessment.validUntil },
  ];
  if (assessment.minimumTemperature !== undefined) {
    parts.push({ role: 'OFFICIAL_FACT', text: `${clock(assessment.minimumAt!)} 기온 예보 ${formatWeatherNumber(assessment.minimumTemperature)}℃ · ${clock(assessment.forecastIssuedAt!)} 이후 발표 자료`,
      source: '기상청 단기예보', validUntil: assessment.validUntil });
    parts.push({ role: 'CALCULATED_FACT', text: `${complete ? '48시간 중' : '확보한 예보 중'} 최저 ${formatWeatherNumber(assessment.minimumTemperature)}℃ · 영하 최장 ${assessment.freezingHours}시간 · -10℃ 미만 최장 ${assessment.belowMinus10Hours}시간 · -15℃ 미만 최장 ${assessment.belowMinus15Hours}시간. 결측 시각은 이어 세지 않아요.`,
      source: '날씨챙겨 기온 예보 집계', validUntil: assessment.validUntil });
  }
  if (!complete) parts.push({ role: 'DATA_STATUS', text: '48시간 기온 예보가 없거나 일부가 오래돼 단계를 판단하지 않아요. 자료 부족을 낮은 위험으로 해석하지 마세요.',
    source: '기상청 단기예보', validUntil: assessment.validUntil });
  parts.push({ role: 'CALCULATED_FACT', text: '서울시 최저기온·이틀 지속 기준을 참고한 앱 안내예요. 48시간을 앞·뒤 24시간으로 나누어, 양쪽 최저가 -15℃ 미만이면 심각, -10℃ 미만이면 경계, 전체 최저가 -5℃ 미만이면 주의로 표시해요. 그 외는 보온 점검이에요. 공식 동파 예보·발생 확률이 아니며 체감온도는 사용하지 않아요. 보온·노출 상태에 따라 실제 위험은 달라지고 도로 결빙과는 별개예요.',
    source: '날씨챙겨 참고 기준 · 서울시 동파 예방 안내', validUntil: assessment.validUntil });
  return { type: LifestyleInsightType.PIPE_FREEZE_GUIDANCE, title, description: action,
    priority: intense ? 80 : assessment.level === 'CAUTION' ? 65 : 25,
    parts: parts.map((part) => ({ ...part, validFrom: now.toISOString() })) };
}
