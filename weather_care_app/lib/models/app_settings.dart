class AppSettings {
  final String installationId;
  final String locationMode;
  final String? currentRegionId;
  final String? manualRegionKey;
  final bool onboardingCompleted;
  final bool notificationEnabled;
  final String notificationTime;
  final bool umbrellaEnabled;
  final bool parasolEnabled;
  final bool heavyRainEnabled;
  final bool heavySnowEnabled;
  final bool heatwaveEnabled;
  final bool coldWaveEnabled;
  final bool showerAndLightRainEnabled;
  final bool outerwearEnabled;
  final bool maskEnabled;
  final bool waterEnabled;
  final bool sunscreenEnabled;
  final bool dailyWeatherEnabled;

  AppSettings({
    required this.installationId,
    required this.locationMode,
    this.currentRegionId,
    this.manualRegionKey,
    required this.onboardingCompleted,
    required this.notificationEnabled,
    required this.notificationTime,
    required this.umbrellaEnabled,
    required this.parasolEnabled,
    required this.heavyRainEnabled,
    required this.heavySnowEnabled,
    required this.heatwaveEnabled,
    required this.coldWaveEnabled,
    required this.showerAndLightRainEnabled,
    required this.outerwearEnabled,
    required this.maskEnabled,
    required this.waterEnabled,
    required this.sunscreenEnabled,
    required this.dailyWeatherEnabled,
  });

  AppSettings copyWith({
    String? locationMode,
    String? currentRegionId,
    String? manualRegionKey,
    bool clearManualRegionKey = false,
    bool? onboardingCompleted,
    bool? notificationEnabled,
    String? notificationTime,
    bool? umbrellaEnabled,
    bool? parasolEnabled,
    bool? heavyRainEnabled,
    bool? heavySnowEnabled,
    bool? heatwaveEnabled,
    bool? coldWaveEnabled,
    bool? showerAndLightRainEnabled,
    bool? outerwearEnabled,
    bool? maskEnabled,
    bool? waterEnabled,
    bool? sunscreenEnabled,
    bool? dailyWeatherEnabled,
  }) {
    return AppSettings(
      installationId: installationId,
      locationMode: locationMode ?? this.locationMode,
      currentRegionId: currentRegionId ?? this.currentRegionId,
      manualRegionKey:
          clearManualRegionKey ? null : manualRegionKey ?? this.manualRegionKey,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      notificationTime: notificationTime ?? this.notificationTime,
      umbrellaEnabled: umbrellaEnabled ?? this.umbrellaEnabled,
      parasolEnabled: parasolEnabled ?? this.parasolEnabled,
      heavyRainEnabled: heavyRainEnabled ?? this.heavyRainEnabled,
      heavySnowEnabled: heavySnowEnabled ?? this.heavySnowEnabled,
      heatwaveEnabled: heatwaveEnabled ?? this.heatwaveEnabled,
      coldWaveEnabled: coldWaveEnabled ?? this.coldWaveEnabled,
      showerAndLightRainEnabled:
          showerAndLightRainEnabled ?? this.showerAndLightRainEnabled,
      outerwearEnabled: outerwearEnabled ?? this.outerwearEnabled,
      maskEnabled: maskEnabled ?? this.maskEnabled,
      waterEnabled: waterEnabled ?? this.waterEnabled,
      sunscreenEnabled: sunscreenEnabled ?? this.sunscreenEnabled,
      dailyWeatherEnabled: dailyWeatherEnabled ?? this.dailyWeatherEnabled,
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
    return AppSettings(
      installationId: installationId,
      locationMode:
          json['locationMode'] as String? ?? fallbackSettings.locationMode,
      currentRegionId:
          json['currentRegion'] as String? ?? fallbackSettings.currentRegionId,
      manualRegionKey: json['manualRegionKey'] is String
          ? json['manualRegionKey'] as String
          : null,
      onboardingCompleted: json['onboardingCompleted'] as bool? ??
          fallbackSettings.onboardingCompleted,
      notificationEnabled: json['notificationEnabled'] as bool? ??
          fallbackSettings.notificationEnabled,
      notificationTime: json['notificationTime'] as String? ??
          fallbackSettings.notificationTime,
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
      showerAndLightRainEnabled: json['showerAndLightRainEnabled'] as bool? ??
          fallbackSettings.showerAndLightRainEnabled,
      outerwearEnabled: json['outerwearEnabled'] as bool? ??
          fallbackSettings.outerwearEnabled,
      maskEnabled: json['maskEnabled'] as bool? ?? fallbackSettings.maskEnabled,
      waterEnabled:
          json['waterEnabled'] as bool? ?? fallbackSettings.waterEnabled,
      sunscreenEnabled: json['sunscreenEnabled'] as bool? ??
          fallbackSettings.sunscreenEnabled,
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
      'onboardingCompleted': onboardingCompleted,
      'notificationEnabled': notificationEnabled,
      'notificationTime': notificationTime,
      'umbrellaEnabled': umbrellaEnabled,
      'parasolEnabled': parasolEnabled,
      'heavyRainEnabled': heavyRainEnabled,
      'heavySnowEnabled': heavySnowEnabled,
      'heatwaveEnabled': heatwaveEnabled,
      'coldWaveEnabled': coldWaveEnabled,
      'showerAndLightRainEnabled': showerAndLightRainEnabled,
      'outerwearEnabled': outerwearEnabled,
      'maskEnabled': maskEnabled,
      'waterEnabled': waterEnabled,
      'sunscreenEnabled': sunscreenEnabled,
      'dailyWeatherEnabled': dailyWeatherEnabled,
    };
  }
}
