import { lifestyleMessageFor } from '../lifestyle/lifestyleTemplates';
import {
  AmountRange,
  EnvironmentalSourceStatus,
  LifestyleInsight,
  LifestyleInsightType,
  TodayWeatherResponse,
  WeatherMessagePart,
  WeatherRuleFact,
  WeatherRuleFactType,
  WeatherSnapshot,
} from '../types';
import {
  amountMinimum,
  isWetSnapshot,
  snapshotTime,
} from '../rules/timeWindows';
import {
  parasolBenefitMessage,
  sensationMessage,
} from './sensationMessages';
import { isPrecipitationFact, precipitationStart, precipitationEnd,
  precipitationPeriod, precipitationLabel, otherDatePrefix, koreanHour } from '../rules/precipitationWindows';

export function buildLifestyleMessages(
  insights: LifestyleInsight[],
  facts: WeatherRuleFact[] = [],
  hourly: WeatherSnapshot[] = [],
  regionName = '선택한 지역',
): TodayWeatherResponse['lifestyleMessages'] {
  return insights.map((item) => {
    const message = lifestyleMessageFor(item.type, item.score, item.context);
    const impactText = impactTextFor(item, facts, hourly) ?? message.description;
    const validFrom = stringContext(item, 'validFrom');
    const validUntil = stringContext(item, 'validUntil');
    const parts: WeatherMessagePart[] = [
      {
        role: 'APP_SUGGESTION',
        text: message.title,
        source: '날씨챙겨',
        validFrom,
        validUntil,
      },
    ];
    if (impactText) {
      parts.push({
        role: impactRole(item.type),
        text: impactText,
        source: '날씨챙겨',
        validFrom,
        validUntil,
      });
    }
    const grounding = groundingPartFor(item, facts, hourly, regionName);
    if (grounding) parts.push(grounding);
    const dataStatus = dataStatusPartFor(item, hourly);
    if (dataStatus) parts.push(dataStatus);

    return {
      type: item.type,
      title: message.title,
      description: impactText || undefined,
      priority: item.score,
      parts: deduplicateParts(parts),
    };
  });
}

export function buildEnvironmentalDataStatusMessages(sources: {
  uv: EnvironmentalSourceStatus;
  airQuality: EnvironmentalSourceStatus;
}): WeatherMessagePart[] {
  return [
    environmentalStatusPart('자외선지수', sources.uv),
    environmentalStatusPart('대기질', sources.airQuality),
  ].filter((item): item is WeatherMessagePart => item !== undefined);
}

function impactRole(type: LifestyleInsightType): WeatherMessagePart['role'] {
  return type === LifestyleInsightType.BEST_OUTING_WINDOW
    ? 'CALCULATED_FACT'
    : 'INTERNAL_POSSIBILITY';
}

function groundingPartFor(
  insight: LifestyleInsight,
  facts: WeatherRuleFact[],
  hourly: WeatherSnapshot[],
  regionName: string,
): WeatherMessagePart | undefined {
  const fact = strongestFactFor(insight, facts);
  const groundingAt = stringContext(insight, 'groundingAt');
  const snapshot = groundingAt ? hourly.find((item) => snapshotTime(item) === groundingAt)
    : snapshotForInsight(insight.type, hourly, fact);

  switch (insight.type) {
    case LifestyleInsightType.RAIN_GEAR_USEFUL:
    case LifestyleInsightType.WET_ROAD_CAUTION:
      return snapshot ? precipitationFact(snapshot, regionName) : undefined;
    case LifestyleInsightType.LAUNDRY_PICKUP_DUE:
    case LifestyleInsightType.WINDOW_CLOSE_SOON:
      if (!snapshot) return undefined;
      if (stringContext(insight, 'messageContext') === 'SNOW') {
        return snowfallFact(snapshot, regionName);
      }
      if (stringContext(insight, 'messageContext') === 'WIND') {
        return windFact(snapshot, regionName);
      }
      return precipitationFact(snapshot, regionName);
    case LifestyleInsightType.SNOW_TRAVEL_CAUTION:
      return snapshot ? snowfallFact(snapshot, regionName) : undefined;
    case LifestyleInsightType.STRONG_SUN_EXPOSURE:
    case LifestyleInsightType.SUNSCREEN_USEFUL:
      return snapshot ? uvFact(snapshot, regionName) : undefined;
    case LifestyleInsightType.MASK_USEFUL:
      return snapshot ? airQualityFact(snapshot, regionName) : undefined;
    case LifestyleInsightType.OZONE_CAUTION:
      return snapshot ? ozoneFact(snapshot, regionName) : undefined;
    case LifestyleInsightType.HYDRATION_IMPORTANT:
    case LifestyleInsightType.VERY_HOT_AND_HUMID:
      return snapshot ? apparentTemperatureFact(snapshot) : undefined;
    case LifestyleInsightType.OUTERWEAR_USEFUL:
    case LifestyleInsightType.COOLER_THAN_TEMPERATURE:
      return snapshot ? temperatureFact(snapshot, regionName) : undefined;
    case LifestyleInsightType.OUTDOOR_ACTIVITY_CAUTION:
      return snapshot ? windFact(snapshot, regionName) : undefined;
    case LifestyleInsightType.LARGE_TEMPERATURE_SWING:
      return calculatedDifferenceFact(
        fact,
        'dailyTemperatureRange',
        '제공된 시간대의 최저·최고 예보기온 차이',
      );
    case LifestyleInsightType.RAPID_TEMPERATURE_DROP:
      return calculatedDifferenceFact(
        fact,
        'temperatureChange',
        '앞 시간과 뒤 시간의 예보기온 차이',
      );
    case LifestyleInsightType.NIGHT_WEATHER_CHECK:
      return nightWeatherFact(fact);
    case LifestyleInsightType.RAIN_BREAK_WINDOW:
    case LifestyleInsightType.BEST_OUTING_WINDOW:
    case LifestyleInsightType.PET_WALK_WINDOW:
    case LifestyleInsightType.BLACK_ICE_CAUTION:
    case LifestyleInsightType.COMMUTE_ROUTE_CAUTION:
      return undefined;
  }
}

function strongestFactFor(
  insight: LifestyleInsight,
  facts: WeatherRuleFact[],
): WeatherRuleFact | undefined {
  return facts
    .filter((fact) => insight.sourceFacts.includes(fact.type))
    .sort((left, right) => right.severity - left.severity)[0];
}

function snapshotForInsight(
  type: LifestyleInsightType,
  hourly: WeatherSnapshot[],
  fact?: WeatherRuleFact,
): WeatherSnapshot | undefined {
  const candidates = fact?.validFrom
    ? hourly.filter((item) => {
        const rain = fact && isPrecipitationFact(fact.type);
        const time = Date.parse(rain ? precipitationStart(item) : snapshotTime(item));
        const itemEnd = rain ? Date.parse(precipitationEnd(item)) : time;
        const start = Date.parse(fact.validFrom ?? '');
        const end = Date.parse(fact.validUntil ?? fact.validFrom ?? '');
        return Number.isFinite(start) && itemEnd >= start && time <= end;
      })
    : hourly;
  const source = fact?.validFrom ? candidates : hourly;

  switch (type) {
    case LifestyleInsightType.RAIN_GEAR_USEFUL:
    case LifestyleInsightType.RAIN_BREAK_WINDOW:
    case LifestyleInsightType.LAUNDRY_PICKUP_DUE:
    case LifestyleInsightType.WINDOW_CLOSE_SOON:
    case LifestyleInsightType.WET_ROAD_CAUTION:
      return source.find(isWetSnapshot);
    case LifestyleInsightType.SNOW_TRAVEL_CAUTION:
      return source.find(
        (item) =>
          item.snowExpected === true ||
          item.precipitationType === 'SNOW' ||
          item.precipitationType === 'RAIN_SNOW',
      );
    case LifestyleInsightType.STRONG_SUN_EXPOSURE:
    case LifestyleInsightType.SUNSCREEN_USEFUL:
      return maximumBy(source, (item) => item.uvIndex);
    case LifestyleInsightType.MASK_USEFUL:
      return source.find(
        (item) => item.pm10 !== undefined || item.pm25 !== undefined,
      );
    case LifestyleInsightType.OZONE_CAUTION:
      return source.find(
        (item) => item.ozone !== undefined || item.ozoneGrade !== undefined,
      );
    case LifestyleInsightType.HYDRATION_IMPORTANT:
    case LifestyleInsightType.VERY_HOT_AND_HUMID:
      return maximumBy(source, (item) => item.apparentTemperature);
    case LifestyleInsightType.OUTERWEAR_USEFUL:
    case LifestyleInsightType.COOLER_THAN_TEMPERATURE:
      return minimumBy(
        source,
        (item) => item.apparentTemperature ?? item.temperature,
      );
    case LifestyleInsightType.OUTDOOR_ACTIVITY_CAUTION:
      return maximumBy(source, (item) => item.windSpeed);
    case LifestyleInsightType.LARGE_TEMPERATURE_SWING:
    case LifestyleInsightType.RAPID_TEMPERATURE_DROP:
    case LifestyleInsightType.BEST_OUTING_WINDOW:
    case LifestyleInsightType.PET_WALK_WINDOW:
    case LifestyleInsightType.NIGHT_WEATHER_CHECK:
    case LifestyleInsightType.BLACK_ICE_CAUTION:
    case LifestyleInsightType.COMMUTE_ROUTE_CAUTION:
      return source[0];
  }
}

function impactTextFor(
  insight: LifestyleInsight,
  facts: WeatherRuleFact[],
  hourly: WeatherSnapshot[],
): string | undefined {
  const fact = strongestFactFor(insight, facts);
  const snapshot = snapshotForInsight(insight.type, hourly, fact);
  if (!snapshot) return undefined;
  const time = timeRangeLabel(snapshot);
  const variant = Math.abs(insight.score) % 3;

  if (insight.type === LifestyleInsightType.RAIN_GEAR_USEFUL) {
    const amount = amountForImpact(
      snapshot.precipitationAmountRange,
      snapshot.precipitationAmount,
    );
    if (amount === undefined) return undefined;
    return rainImpactMessages(time, amount)[variant];
  }
  if (insight.type === LifestyleInsightType.SNOW_TRAVEL_CAUTION) {
    const amount = amountForImpact(
      snapshot.snowfallAmountRange,
      snapshot.snowfallAmount,
    );
    if (amount === undefined || amount <= 0) return undefined;
    return snowImpactMessages(time, amount)[variant];
  }
  if (insight.type === LifestyleInsightType.STRONG_SUN_EXPOSURE) {
    return parasolBenefitMessage(insight.score);
  }
  if (insight.type === LifestyleInsightType.SUNSCREEN_USEFUL) {
    return sensationMessage('UV_DIRECT_PERCEPTION', variant);
  }
  if (insight.type === LifestyleInsightType.MASK_USEFUL) {
    return sensationMessage('PM_DIRECT_PERCEPTION', variant);
  }
  if (insight.type === LifestyleInsightType.OZONE_CAUTION) {
    return sensationMessage('OZONE_DIRECT_PERCEPTION', variant);
  }
  if (insight.type === LifestyleInsightType.VERY_HOT_AND_HUMID) {
    return sensationMessage('HOT_HUMID', variant);
  }
  return undefined;
}

function rainImpactMessages(time: string, amount: number): string[] {
  if (amount < 3) {
    return [
      `${time}에는 가벼운 빗방울이 떨어질 수 있어요.`,
      `${time}에는 약한 빗방울이 내릴 수 있어요.`,
      `${time}에는 이슬비처럼 약한 비가 내릴 수 있어요.`,
    ];
  }
  if (amount < 5) {
    return [
      `${time}에는 옷이나 머리카락이 조금 젖을 만큼 비가 올 수도 있어요.`,
      `${time}에는 빗방울에 옷이나 머리카락이 조금씩 젖을 수 있어요.`,
      `${time}에 우산 없이 걸으면 옷이나 머리카락이 조금 젖을 수 있어요.`,
    ];
  }
  if (amount < 15) {
    return [
      `${time}에는 우산이 없으면 옷과 신발이 젖을 수 있어요.`,
      `${time}에는 안경이나 차량 유리에 빗물이 맺혀 앞이 흐리게 보일 수 있어요.`,
      `${time}에 걸어서 이동한다면 옷과 신발이 비에 젖을 수 있어요.`,
    ];
  }
  if (amount < 30) {
    return [
      `${time}에는 우산을 써도 옷이 젖을 수 있어요.`,
      `${time}에는 보행로 곳곳에 물이 고일 수 있어요.`,
      `${time}에는 낮은 곳에 물이 차기 시작할 수 있어요.`,
    ];
  }
  if (amount < 50) {
    return [
      `${time}에는 배수가 좋지 않은 보행로에서 신발이 젖을 수 있어요.`,
      `${time}에는 물고임이 많은 구간에서 이동이 불편할 수 있어요.`,
      `${time}에는 차량 운행이 어려워질 수 있어요.`,
    ];
  }
  return [
    `${time}에는 정상적으로 걷기 어려울 수 있어요.`,
    `${time}에는 차량 운행이 어려워질 수 있어요.`,
    `${time}에는 극심한 교통정체가 발생할 수 있어요.`,
  ];
}

function snowImpactMessages(time: string, amount: number): string[] {
  if (amount < 0.5) {
    return [
      `${time}에는 바닥에 눈이 아주 얇게 쌓일 수 있어요.`,
      `${time}에는 바닥에 눈이 살짝 내려앉을 수 있어요.`,
      `${time}에는 눈이 쌓이기 시작할 수 있어요.`,
    ];
  }
  if (amount < 1.5) {
    return [
      `${time}에는 바닥이 눈으로 덮일 수 있어요.`,
      `${time}에는 눈이 쌓일 수 있어요.`,
      `${time}에는 바닥의 색이 눈으로 달라졌다고 느낄 수도 있어요.`,
    ];
  }
  if (amount < 3) {
    return [
      `${time}에는 눈이 꽤 쌓일 수 있어요.`,
      `${time}에는 바닥이 눈으로 넓게 덮일 수 있어요.`,
      `${time}에는 발이 눈에 들어갈 수 있어요.`,
    ];
  }
  return [
    `${time}에는 짧은 시간 동안 눈이 빠르게 쌓일 수 있어요.`,
    `${time}에는 바닥에 쌓인 눈이 빠르게 늘어날 수 있어요.`,
    `${time}에는 제설 전 도로에 눈이 빠르게 쌓일 수 있어요.`,
  ];
}

function amountForImpact(
  range?: AmountRange,
  value?: number,
): number | undefined {
  if (!range || range.type === 'NONE') return value;
  if (range.type === 'LESS_THAN') {
    const upperBound = range.max ?? range.min ?? value;
    return upperBound === undefined ? undefined : Math.max(0, upperBound - 0.001);
  }
  return range.min ?? range.max ?? value;
}

function nightWeatherFact(
  fact: WeatherRuleFact | undefined,
): WeatherMessagePart | undefined {
  if (!fact) return undefined;
  return {
    role: 'OFFICIAL_FACT',
    text: '기상청은 오늘 밤 기온과 습도가 높을 것으로 예보했어요',
    source: '기상청 단기예보',
    validFrom: fact.validFrom,
    validUntil: fact.validUntil,
  };
}

function precipitationFact(
  snapshot: WeatherSnapshot,
  regionName: string,
): WeatherMessagePart {
  const time = timeRangeLabel(snapshot);
  const amount = amountLabel(snapshot.precipitationAmountRange);
  const shower = snapshot.precipitationType === 'SHOWER';
  const regionAt = regionName === '현재 위치' ? '' : `${regionName}에 `;
  const regionOf = regionName === '현재 위치' ? '' : `${regionName}의 `;
  const text = shower
    ? `기상청은 ${regionAt}${time} 소나기를 예보했어요`
    : amount
      ? `기상청은 ${regionAt}${time} 시간당 ${amount}의 비를 예보했어요`
      : `기상청은 ${regionOf}${time} 강수확률을 ${Math.round(snapshot.precipitationProbability ?? 0)}%로 예보했어요`;
  return { ...officialFact(text, snapshot, '기상청'),
    validFrom: precipitationStart(snapshot), validUntil: precipitationEnd(snapshot) };
}

function snowfallFact(
  snapshot: WeatherSnapshot,
  regionName: string,
): WeatherMessagePart {
  const time = timeRangeLabel(snapshot);
  const amount = amountLabel(snapshot.snowfallAmountRange);
  const regionAt = regionName === '현재 위치' ? '' : `${regionName}에 `;
  const text = amount
    ? `기상청은 ${regionAt}${time} 눈이 ${amount} 쌓일 것으로 예보했어요`
    : `기상청은 ${regionAt}${time} 눈을 예보했어요`;
  return { ...officialFact(text, snapshot, '기상청'),
    validFrom: precipitationStart(snapshot), validUntil: precipitationEnd(snapshot) };
}

function uvFact(
  snapshot: WeatherSnapshot,
  regionName: string,
): WeatherMessagePart | undefined {
  if (snapshot.uvIndex === undefined) return undefined;
  const forecastAt = snapshotTime(snapshot);
  if (!Number.isFinite(Date.parse(forecastAt))) return undefined;
  const time = otherDatePrefix(forecastAt, snapshot.fetchedAt) + koreanHour(forecastAt);
  const value = Math.round(snapshot.uvIndex);
  const regionOf = regionName === '현재 위치' ? '' : `${regionName}의 `;
  return officialFact(
    `기상청은 ${time} ${regionOf}자외선지수를 ${value}, ${uvGrade(value)} 단계로 예보했어요`,
    snapshot,
    '기상청 생활기상지수',
  );
}

function airQualityFact(
  snapshot: WeatherSnapshot,
  regionName: string,
): WeatherMessagePart | undefined {
  const station = snapshot.airQualityStationName ?? `${regionName} 측정소`;
  const time = formatHour(
    snapshot.airQualityObservedAt ?? snapshot.observedAt,
  );
  if (snapshot.pm25 !== undefined) {
    return {
      ...officialFact(
        `에어코리아는 ${time} ${station}의 초미세먼지 농도를 ${Math.round(snapshot.pm25)}㎍/㎥로 제공했어요`,
        snapshot,
        '에어코리아',
      ),
      validFrom: snapshot.airQualityObservedAt,
      validUntil: undefined,
    };
  }
  if (snapshot.pm10 !== undefined) {
    return {
      ...officialFact(
        `에어코리아는 ${time} ${station}의 미세먼지 농도를 ${Math.round(snapshot.pm10)}㎍/㎥로 제공했어요`,
        snapshot,
        '에어코리아',
      ),
      validFrom: snapshot.airQualityObservedAt,
      validUntil: undefined,
    };
  }
  return undefined;
}

function ozoneFact(
  snapshot: WeatherSnapshot,
  regionName: string,
): WeatherMessagePart | undefined {
  if (snapshot.ozone === undefined && snapshot.ozoneGrade === undefined) {
    return undefined;
  }
  const station = snapshot.airQualityStationName ?? `${regionName} 측정소`;
  const time = formatHour(
    snapshot.airQualityObservedAt ?? snapshot.observedAt,
  );
  const grade = ozoneGradeLabel(snapshot.ozoneGrade, snapshot.ozone);
  const text = snapshot.ozone === undefined
    ? `에어코리아는 ${time} ${station}의 오존 등급을 ${grade}으로 제공했어요`
    : `에어코리아는 ${time} ${station}의 오존 농도를 ${snapshot.ozone.toFixed(3)}ppm, ${grade} 단계로 제공했어요`;
  return {
    ...officialFact(text, snapshot, '에어코리아'),
    validFrom: snapshot.airQualityObservedAt,
    validUntil: undefined,
  };
}

function ozoneGradeLabel(
  providerGrade: string | undefined,
  ozone: number | undefined,
): string {
  const provided = {
    Good: '좋음',
    Moderate: '보통',
    Bad: '나쁨',
    'Very Bad': '매우 나쁨',
  }[providerGrade ?? ''];
  if (provided) return provided;
  if (ozone === undefined) return '확인 어려움';
  if (ozone <= 0.03) return '좋음';
  if (ozone <= 0.09) return '보통';
  if (ozone <= 0.15) return '나쁨';
  return '매우 나쁨';
}

function apparentTemperatureFact(
  snapshot: WeatherSnapshot,
): WeatherMessagePart | undefined {
  if (snapshot.apparentTemperature === undefined) return undefined;
  return {
    role: 'CALCULATED_FACT',
    text: `기상청 단기예보 기온·습도·풍속 기준 ${formatHour(snapshotTime(snapshot))} 예상 체감온도는 ${formatNumber(snapshot.apparentTemperature)}℃예요`,
    source: '날씨챙겨 계산',
    validFrom: snapshot.validFrom ?? snapshot.forecastAt,
    validUntil: snapshot.validTo,
  };
}

function temperatureFact(
  snapshot: WeatherSnapshot,
  regionName: string,
): WeatherMessagePart | undefined {
  if (snapshot.temperature === undefined) return undefined;
  if (regionName === '현재 위치') {
    return officialFact(
      `기상청은 ${formatHour(snapshotTime(snapshot))} 기온이 ${formatNumber(snapshot.temperature)}℃라고 예보했어요`,
      snapshot,
      '기상청',
    );
  }
  return officialFact(
    `기상청은 ${regionName}의 ${formatHour(snapshotTime(snapshot))} 기온은 ${formatNumber(snapshot.temperature)}℃라고 예보했어요`,
    snapshot,
    '기상청',
  );
}

function windFact(
  snapshot: WeatherSnapshot,
  regionName: string,
): WeatherMessagePart | undefined {
  if (snapshot.windSpeed === undefined) return undefined;
  const regionAt = regionName === '현재 위치' ? '' : `${regionName}에 `;
  return officialFact(
    `기상청은 ${formatHour(snapshotTime(snapshot))} ${regionAt}풍속 ${formatNumber(snapshot.windSpeed)}m/s의 ${windLabel(snapshot.windSpeed)} 바람을 예보했어요`,
    snapshot,
    '기상청',
  );
}

function calculatedDifferenceFact(
  fact: WeatherRuleFact | undefined,
  evidenceKey: string,
  label: string,
): WeatherMessagePart | undefined {
  const raw = fact?.evidence[evidenceKey];
  if (typeof raw !== 'number') return undefined;
  return {
    role: 'CALCULATED_FACT',
    text: `${label}는 ${formatNumber(Math.abs(raw))}℃로 계산됐어요`,
    source: '날씨챙겨 계산',
    validFrom: fact?.validFrom,
    validUntil: fact?.validUntil,
  };
}

function dataStatusPartFor(
  insight: LifestyleInsight,
  hourly: WeatherSnapshot[],
): WeatherMessagePart | undefined {
  const flags = new Set(hourly.flatMap((item) => item.qualityFlags ?? []));
  if (
    insight.sourceFacts.includes(WeatherRuleFactType.RAIN_LIKELY) &&
    flags.has('MISSING_PCP')
  ) {
    return {
      role: 'DATA_STATUS',
      text: '강수량 자료를 받아오지 못해 예상 강수량을 확인하기 어려워요',
      source: '기상청 단기예보',
    };
  }
  if (
    insight.sourceFacts.some((type) =>
      [WeatherRuleFactType.SNOW_LIKELY, WeatherRuleFactType.HEAVY_SNOW].includes(
        type,
      ),
    ) &&
    flags.has('MISSING_SNO')
  ) {
    return {
      role: 'DATA_STATUS',
      text: '적설량 자료를 받아오지 못해 예상 적설량을 확인하기 어려워요',
      source: '기상청 단기예보',
    };
  }
  return undefined;
}

function environmentalStatusPart(
  label: string,
  source: EnvironmentalSourceStatus,
): WeatherMessagePart | undefined {
  if (source.state === 'AVAILABLE' || source.state === 'CACHED') {
    return undefined;
  }
  if (source.state === 'STALE') {
    return {
      role: 'DATA_STATUS',
      text: source.observedAt
        ? `마지막으로 확인한 ${label}은 ${formatHour(source.observedAt)} 자료예요 · 이후 달라졌을 수 있어요`
        : `마지막으로 확인한 ${label}은 이전 자료예요 · 현재 상태는 달라졌을 수 있어요`,
      source: source.provider,
    };
  }
  if (source.state === 'UNSUPPORTED_REGION') {
    return {
      role: 'DATA_STATUS',
      text: `선택한 지역에서는 ${label} 자료를 지원하지 않아 확인하기 어려워요`,
      source: source.provider,
    };
  }
  return {
    role: 'DATA_STATUS',
    text: `자료를 받아오지 못해 ${label}을 확인하기 어려워요`,
    source: source.provider,
  };
}

function officialFact(
  text: string,
  snapshot: WeatherSnapshot,
  source: string,
): WeatherMessagePart {
  return {
    role: 'OFFICIAL_FACT',
    text,
    source,
    validFrom: snapshot.validFrom ?? snapshot.forecastAt,
    validUntil: snapshot.validTo,
  };
}

function amountLabel(range?: AmountRange): string | undefined {
  if (!range || range.type === 'NONE') return undefined;
  if (range.type === 'LESS_THAN') {
    return `${formatNumber(range.max ?? range.min ?? 0)}${unitLabel(range)} 미만`;
  }
  if (range.type === 'RANGE') {
    return `${formatNumber(range.min ?? 0)}~${formatNumber(range.max ?? 0)}${unitLabel(range)}`;
  }
  if (range.type === 'AT_LEAST') {
    return `${formatNumber(range.min ?? range.max ?? 0)}${unitLabel(range)} 이상`;
  }
  return `${formatNumber(range.min ?? range.max ?? 0)}${unitLabel(range)}`;
}

function unitLabel(range: AmountRange): string {
  return range.unit === 'MM' ? 'mm' : 'cm';
}

function timeRangeLabel(snapshot: WeatherSnapshot): string {
  if (precipitationPeriod(snapshot)) return precipitationLabel(snapshot);
  const start = formatHour(snapshotTime(snapshot));
  if (!snapshot.validTo) return start;
  const endTimestamp = Date.parse(snapshot.validTo) + 60_000;
  const end = Number.isFinite(endTimestamp)
    ? formatHour(new Date(endTimestamp).toISOString())
    : formatHour(snapshot.validTo);
  if (start === end) return start;

  const startMatch = /^(오전|오후) (.+)$/.exec(start);
  const endMatch = /^(오전|오후) (.+)$/.exec(end);
  if (startMatch && endMatch && startMatch[1] === endMatch[1]) {
    return `${startMatch[1]} ${startMatch[2]}~${endMatch[2]}`;
  }
  return `${start}~${end}`;
}

function formatHour(iso: string): string {
  const hasOffset = /[+-]\d{2}:\d{2}$/.test(iso);
  const local = hasOffset
    ? iso.slice(11, 16)
    : new Date(Date.parse(iso) + 9 * 60 * 60 * 1000)
        .toISOString()
        .slice(11, 16);
  const hour = Number(local.slice(0, 2));
  const minute = Number(local.slice(3, 5));
  const period = hour < 12 ? '오전' : '오후';
  const hour12 = hour % 12 || 12;
  return `${period} ${hour12}시${minute === 0 ? '' : ` ${minute}분`}`;
}

function uvGrade(value: number): string {
  if (value <= 2) return '낮음';
  if (value <= 5) return '보통';
  if (value <= 7) return '높음';
  if (value <= 10) return '매우 높음';
  return '위험';
}

function windLabel(speed: number): string {
  if (speed < 4) return '약한';
  if (speed < 9) return '약간 강한';
  if (speed < 14) return '강한';
  return '매우 강한';
}

function formatNumber(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(1);
}

function stringContext(
  insight: LifestyleInsight,
  key: string,
): string | undefined {
  const value = insight.context?.[key];
  return typeof value === 'string' ? value : undefined;
}

function maximumBy(
  values: WeatherSnapshot[],
  select: (value: WeatherSnapshot) => number | undefined,
): WeatherSnapshot | undefined {
  return values.reduce<WeatherSnapshot | undefined>((picked, item) => {
    const value = select(item);
    if (value === undefined) return picked;
    if (!picked) return item;
    return value > (select(picked) ?? -Infinity) ? item : picked;
  }, undefined);
}

function minimumBy(
  values: WeatherSnapshot[],
  select: (value: WeatherSnapshot) => number | undefined,
): WeatherSnapshot | undefined {
  return values.reduce<WeatherSnapshot | undefined>((picked, item) => {
    const value = select(item);
    if (value === undefined) return picked;
    if (!picked) return item;
    return value < (select(picked) ?? Infinity) ? item : picked;
  }, undefined);
}

function deduplicateParts(parts: WeatherMessagePart[]): WeatherMessagePart[] {
  const seen = new Set<string>();
  return parts.filter((part) => {
    const key = `${part.role}|${part.text}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
