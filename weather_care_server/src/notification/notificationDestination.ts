import { RecommendationType } from '../types';

export type NotificationTarget = 'MAIN' | 'WEATHER_DETAILS' | 'STORE_UPDATE';

export type NotificationTopic =
  | 'APP_UPDATE'
  | 'OVERVIEW'
  | 'STRONG_WIND'
  | 'ROAD_ICE'
  | 'LIGHTNING'
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
    case 'RAINCOAT':
    case 'RAIN_BOOTS':
      return weatherDetailsDestination('PRECIPITATION');
    case 'PARASOL':
    case 'SUN_HAT':
    case 'SUNSCREEN':
    case 'SUNGLASSES':
      return weatherDetailsDestination('UV');
    case 'HEAVY_SNOW_CAUTION':
    case 'SNOW_CHAINS':
    case 'POWER_BANK':
    case 'WINTER_BOOTS':
    case 'SLIP_RESISTANT_SHOES':
      return weatherDetailsDestination('SNOW');
    case 'OUTERWEAR':
    case 'LIGHT_OUTERWEAR':
    case 'SCARF':
    case 'HAND_WARMER':
      return weatherDetailsDestination('TEMPERATURE');
    case 'MASK':
      return weatherDetailsDestination('AIR_QUALITY');
    case 'WATER':
    case 'PORTABLE_FAN':
    case 'COOLING_ITEM':
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
