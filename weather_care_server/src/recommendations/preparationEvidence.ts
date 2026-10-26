import type { WeatherMessagePart, WeatherSnapshot } from '../types';
import { snapshotTime } from '../rules/timeWindows';
import { formatWeatherNumber as number } from '../utils/weatherNumber';
import { pollenEvidence } from '../services/livingIndexAdvice';

export type PreparationReason = 'snow' | 'heat' | 'cold' | 'rain' | 'air' | 'uv' | 'humidity';

/** 추천을 실제로 발생시킨 시간 자료와 앱 판단 기준을 함께 보존한다. */
export function buildPreparationEvidence(
  snapshot: WeatherSnapshot,
  reason: PreparationReason,
  criterion: string,
): WeatherMessagePart[] {
  const values: string[] = [];
  const add = (label: string, value: number | undefined, unit: string) => {
    if (value !== undefined && Number.isFinite(value)) values.push(`${label} ${number(value)}${unit}`);
  };
  let calculated = snapshot.dataRole === 'ANALYSIS';
  let source = snapshot.provider ?? '기상 자료';
  switch (reason) {
    case 'cold':
    case 'heat': {
      add('기온', snapshot.temperature, '℃');
      const apparent = snapshot.kmaApparentTemperature ?? snapshot.apparentTemperature;
      if (apparent !== undefined) {
        add('체감온도', apparent, '℃');
        calculated ||= snapshot.apparentTemperatureSource !== 'OFFICIAL_KMA_VALUE';
        if (calculated) source = '날씨챙겨 체감온도 계산';
      }
      break;
    }
    case 'uv':
      add('자외선지수', snapshot.uvIndex, '');
      source = snapshot.uvProvider ?? '자외선 자료';
      break;
    case 'air':
      add('미세먼지', snapshot.pm10, '㎍/㎥');
      add('초미세먼지', snapshot.pm25, '㎍/㎥');
      if (snapshot.pm25ForecastGrade) values.push(`초미세먼지 예보 ${snapshot.pm25ForecastGrade}`);
      if (!values.length && snapshot.airQualityGrade) values.push(`대기질 등급 ${snapshot.airQualityGrade}`);
      source = '에어코리아';
      break;
    case 'humidity':
      add('습도', snapshot.humidity, '%');
      break;
    case 'rain':
    case 'snow': {
      const types = { NONE: '없음', RAIN: '비', RAIN_SNOW: '비/눈', SNOW: '눈', SHOWER: '소나기' };
      if (snapshot.precipitationType) values.push(`강수형태 ${types[snapshot.precipitationType]}`);
      if (reason === 'rain') {
        add('강수확률', snapshot.precipitationProbability, '%');
        if (snapshot.precipitationAmountRange?.rawValue) {
          values.push(`1시간 강수량 ${snapshot.precipitationAmountRange.rawValue}`);
        } else add('1시간 강수량', snapshot.precipitationAmount, 'mm');
      } else {
        if (snapshot.snowExpected) values.push('눈 예보 있음');
        // snowProbability는 PTY에서 파생될 수 있으므로 공식 확률로 표시하지 않는다.
        if (snapshot.snowProbability !== undefined) {
          values.push(`눈 판단 지표 ${number(snapshot.snowProbability)}%`);
          calculated = true;
          source = '날씨챙겨 눈 판단';
        }
        if (snapshot.snowfallAmountRange?.rawValue) {
          values.push(`1시간 신적설 ${snapshot.snowfallAmountRange.rawValue}`);
        } else add('1시간 신적설', snapshot.snowfallAmount, 'cm');
      }
      break;
    }
  }
  const pollen = reason === 'air' ? pollenEvidence(snapshot) : [];
  if (values.length === 0) return pollen;
  const validFrom = snapshotTime(snapshot);
  const date = new Date(Date.parse(validFrom) + 9 * 60 * 60 * 1000);
  if (!Number.isFinite(date.getTime())) return [];
  const time = `${date.getUTCMonth() + 1}월 ${date.getUTCDate()}일 ${date.getUTCHours()}시` +
    (date.getUTCMinutes() ? ` ${date.getUTCMinutes()}분` : '');
  const role = snapshot.dataRole === 'OBSERVATION' ? '관측' : snapshot.dataRole === 'FORECAST' ? '예보' : '자료';
  return [
    { role: calculated ? 'CALCULATED_FACT' : 'OFFICIAL_FACT',
      text: `${time} ${role}: ${values.join(' · ')}`, source, validFrom, validUntil: snapshot.validTo },
    ...pollen,
    { role: 'CALCULATED_FACT', text: `적용한 준비물 판단 기준: ${criterion}`,
      source: '날씨챙겨 준비물 판단', validFrom, validUntil: snapshot.validTo },
  ];
}
