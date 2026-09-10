import { RecommendationType } from '../types';

export type NotificationTarget = 'MAIN' | 'WEATHER_DETAILS';

export type NotificationTopic =
  | 'OVERVIEW'
  | 'STRONG_WIND'
  | 'ROAD_ICE'
  | 'UV'
  | 'PRECIPITATION'
  | 'LAUNDRY'
  | 'PET_WALK'
  | 'COMMUTE'
  | 'SLEEP'
  | 'SNOW'
  | 'AIR_QUALITY'
  | 'TEMPERATURE'
  | 'HEAT'
  | 'WEATHER_WARNING';

export interface NotificationDestination {
  target: NotificationTarget;
  topic: NotificationTopic;
}

export const morningBriefDestination: NotificationDestination = {
  target: 'MAIN',
  topic: 'OVERVIEW',
};

export function weatherDetailsDestination(
  topic: NotificationTopic,
): NotificationDestination {
  return { target: 'WEATHER_DETAILS', topic };
}

export function recommendationDestination(
  type: RecommendationType,
): NotificationDestination {
  switch (type) {
    case 'UMBRELLA':
      return weatherDetailsDestination('PRECIPITATION');
    case 'PARASOL':
    case 'SUNSCREEN':
      return weatherDetailsDestination('UV');
    case 'HEAVY_SNOW_CAUTION':
      return weatherDetailsDestination('SNOW');
    case 'OUTERWEAR':
      return weatherDetailsDestination('TEMPERATURE');
    case 'MASK':
      return weatherDetailsDestination('AIR_QUALITY');
    case 'WATER':
      return weatherDetailsDestination('HEAT');
  }
}

export function warningDestination(
  typeCode: string,
): NotificationDestination {
  switch (typeCode) {
    case 'W':
      return weatherDetailsDestination('STRONG_WIND');
    case 'R':
      return weatherDetailsDestination('PRECIPITATION');
    case 'C':
      return weatherDetailsDestination('TEMPERATURE');
    case 'S':
      return weatherDetailsDestination('SNOW');
    case 'Y':
      return weatherDetailsDestination('AIR_QUALITY');
    case 'H':
      return weatherDetailsDestination('HEAT');
    case 'F':
      return weatherDetailsDestination('COMMUTE');
    case 'K':
      return weatherDetailsDestination('SLEEP');
    case 'D':
    case 'O':
    case 'N':
    case 'V':
    case 'T':
      return weatherDetailsDestination('WEATHER_WARNING');
    default:
      return weatherDetailsDestination('WEATHER_WARNING');
  }
}
