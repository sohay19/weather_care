import type { WeatherForecast } from '../providers/weather/weatherProvider';
import { snapshotTime } from '../rules/timeWindows';
import { defaultRuleConfig } from '../config/ruleConfig';
import { LifestyleInsightType, type TodayLivingIndices, type TodayWeatherResponse,
  type WeatherMessagePart, type WeatherSnapshot } from '../types';

const kstDate = (date: Date) => new Date(date.getTime() + 9 * 3_600_000).toISOString().slice(0, 10);
const high = (level: string) => level === '높음' || level === '매우 높음';

/** 일별 꽃가루 예측을 그 날짜의 판단에만 연결한다. 새 API 호출은 하지 않는다. */
export function withLivingIndexAdvice(forecast: WeatherForecast, indices: TodayLivingIndices,
  now: Date): WeatherForecast {
  const date = kstDate(now);
  const risks = indices.pollenStatus === 'AVAILABLE' ? indices.pollen.filter((risk) => {
    const age = now.getTime() - Date.parse(risk.issuedAt);
    return Number.isFinite(age) && age >= 0 && age <= 24 * 3_600_000;
  }) : [];
  const add = (snapshot: WeatherSnapshot): WeatherSnapshot => {
    const { pollenForecast: _previous, ...clean } = snapshot;
    const time = new Date(snapshotTime(snapshot));
    if (!risks.length || !Number.isFinite(time.getTime()) || kstDate(time) !== date) return clean;
    return { ...clean, pollenForecast: { date, risks } };
  };
  return { ...forecast, current: add(forecast.current), hourly: forecast.hourly.map(add) };
}

export function pollenEvidence(snapshot: WeatherSnapshot): WeatherMessagePart[] {
  const forecast = snapshot.pollenForecast;
  const time = new Date(snapshotTime(snapshot));
  if (!forecast || !Number.isFinite(time.getTime()) || kstDate(time) !== forecast.date) return [];
  const risks = forecast.risks.filter((risk) => high(risk.level));
  if (!risks.length) return [];
  const start = `${forecast.date}T00:00:00+09:00`;
  const end = new Date(Date.parse(start) + 24 * 3_600_000).toISOString();
  return [{ role: 'OFFICIAL_FACT', source: '기상청 꽃가루농도위험지수',
    text: `${forecast.date} 꽃가루 예측: ${risks.map((risk) => `${risk.species} ${risk.level} (${risk.issuedAt} 발표)`).join(' · ')}`,
    validFrom: start, validUntil: end }];
}

/** 대기정체는 농도와 별개이며, 한쪽 결측을 좋음으로 간주하지 않는다. */
export function ventilationAdvice(current: WeatherSnapshot, indices: TodayLivingIndices,
  now: Date): TodayWeatherResponse['lifestyleMessages'] {
  const stagnation = indices.airStagnation;
  if (!stagnation) return [];
  const issuedAge = now.getTime() - Date.parse(stagnation.issuedAt);
  const forecastAge = now.getTime() - Date.parse(stagnation.forecastAt);
  if (!Number.isFinite(issuedAge) || issuedAge < 0 || issuedAge >= 8 * 3_600_000 ||
      !Number.isFinite(forecastAge) || forecastAge >= 3 * 3_600_000 || forecastAge < -3 * 3_600_000) return [];
  const pmTime = Date.parse(current.airQualityObservedAt ?? '');
  const airKnown = current.pm10 !== undefined && Number.isFinite(current.pm10) && current.pm10 >= 0 &&
    current.pm25 !== undefined && Number.isFinite(current.pm25) && current.pm25 >= 0 &&
    Number.isFinite(pmTime) && now.getTime() >= pmTime && now.getTime() - pmTime < 3 * 3_600_000;
  const highOzone = typeof current.ozone === 'number' && Number.isFinite(current.ozone) &&
    current.ozone >= defaultRuleConfig.airQuality.ozone;
  const poor = airKnown && (current.pm10! >= defaultRuleConfig.airQuality.pm10 ||
    current.pm25! >= defaultRuleConfig.airQuality.pm25 || highOzone);
  const stagnant = high(stagnation.level);
  const title = !airKnown ? '환기 전에 최신 대기질을 확인하세요'
    : poor ? '바깥 대기질을 확인하고 환기는 짧게 나누세요'
    : stagnant ? '대기가 정체될 수 있어 환기 전 대기질을 다시 확인하세요'
    : '바깥 대기질을 확인하며 짧게 환기하세요';
  const detail = !airKnown ? '대기질 관측이 없거나 오래돼 환기 적합성을 판단하기 어려워요.'
    : poor ? '대기정체와 대기질 상태를 함께 고려한 안내예요. 필요한 환기를 계속 미루지는 마세요.'
    : '대기정체가 높다고 미세먼지 농도도 높다는 뜻은 아니에요. 실내 오염·비·강풍 등도 함께 살펴주세요.';
  const validUntil = new Date(Math.min(Date.parse(stagnation.issuedAt) + 8 * 3_600_000,
    Date.parse(stagnation.forecastAt) + 3 * 3_600_000,
    airKnown ? pmTime + 3 * 3_600_000 : Infinity)).toISOString();
  return [{ type: LifestyleInsightType.VENTILATION_GUIDANCE, title, description: detail,
    priority: poor ? 76 : 45, parts: [
      { role: 'APP_SUGGESTION', text: title, source: '날씨챙겨 환기 참고 안내', validUntil },
      { role: 'CALCULATED_FACT', text: detail, source: '날씨챙겨', validUntil },
      { role: 'OFFICIAL_FACT', text: `${stagnation.forecastAt} 예측 대기정체 ${stagnation.level}`,
        source: '기상청 대기정체지수', validUntil },
      airKnown ? { role: 'OFFICIAL_FACT', text: `${current.airQualityObservedAt} 관측 미세먼지 ${current.pm10}㎍/㎥ · 초미세먼지 ${current.pm25}㎍/㎥${highOzone ? ` · 오존 ${current.ozone}ppm` : ''}`, source: '에어코리아', validUntil }
        : { role: 'DATA_STATUS', text: '최신 대기질 자료가 필요해요.', source: '에어코리아', validUntil },
    ] }];
}
