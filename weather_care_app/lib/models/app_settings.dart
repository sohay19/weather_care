class AppSettings {
  final String installationId;
  final String locationMode;
  final String? currentRegionId;
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

  Map<String, dynamic> toJson() {
    return {
      'installationId': installationId,
      'locationMode': locationMode,
      'currentRegion': currentRegionId,
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
