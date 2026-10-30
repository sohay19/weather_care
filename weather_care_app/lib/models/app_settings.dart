class AppSettings {
  final String installationId;
  final String locationMode;
  final String? currentRegionId;
  final String? manualRegionKey;
  final List<String> savedRegionKeys;
  final List<String>? notificationRegionKeys;
  final String? manualRegionName;
  final bool legacyNotificationRegionAvailable;

  List<String> get enabledNotificationRegionKeys =>
      notificationRegionKeys ??
      [
        if (locationMode == 'GPS')
          'GPS'
        else if (manualRegionKey != null)
          manualRegionKey!
        else if (currentRegionId != null)
          'LEGACY'
      ];
  final bool onboardingCompleted;
  final bool notificationEnabled;
  final bool backgroundLocationEnabled;
  final String notificationTime;
  final String commuteToWorkStart;
  final String commuteToWorkEnd;
  final String commuteFromWorkStart;
  final String commuteFromWorkEnd;
  final bool umbrellaEnabled;
  final bool parasolEnabled;
  final bool heavyRainEnabled;
  final bool heavySnowEnabled;
  final bool heatwaveEnabled;
  final bool coldWaveEnabled;
  final bool pipeFreezeEnabled;
  final bool showerAndLightRainEnabled;
  final bool lightningEnabled;
  final bool outerwearEnabled;
  final bool maskEnabled;
  final bool waterEnabled;
  final bool sunscreenEnabled;
  final bool drynessEnabled;
  final bool todayVisibilityEnabled;
  final bool todayOzoneEnabled;
  final bool todayWindEnabled;
  final bool todayHumidityEnabled;
  final bool todayApparentTemperatureEnabled;
  final bool snowPreparationEnabled;
  final bool uvPreparationEnabled;
  final bool pollenEnabled;
  final bool blackIceEnabled;
  final bool carryNotificationEnabled;
  final bool todayNotificationEnabled;
  final bool weatherNotificationEnabled;
  final bool dailyWeatherEnabled;

  AppSettings({
    required this.installationId,
    required this.locationMode,
    this.currentRegionId,
    this.manualRegionKey,
    this.savedRegionKeys = const [],
    this.notificationRegionKeys,
    this.manualRegionName,
    this.legacyNotificationRegionAvailable = false,
    required this.onboardingCompleted,
    required this.notificationEnabled,
    this.backgroundLocationEnabled = false,
    required this.notificationTime,
    this.commuteToWorkStart = '07:00',
    this.commuteToWorkEnd = '10:00',
    this.commuteFromWorkStart = '17:00',
    this.commuteFromWorkEnd = '20:00',
    required this.umbrellaEnabled,
    required this.parasolEnabled,
    required this.heavyRainEnabled,
    required this.heavySnowEnabled,
    required this.heatwaveEnabled,
    required this.coldWaveEnabled,
    this.pipeFreezeEnabled = true,
    required this.showerAndLightRainEnabled,
    this.lightningEnabled = true,
    required this.outerwearEnabled,
    required this.maskEnabled,
    required this.waterEnabled,
    required this.sunscreenEnabled,
    this.drynessEnabled = true,
    this.todayVisibilityEnabled = true,
    this.todayOzoneEnabled = true,
    this.todayWindEnabled = true,
    this.todayHumidityEnabled = true,
    this.todayApparentTemperatureEnabled = true,
    bool? snowPreparationEnabled,
    bool? uvPreparationEnabled,
    bool? pollenEnabled,
    bool? blackIceEnabled,
    bool? carryNotificationEnabled,
    bool? todayNotificationEnabled,
    this.weatherNotificationEnabled = true,
    required this.dailyWeatherEnabled,
  })  : carryNotificationEnabled =
            dailyWeatherEnabled && (carryNotificationEnabled ?? true),
        todayNotificationEnabled =
            dailyWeatherEnabled && (todayNotificationEnabled ?? true),
        snowPreparationEnabled = snowPreparationEnabled ?? (heavySnowEnabled),
        uvPreparationEnabled =
            uvPreparationEnabled ?? (parasolEnabled || sunscreenEnabled),
        pollenEnabled = pollenEnabled ?? (maskEnabled),
        blackIceEnabled = blackIceEnabled ?? (true);

  AppSettings copyWith({
    String? locationMode,
    String? currentRegionId,
    String? manualRegionKey,
    List<String>? savedRegionKeys,
    List<String>? notificationRegionKeys,
    String? manualRegionName,
    bool? legacyNotificationRegionAvailable,
    bool clearManualRegionKey = false,
    bool? onboardingCompleted,
    bool? notificationEnabled,
    bool? backgroundLocationEnabled,
    String? notificationTime,
    String? commuteToWorkStart,
    String? commuteToWorkEnd,
    String? commuteFromWorkStart,
    String? commuteFromWorkEnd,
    bool? umbrellaEnabled,
    bool? parasolEnabled,
    bool? heavyRainEnabled,
    bool? heavySnowEnabled,
    bool? heatwaveEnabled,
    bool? coldWaveEnabled,
    bool? pipeFreezeEnabled,
    bool? showerAndLightRainEnabled,
    bool? lightningEnabled,
    bool? outerwearEnabled,
    bool? maskEnabled,
    bool? waterEnabled,
    bool? sunscreenEnabled,
    bool? drynessEnabled,
    bool? todayVisibilityEnabled,
    bool? todayOzoneEnabled,
    bool? todayWindEnabled,
    bool? todayHumidityEnabled,
    bool? todayApparentTemperatureEnabled,
    bool? snowPreparationEnabled,
    bool? uvPreparationEnabled,
    bool? pollenEnabled,
    bool? blackIceEnabled,
    bool? carryNotificationEnabled,
    bool? todayNotificationEnabled,
    bool? weatherNotificationEnabled,
    bool? dailyWeatherEnabled,
  }) {
    final carry = carryNotificationEnabled ??
        dailyWeatherEnabled ??
        this.carryNotificationEnabled;
    final today = todayNotificationEnabled ??
        dailyWeatherEnabled ??
        this.todayNotificationEnabled;
    final split =
        carryNotificationEnabled != null || todayNotificationEnabled != null;
    return AppSettings(
      installationId: installationId,
      locationMode: locationMode ?? this.locationMode,
      currentRegionId: currentRegionId ?? this.currentRegionId,
      manualRegionKey:
          clearManualRegionKey ? null : manualRegionKey ?? this.manualRegionKey,
      savedRegionKeys: savedRegionKeys ?? this.savedRegionKeys,
      notificationRegionKeys:
          notificationRegionKeys ?? this.notificationRegionKeys,
      manualRegionName: manualRegionName ?? this.manualRegionName,
      legacyNotificationRegionAvailable: legacyNotificationRegionAvailable ??
          this.legacyNotificationRegionAvailable,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      backgroundLocationEnabled:
          backgroundLocationEnabled ?? this.backgroundLocationEnabled,
      notificationTime: notificationTime ?? this.notificationTime,
      commuteToWorkStart: commuteToWorkStart ?? this.commuteToWorkStart,
      commuteToWorkEnd: commuteToWorkEnd ?? this.commuteToWorkEnd,
      commuteFromWorkStart: commuteFromWorkStart ?? this.commuteFromWorkStart,
      commuteFromWorkEnd: commuteFromWorkEnd ?? this.commuteFromWorkEnd,
      umbrellaEnabled: umbrellaEnabled ?? this.umbrellaEnabled,
      parasolEnabled: parasolEnabled ?? this.parasolEnabled,
      heavyRainEnabled: heavyRainEnabled ?? this.heavyRainEnabled,
      heavySnowEnabled: heavySnowEnabled ?? this.heavySnowEnabled,
      heatwaveEnabled: heatwaveEnabled ?? this.heatwaveEnabled,
      coldWaveEnabled: coldWaveEnabled ?? this.coldWaveEnabled,
      pipeFreezeEnabled: pipeFreezeEnabled ?? this.pipeFreezeEnabled,
      showerAndLightRainEnabled:
          showerAndLightRainEnabled ?? this.showerAndLightRainEnabled,
      lightningEnabled: lightningEnabled ?? this.lightningEnabled,
      outerwearEnabled: outerwearEnabled ?? this.outerwearEnabled,
      maskEnabled: maskEnabled ?? this.maskEnabled,
      waterEnabled: waterEnabled ?? this.waterEnabled,
      sunscreenEnabled: sunscreenEnabled ?? this.sunscreenEnabled,
      drynessEnabled: drynessEnabled ?? this.drynessEnabled,
      todayVisibilityEnabled:
          todayVisibilityEnabled ?? this.todayVisibilityEnabled,
      todayOzoneEnabled: todayOzoneEnabled ?? this.todayOzoneEnabled,
      todayWindEnabled: todayWindEnabled ?? this.todayWindEnabled,
      todayHumidityEnabled: todayHumidityEnabled ?? this.todayHumidityEnabled,
      todayApparentTemperatureEnabled: todayApparentTemperatureEnabled ??
          this.todayApparentTemperatureEnabled,
      snowPreparationEnabled:
          snowPreparationEnabled ?? this.snowPreparationEnabled,
      uvPreparationEnabled: uvPreparationEnabled ?? this.uvPreparationEnabled,
      pollenEnabled: pollenEnabled ?? this.pollenEnabled,
      blackIceEnabled: blackIceEnabled ?? this.blackIceEnabled,
      weatherNotificationEnabled:
          weatherNotificationEnabled ?? this.weatherNotificationEnabled,
      carryNotificationEnabled: carry,
      todayNotificationEnabled: today,
      dailyWeatherEnabled: split
          ? carry || today
          : dailyWeatherEnabled ?? this.dailyWeatherEnabled,
    );
  }

  static AppSettings fallback(String installationId) {
    return AppSettings(
      installationId: installationId,
      locationMode: 'GPS',
      onboardingCompleted: false,
      notificationEnabled: true,
      notificationTime: '07:00',
      umbrellaEnabled: true,
      parasolEnabled: true,
      heavyRainEnabled: true,
      heavySnowEnabled: true,
      heatwaveEnabled: true,
      coldWaveEnabled: true,
      showerAndLightRainEnabled: true,
      outerwearEnabled: true,
      maskEnabled: true,
      waterEnabled: true,
      sunscreenEnabled: true,
      dailyWeatherEnabled: true,
    );
  }

  factory AppSettings.fromJson(
    Map<String, dynamic> json,
    String installationId,
  ) {
    final fallbackSettings = AppSettings.fallback(installationId);
    final rawSavedRegions = json['savedRegionKeys'];
    final savedRegionKeys = rawSavedRegions is List
        ? rawSavedRegions.whereType<String>().toList()
        : <String>[];
    final manualRegionKey = json['manualRegionKey'];
    if (manualRegionKey is String &&
        !savedRegionKeys.contains(manualRegionKey)) {
      savedRegionKeys.add(manualRegionKey);
    }
    return AppSettings(
      installationId: installationId,
      locationMode:
          json['locationMode'] as String? ?? fallbackSettings.locationMode,
      currentRegionId:
          json['currentRegion'] as String? ?? fallbackSettings.currentRegionId,
      manualRegionKey: manualRegionKey is String ? manualRegionKey : null,
      savedRegionKeys: savedRegionKeys,
      notificationRegionKeys: json['notificationRegionKeys'] is List
          ? (json['notificationRegionKeys'] as List)
              .whereType<String>()
              .toSet()
              .toList()
          : null,
      manualRegionName: json['manualRegionName'] as String?,
      legacyNotificationRegionAvailable:
          json['legacyNotificationRegionAvailable'] == true ||
              (json['notificationRegionKeys'] == null &&
                  json['locationMode'] == 'MANUAL' &&
                  manualRegionKey == null &&
                  json['currentRegion'] != null),
      onboardingCompleted: json['onboardingCompleted'] as bool? ??
          fallbackSettings.onboardingCompleted,
      notificationEnabled: json['notificationEnabled'] as bool? ??
          fallbackSettings.notificationEnabled,
      backgroundLocationEnabled: json['backgroundLocationEnabled'] == true,
      notificationTime: json['notificationTime'] as String? ??
          fallbackSettings.notificationTime,
      commuteToWorkStart: json['commuteToWorkStart'] as String? ?? '07:00',
      commuteToWorkEnd: json['commuteToWorkEnd'] as String? ?? '10:00',
      commuteFromWorkStart: json['commuteFromWorkStart'] as String? ?? '17:00',
      commuteFromWorkEnd: json['commuteFromWorkEnd'] as String? ?? '20:00',
      umbrellaEnabled:
          json['umbrellaEnabled'] as bool? ?? fallbackSettings.umbrellaEnabled,
      parasolEnabled:
          json['parasolEnabled'] as bool? ?? fallbackSettings.parasolEnabled,
      heavyRainEnabled: json['heavyRainEnabled'] as bool? ??
          fallbackSettings.heavyRainEnabled,
      heavySnowEnabled: json['heavySnowEnabled'] as bool? ??
          fallbackSettings.heavySnowEnabled,
      heatwaveEnabled:
          json['heatwaveEnabled'] as bool? ?? fallbackSettings.heatwaveEnabled,
      coldWaveEnabled:
          json['coldWaveEnabled'] as bool? ?? fallbackSettings.coldWaveEnabled,
      pipeFreezeEnabled: json['pipeFreezeEnabled'] as bool? ?? true,
      showerAndLightRainEnabled: json['showerAndLightRainEnabled'] as bool? ??
          fallbackSettings.showerAndLightRainEnabled,
      lightningEnabled: json['lightningEnabled'] as bool? ?? true,
      outerwearEnabled: json['outerwearEnabled'] as bool? ??
          fallbackSettings.outerwearEnabled,
      maskEnabled: json['maskEnabled'] as bool? ?? fallbackSettings.maskEnabled,
      waterEnabled:
          json['waterEnabled'] as bool? ?? fallbackSettings.waterEnabled,
      drynessEnabled:
          json['drynessEnabled'] as bool? ?? fallbackSettings.drynessEnabled,
      sunscreenEnabled: json['sunscreenEnabled'] as bool? ??
          fallbackSettings.sunscreenEnabled,
      todayVisibilityEnabled: json['todayVisibilityEnabled'] as bool? ?? true,
      todayOzoneEnabled: json['todayOzoneEnabled'] as bool? ?? true,
      todayWindEnabled: json['todayWindEnabled'] as bool? ?? true,
      todayHumidityEnabled: json['todayHumidityEnabled'] as bool? ?? true,
      todayApparentTemperatureEnabled:
          json['todayApparentTemperatureEnabled'] as bool? ?? true,
      snowPreparationEnabled: json['snowPreparationEnabled'] as bool? ??
          ((json['heavySnowEnabled'] as bool? ?? true)),
      uvPreparationEnabled: json['uvPreparationEnabled'] as bool? ??
          ((json['parasolEnabled'] as bool? ?? true) ||
              (json['sunscreenEnabled'] as bool? ?? true)),
      pollenEnabled: json['pollenEnabled'] as bool? ??
          ((json['maskEnabled'] as bool? ?? true)),
      blackIceEnabled: json['blackIceEnabled'] as bool? ?? (true),
      carryNotificationEnabled: json['carryNotificationEnabled'] as bool?,
      todayNotificationEnabled: json['todayNotificationEnabled'] as bool?,
      weatherNotificationEnabled:
          json['weatherNotificationEnabled'] as bool? ?? true,
      dailyWeatherEnabled: json['dailyWeatherEnabled'] as bool? ??
          fallbackSettings.dailyWeatherEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'installationId': installationId,
      'locationMode': locationMode,
      'currentRegion': currentRegionId,
      'manualRegionKey': manualRegionKey,
      'savedRegionKeys': savedRegionKeys,
      if (notificationRegionKeys != null)
        'notificationRegionKeys': notificationRegionKeys,
      if (manualRegionName != null) 'manualRegionName': manualRegionName,
      if (legacyNotificationRegionAvailable)
        'legacyNotificationRegionAvailable': true,
      'onboardingCompleted': onboardingCompleted,
      'notificationEnabled': notificationEnabled,
      'backgroundLocationEnabled': backgroundLocationEnabled,
      'notificationTime': notificationTime,
      'commuteToWorkStart': commuteToWorkStart,
      'commuteToWorkEnd': commuteToWorkEnd,
      'commuteFromWorkStart': commuteFromWorkStart,
      'commuteFromWorkEnd': commuteFromWorkEnd,
      'umbrellaEnabled': umbrellaEnabled,
      'parasolEnabled': parasolEnabled,
      'heavyRainEnabled': heavyRainEnabled,
      'heavySnowEnabled': heavySnowEnabled,
      'heatwaveEnabled': heatwaveEnabled,
      'coldWaveEnabled': coldWaveEnabled,
      'pipeFreezeEnabled': pipeFreezeEnabled,
      'showerAndLightRainEnabled': showerAndLightRainEnabled,
      'lightningEnabled': lightningEnabled,
      'outerwearEnabled': outerwearEnabled,
      'maskEnabled': maskEnabled,
      'waterEnabled': waterEnabled,
      'sunscreenEnabled': sunscreenEnabled,
      'drynessEnabled': drynessEnabled,
      'todayVisibilityEnabled': todayVisibilityEnabled,
      'todayOzoneEnabled': todayOzoneEnabled,
      'todayWindEnabled': todayWindEnabled,
      'todayHumidityEnabled': todayHumidityEnabled,
      'todayApparentTemperatureEnabled': todayApparentTemperatureEnabled,
      'snowPreparationEnabled': snowPreparationEnabled,
      'uvPreparationEnabled': uvPreparationEnabled,
      'pollenEnabled': pollenEnabled,
      'blackIceEnabled': blackIceEnabled,
      'carryNotificationEnabled': carryNotificationEnabled,
      'todayNotificationEnabled': todayNotificationEnabled,
      'weatherNotificationEnabled': weatherNotificationEnabled,
      'dailyWeatherEnabled': dailyWeatherEnabled,
    };
  }
}
