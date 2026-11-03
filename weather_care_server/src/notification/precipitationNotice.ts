import type { WeatherSnapshot } from '../types';
import { WeatherRuleFactType } from '../types';
import { defaultRuleConfig } from '../config/ruleConfig';
import { otherDatePrefix, precipitationDecisionSnapshot, precipitationEnd, precipitationPeriod, precipitationStart, periodLabel } from '../rules/precipitationWindows';
import { sortSnapshots } from '../rules/timeWindows';
import { runWeatherRuleEngineForHourly } from '../rules/weatherRuleEngine';
import { formatWeatherNumber } from '../utils/weatherNumber';

export type PrecipitationTopic = 'rain' | 'snow';

function endExclusive(item: WeatherSnapshot): number {
  const period = precipitationPeriod(item);
  if (period) return Date.parse(period.end);
  const start = Date.parse(precipitationStart(item));
  const end = Date.parse(precipitationEnd(item));
  return end > start ? end + 1 : start + 3_600_000;
}

export function precipitationNotice(
  hourly: WeatherSnapshot[],
  topic: PrecipitationTopic,
  now: Date,
  midnight: number,
  warning = false,
) {
  const snow = topic === 'snow';
  const runs: WeatherSnapshot[][] = [];
  for (const raw of sortSnapshots(hourly)) {
    const item = precipitationDecisionSnapshot(raw, now);
    if (item.dataRole === 'OBSERVATION' || item.precipitationPeriod === null ||
        endExclusive(item) <= now.getTime() ||
        Date.parse(precipitationStart(item)) >= midnight) continue;
    const hasSnow = item.precipitationType === 'SNOW' || item.precipitationType === 'RAIN_SNOW';
    const matches = snow
      ? hasSnow || item.snowExpected || (item.snowfallAmountRange?.min ?? item.snowfallAmount ?? 0) > 0
      : item.precipitationType !== 'SNOW' && (
        item.precipitationType === 'RAIN' || item.precipitationType === 'RAIN_SNOW' ||
        item.precipitationType === 'SHOWER' ||
        (item.precipitationProbability ?? 0) >= defaultRuleConfig.rain.minProbability ||
        (item.precipitationAmountRange?.min ?? item.precipitationAmount ?? 0) >= defaultRuleConfig.rain.minAmount);
    if (!matches) continue;
    const run = runs.at(-1);
    const last = run?.at(-1);
    if (run && last && Date.parse(precipitationStart(item)) === endExclusive(last)) {
      run.push(item);
    } else if (!last || precipitationStart(last) !== precipitationStart(item)) {
      runs.push([item]);
    }
  }
  const severeType = snow ? WeatherRuleFactType.HEAVY_SNOW : WeatherRuleFactType.HEAVY_RAIN;
  const severeRun = runs.find((run) =>
    runWeatherRuleEngineForHourly(run, undefined, now).some((fact) => fact.type === severeType));
  const severe = warning || severeRun !== undefined;
  const run = severeRun ?? runs[0];
  if (!run && !warning) return undefined;
  const probability = Math.max(-1, ...(run ?? []).flatMap((item) =>
    typeof item.precipitationProbability === 'number' && Number.isFinite(item.precipitationProbability)
      ? [item.precipitationProbability] : []));
  // 눈 예보 시간의 POP를 사용한다. PTY 기반 snowProbability는 합성 지표다.
  const values = probability < 0 ? [] : [
    `${snow ? '강설' : '강수'}확률${run!.length > 1 ? ' 최고' : ''} ${formatWeatherNumber(probability)}%`,
  ];
  if (severe && run) {
    const amounts = run.map((item) => {
      const range = snow ? item.snowfallAmountRange : item.precipitationAmountRange;
      const scale = (range?.unit ?? (snow ? 'CM' : 'MM')) === 'CM' ? 10 : 1;
      const value = snow ? item.snowfallAmount : item.precipitationAmount;
      if (!range) return value === undefined ? undefined : { min: value * scale, max: value * scale };
      const min = range.min ?? (range.type === 'LESS_THAN' || range.type === 'NONE' ? 0 : undefined);
      const max = range.max ?? (range.type === 'NONE' || range.type === 'VALUE' ? min : undefined);
      return min === undefined ? undefined : { min: min * scale, max: max === undefined ? Infinity : max * scale };
    });
    if (amounts.every((amount) => amount !== undefined && Number.isFinite(amount.min))) {
      const min = amounts.reduce((total, amount) => total + amount!.min, 0);
      const max = amounts.reduce((total, amount) => total + amount!.max, 0);
      values.push(!Number.isFinite(max) ? `≥${formatWeatherNumber(min)}mm`
        : min === max ? `${formatWeatherNumber(min)}mm`
          : `${formatWeatherNumber(min)}~${formatWeatherNumber(max)}mm`);
    }
  }
  const time = run ? otherDatePrefix(precipitationStart(run[0]), now.toISOString()) + periodLabel(precipitationStart(run[0]), new Date(Math.min(midnight,
    endExclusive(run.at(-1)!))).toISOString()) : '';
  const message = snow
    ? severe ? '많은 눈이 예상되니 차량 이동에 여유를 두세요.' : '눈 소식이 있으니 미끄럼에 주의하세요.'
    : severe ? '강한 비가 예상되니 하천변과 지하차도는 피하세요.' : '비 소식이 있으니 우산을 챙기세요.';
  const warningMessage = snow
    ? '대설 특보가 발효 중이에요. 차량 이동에 여유를 두세요.'
    : '호우 특보가 발효 중이에요. 하천변과 지하차도는 피하세요.';
  const details = values.length ? `(${values.join(', ')})` : '';
  return {
    priority: severe ? 0 : 1,
    forecastDetails: details ? `${time} 예보 ${details}` : '',
    body: warning
      ? warningMessage + (details ? ` ${time} 예보 ${details}` : '')
      : `${time}에 ${message}${details ? ` ${details}` : ''}`,
  };
}
