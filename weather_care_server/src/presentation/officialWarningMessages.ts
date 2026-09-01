import {
  OfficialWeatherWarning,
} from '../providers/warnings/kmaWarningProvider';
import { LifestyleInsightType, TodayWeatherResponse } from '../types';

export interface WarningNotificationContent {
  title: string;
  body: string;
}

const WARNING_PRESENTATION: Record<
  OfficialWeatherWarning['typeCode'],
  { type: LifestyleInsightType; action: string }
> = {
  W: {
    type: LifestyleInsightType.OUTDOOR_ACTIVITY_CAUTION,
    action:
      '강풍특보가 발효 중이니, 야외활동을 줄이고 간판·수목·유리창·공사장 주변을 피하세요',
  },
  R: {
    type: LifestyleInsightType.RAIN_GEAR_USEFUL,
    action:
      '호우특보가 발효 중이니, 하천변과 지하차도에 접근하지 마세요',
  },
  C: {
    type: LifestyleInsightType.OUTERWEAR_USEFUL,
    action:
      '한파특보가 발효 중이니, 외출한다면 모자·장갑·목도리를 준비하세요',
  },
  D: {
    type: LifestyleInsightType.OUTDOOR_ACTIVITY_CAUTION,
    action:
      '건조특보가 발효 중이니, 산불로 이어질 수 있는 야외 불씨 사용을 피하세요',
  },
  O: {
    type: LifestyleInsightType.OUTDOOR_ACTIVITY_CAUTION,
    action:
      '해일특보가 발효 중이니, 해안가와 방파제에서 벗어나 높은 곳으로 이동하세요',
  },
  N: {
    type: LifestyleInsightType.OUTDOOR_ACTIVITY_CAUTION,
    action:
      '지진해일특보가 발효 중이니, 해안가에서 벗어나 높은 곳으로 이동하세요',
  },
  V: {
    type: LifestyleInsightType.OUTDOOR_ACTIVITY_CAUTION,
    action:
      '풍랑특보가 발효 중이니, 해안가와 방파제에 접근하지 마세요',
  },
  T: {
    type: LifestyleInsightType.OUTDOOR_ACTIVITY_CAUTION,
    action:
      '태풍특보가 발효 중이니, 야외 보행·운동·작업을 즉시 중단하세요',
  },
  S: {
    type: LifestyleInsightType.SNOW_TRAVEL_CAUTION,
    action:
      '대설특보가 발효 중이니, 외출 전에 도로 통제와 대중교통 운행정보를 확인하세요',
  },
  Y: {
    type: LifestyleInsightType.MASK_USEFUL,
    action:
      '황사특보가 발효 중이니, 외출한다면 보건용 마스크를 착용하세요',
  },
  H: {
    type: LifestyleInsightType.HYDRATION_IMPORTANT,
    action:
      '폭염특보가 발효 중이니, 낮 동안 야외활동을 줄이고 시원한 곳에서 쉬세요',
  },
  F: {
    type: LifestyleInsightType.WET_ROAD_CAUTION,
    action:
      '안개특보가 발효 중이니, 운전한다면 속도를 줄이고 앞차와 거리를 충분히 두세요',
  },
  K: {
    type: LifestyleInsightType.NIGHT_WEATHER_CHECK,
    action:
      '열대야특보가 발효 중이니, 잠들기 전에 냉방이나 제습으로 수면 환경을 조절하세요',
  },
};

export function buildActiveWarningMessages(
  warnings: readonly OfficialWeatherWarning[],
  regionName: string,
): TodayWeatherResponse['lifestyleMessages'] {
  return [...warnings]
    .sort((left, right) => Number(right.levelCode) - Number(left.levelCode))
    .map((warning) => {
      const presentation = WARNING_PRESENTATION[warning.typeCode];
      const fact = activeWarningFact(warning, regionName);
      return {
        type: presentation.type,
        title: presentation.action,
        description: fact,
        priority: warning.levelCode === '3' ? 130 : 120,
        parts: [
          {
            role: 'APP_SUGGESTION' as const,
            text: presentation.action,
            source: '날씨챙겨',
            validFrom: warning.validFrom,
          },
          {
            role: 'OFFICIAL_FACT' as const,
            text: fact,
            source: warning.provider,
            validFrom: warning.validFrom,
          },
        ],
      };
    });
}

export function activeWarningNotification(
  warning: OfficialWeatherWarning,
  regionName: string,
): WarningNotificationContent {
  return {
    title: `${warning.type}${warning.level} 발효`,
    body: `${WARNING_PRESENTATION[warning.typeCode].action} ${activeWarningFact(warning, regionName)}`,
  };
}

export function changedWarningNotification(
  warning: OfficialWeatherWarning,
  previousLevel: '주의보' | '경보',
  regionName: string,
): WarningNotificationContent {
  return {
    title: `${warning.type}특보 변경`,
    body: `${WARNING_PRESENTATION[warning.typeCode].action} 기상청은 ${regionName}의 ${warning.type}${previousLevel}를 ${warning.type}${warning.level}로 변경했어요`,
  };
}

export function releasedWarningNotification(
  warning: Pick<OfficialWeatherWarning, 'type' | 'level'>,
  regionName: string,
): WarningNotificationContent {
  return {
    title: `${warning.type}${warning.level} 해제`,
    body: `${regionName}의 ${warning.type}${warning.level}가 해제됐어요`,
  };
}

function activeWarningFact(
  warning: OfficialWeatherWarning,
  regionName: string,
): string {
  return `${regionName}에는 ${warning.type}${warning.level}가 발효 중이에요`;
}
