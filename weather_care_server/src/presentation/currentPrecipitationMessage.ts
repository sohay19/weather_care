import {
  CurrentPrecipitationObservation,
  LifestyleInsightType,
  TodayWeatherResponse,
} from '../types';

export function buildCurrentPrecipitationMessage(
  observation: CurrentPrecipitationObservation | undefined,
  umbrellaEnabled = true,
): TodayWeatherResponse['lifestyleMessages'][number] | undefined {
  if (!observation || observation.state !== 'RAIN' || !umbrellaEnabled) {
    return undefined;
  }
  const possibility = `${formatHour(observation.observedAt)}에는 비가 내리고 있을 수 있어요`;
  const action =
    '비가 내리고 있을 수 있어요.\n지금 외출한다면 우산을 챙기세요';

  return {
    type: LifestyleInsightType.RAIN_GEAR_USEFUL,
    title: action,
    description: possibility,
    priority: 100,
    parts: [
      {
        role: 'APP_SUGGESTION',
        text: action,
        source: '날씨챙겨',
        validFrom: observation.observedAt,
      },
      {
        role: 'INTERNAL_POSSIBILITY',
        text: possibility,
        source: '기상청 관측분석자료·기상청 레이더',
        validFrom: observation.observedAt,
      },
    ],
  };
}

function formatHour(iso: string): string {
  const hour = Number(iso.slice(11, 13));
  const minute = Number(iso.slice(14, 16));
  const period = hour < 12 ? '오전' : '오후';
  const hour12 = hour % 12 || 12;
  return `${period} ${hour12}시${minute === 0 ? '' : ` ${minute}분`}`;
}
