import '../../../models/lifestyle_message.dart';
import '../../../models/recommendation.dart';
import '../../../services/notification_destination.dart';

enum DetailFocusSource {
  notification,
  selection,
}

Set<LifestyleMessageType> lifestyleTypesForNotificationTopic(
  NotificationTopic? topic,
) =>
    switch (topic) {
      NotificationTopic.strongWind => const {
          LifestyleMessageType.outdoorCaution,
        },
      NotificationTopic.pipeFreeze => const {
          LifestyleMessageType.pipeFreezeGuidance,
        },
      NotificationTopic.roadIce => const {
          LifestyleMessageType.blackIceCaution,
          LifestyleMessageType.wetRoadCaution,
        },
      NotificationTopic.uv => const {
          LifestyleMessageType.strongSunExposure,
          LifestyleMessageType.sunscreenUseful,
        },
      NotificationTopic.precipitation => const {
          LifestyleMessageType.rainGearUseful,
          LifestyleMessageType.rainBreakWindow,
          LifestyleMessageType.wetRoadCaution,
          LifestyleMessageType.windowCloseSoon,
        },
      NotificationTopic.laundry => const {
          LifestyleMessageType.laundryPickupDue,
        },
      NotificationTopic.petWalk => const {
          LifestyleMessageType.petWalkWindow,
          LifestyleMessageType.bestOutingWindow,
        },
      NotificationTopic.commute => const {
          LifestyleMessageType.commuteRouteCaution,
          LifestyleMessageType.wetRoadCaution,
          LifestyleMessageType.snowTravelCaution,
        },
      NotificationTopic.sleep => const {
          LifestyleMessageType.nightWeatherCheck,
          LifestyleMessageType.veryHotAndHumid,
        },
      NotificationTopic.snow => const {
          LifestyleMessageType.snowTravelCaution,
        },
      NotificationTopic.airQuality => const {
          LifestyleMessageType.maskUseful,
          LifestyleMessageType.ozoneCaution,
        },
      NotificationTopic.temperature => const {
          LifestyleMessageType.outerwearUseful,
          LifestyleMessageType.coolerThanTemperature,
          LifestyleMessageType.largeTemperatureSwing,
          LifestyleMessageType.rapidTemperatureDrop,
        },
      NotificationTopic.heat => const {
          LifestyleMessageType.hydrationImportant,
          LifestyleMessageType.veryHotAndHumid,
        },
      NotificationTopic.overview ||
      NotificationTopic.lightning ||
      NotificationTopic.weatherWarning ||
      NotificationTopic.unknown ||
      NotificationTopic.appUpdate ||
      null =>
        const {},
    };

Set<LifestyleMessageType> detailLifestyleTypesForRecommendationType(
  RecommendationType type,
) =>
    switch (type) {
      RecommendationType.parasol ||
      RecommendationType.sunHat ||
      RecommendationType.sunscreen ||
      RecommendationType.sunglasses =>
        const {
          LifestyleMessageType.strongSunExposure,
          LifestyleMessageType.sunscreenUseful,
        },
      RecommendationType.water ||
      RecommendationType.portableFan ||
      RecommendationType.coolingItem =>
        const {
          LifestyleMessageType.hydrationImportant,
          LifestyleMessageType.veryHotAndHumid,
        },
      RecommendationType.outerwear ||
      RecommendationType.lightOuterwear ||
      RecommendationType.scarf ||
      RecommendationType.handWarmer =>
        const {
          LifestyleMessageType.outerwearUseful,
          LifestyleMessageType.coolerThanTemperature,
          LifestyleMessageType.largeTemperatureSwing,
          LifestyleMessageType.rapidTemperatureDrop,
        },
      RecommendationType.slipResistantShoes => const {
          LifestyleMessageType.snowTravelCaution,
          LifestyleMessageType.wetRoadCaution,
          LifestyleMessageType.blackIceCaution,
        },
      _ => {detailLifestyleTypeForRecommendationType(type)},
    };

LifestyleMessageType detailLifestyleTypeForRecommendationType(
  RecommendationType type,
) =>
    switch (type) {
      RecommendationType.umbrella => LifestyleMessageType.rainGearUseful,
      RecommendationType.raincoat => LifestyleMessageType.rainGearUseful,
      RecommendationType.rainBoots => LifestyleMessageType.rainGearUseful,
      RecommendationType.slipResistantShoes =>
        LifestyleMessageType.snowTravelCaution,
      RecommendationType.parasol => LifestyleMessageType.strongSunExposure,
      RecommendationType.sunHat => LifestyleMessageType.strongSunExposure,
      RecommendationType.sunscreen => LifestyleMessageType.sunscreenUseful,
      RecommendationType.sunglasses => LifestyleMessageType.strongSunExposure,
      RecommendationType.water => LifestyleMessageType.hydrationImportant,
      RecommendationType.portableFan => LifestyleMessageType.hydrationImportant,
      RecommendationType.coolingItem => LifestyleMessageType.hydrationImportant,
      RecommendationType.outerwear => LifestyleMessageType.outerwearUseful,
      RecommendationType.lightOuterwear => LifestyleMessageType.outerwearUseful,
      RecommendationType.scarf => LifestyleMessageType.outerwearUseful,
      RecommendationType.handWarmer => LifestyleMessageType.outerwearUseful,
      RecommendationType.snowChains => LifestyleMessageType.snowTravelCaution,
      RecommendationType.powerBank => LifestyleMessageType.snowTravelCaution,
      RecommendationType.winterBoots => LifestyleMessageType.snowTravelCaution,
      RecommendationType.heavySnowCaution =>
        LifestyleMessageType.snowTravelCaution,
      RecommendationType.mask => LifestyleMessageType.maskUseful,
    };
