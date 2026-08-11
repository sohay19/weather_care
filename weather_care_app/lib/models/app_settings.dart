class AppSettings {
  final String installationId;
  final String locationMode;
  final String? currentRegionId;
  final bool onboardingCompleted;
  final bool notificationEnabled;
  final String notificationTime;
  final bool umbrellaEnabled;
  final bool parasolEnabled;
  final bool heavySnowEnabled;
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
    required this.heavySnowEnabled,
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
    bool? heavySnowEnabled,
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
      heavySnowEnabled: heavySnowEnabled ?? this.heavySnowEnabled,
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
      heavySnowEnabled: true,
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
      'heavySnowEnabled': heavySnowEnabled,
      'outerwearEnabled': outerwearEnabled,
      'maskEnabled': maskEnabled,
      'waterEnabled': waterEnabled,
      'sunscreenEnabled': sunscreenEnabled,
      'dailyWeatherEnabled': dailyWeatherEnabled,
    };
  }
}

