import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../models/app_settings.dart';
import '../../services/ad_removal_service.dart';
import '../../services/current_location_service.dart';
import '../../services/region_catalog.dart';
import '../../services/settings_save_controller.dart';
import '../../services/notification_permission_service.dart';
import '../../theme/weather_theme.dart';
import '../home/widgets/tab_page_header.dart';
import 'ad_removal_purchase_screen.dart';
import 'notification_schedule.dart';
import 'notification_time_picker.dart';
import 'settings_time_control.dart';
import 'commute_notification_settings_screen.dart';
import 'region_picker_screen.dart' show RegionMapBuilder;
import 'settings_guide.dart';
import 'settings_guide_screen.dart';
import 'analytics_consent_control.dart';
import 'ads_privacy_control.dart';
import 'background_location_control.dart';
import '../../services/background_location_service.dart';
import '../../services/server_data_access.dart';
import '../../services/theme_mode_settings.dart';

class SettingsScreen extends StatefulWidget {
  final bool embedded;
  final Future<void> Function()? onRefresh;
  final AppSettings? initialSettings;
  final Future<void> Function(AppSettings settings)? onSettingsChanged;
  final LocationResult location;
  final String? regionName;
  final Future<void> Function()? onLocate;
  final Future<void> Function()? onOpenLocationSettings;
  final Future<RegionCatalog> Function()? loadRegionCatalog;
  final String? manualRegionName;
  final SettingsSaveState saveState;
  final Future<void> Function()? onRetrySave;
  final NotificationPermissionState notificationPermission;
  final Future<void> Function()? onRequestNotificationPermission;
  final Future<void> Function()? onRefreshNotificationPermission;
  final Future<void> Function()? onOpenNotificationSettings;
  final ServerDataAccess? serverDataAccess;
  final Future<void> Function()? onDeleteServerData;
  final Future<void> Function()? onResumeServerData;
  final Future<bool> Function(Uri)? openExternalLink;
  final RegionMapBuilder? regionMapBuilder;
  final AdRemovalService? adRemoval;
  final BackgroundLocationService? backgroundLocation;
  final Future<void> Function()? onBackgroundLocationPermission;

  const SettingsScreen({
    super.key,
    this.embedded = false,
    this.onRefresh,
    this.initialSettings,
    this.onSettingsChanged,
    this.location = const LocationResult(LocationState.idle),
    this.regionName,
    this.onLocate,
    this.onOpenLocationSettings,
    this.loadRegionCatalog,
    this.manualRegionName,
    this.saveState = SettingsSaveState.checking,
    this.onRetrySave,
    this.notificationPermission = NotificationPermissionState.checking,
    this.onRequestNotificationPermission,
    this.onRefreshNotificationPermission,
    this.onOpenNotificationSettings,
    this.serverDataAccess,
    this.onDeleteServerData,
    this.onResumeServerData,
    this.openExternalLink,
    this.regionMapBuilder,
    this.adRemoval,
    this.backgroundLocation,
    this.onBackgroundLocationPermission,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings settings;
  late final Future<String?> _appVersion;
  final _statusChanges = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    settings =
        widget.initialSettings ?? AppSettings.fallback('local-installation');
    _appVersion = _loadAppVersion();
    widget.adRemoval?.addListener(_onAdRemovalChanged);
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updated = widget.initialSettings;
    if (updated != null && updated != oldWidget.initialSettings) {
      settings = updated;
    }
    if (oldWidget.adRemoval != widget.adRemoval) {
      oldWidget.adRemoval?.removeListener(_onAdRemovalChanged);
      widget.adRemoval?.addListener(_onAdRemovalChanged);
    }
    if (oldWidget.notificationPermission != widget.notificationPermission ||
        oldWidget.saveState != widget.saveState ||
        oldWidget.initialSettings != widget.initialSettings ||
        oldWidget.serverDataAccess != widget.serverDataAccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _statusChanges.value++;
      });
    }
  }

  void _onAdRemovalChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.adRemoval?.removeListener(_onAdRemovalChanged);
    _statusChanges.dispose();
    super.dispose();
  }

  bool get _alertsEnabled =>
      settings.notificationEnabled &&
      !(widget.serverDataAccess?.paused ?? false);

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      key: widget.embedded ? const ValueKey('setting-tab') : null,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, widget.embedded ? 12 : 4, 16, 32),
      children: [
        if (widget.embedded)
          const TabPageHeader(
            eyebrow: 'SETTING',
            title: '설정',
            subtitle: '필요한 알림과 데이터 사용을 설정할 수 있어요.',
            icon: Icons.tune_rounded,
          )
        else
          Text(
            '필요한 알림과 데이터 사용을 설정할 수 있어요.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: WeatherCareTheme.of(context).textSecondary,
                ),
          ),
        const SizedBox(height: 20),
        _AdRemovalBanner(
          isOwned: widget.adRemoval?.isOwned ?? false,
          onTap: _openAdRemovalPurchase,
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeModeSettings.instance,
          builder: (context, mode, _) => _SettingsMenuButton(
            key: const ValueKey('theme-mode-menu'),
            icon: Icons.brightness_6_outlined,
            title: '테마',
            subtitle: _themeModeLabel(mode),
            onTap: _openThemeModeSettings,
          ),
        ),
        const SizedBox(height: 16),
        _SettingsMenuButton(
          key: const ValueKey('weather-alerts-menu'),
          icon: Icons.notifications_active_outlined,
          title: '알림',
          subtitle: _alertsEnabled ? '시간과 알림 종류를 설정해요' : '알림이 꺼져 있어요',
          onTap: _openWeatherAlertsSettings,
        ),
        const SizedBox(height: 16),
        _SettingsMenuButton(
          key: const ValueKey('notification-status-menu'),
          icon: Icons.sync_rounded,
          title: '데이터 저장·기기 권한 상태',
          subtitle: '데이터 저장과 알림·위치 권한을 확인해요',
          onTap: _openNotificationStatusSettings,
        ),
        const SizedBox(height: 16),
        _SettingsMenuButton(
          key: const ValueKey('data-permission-menu'),
          icon: Icons.info_outline_rounded,
          title: '데이터 권한 안내',
          subtitle: '자료 출처와 위치·알림 정보 사용을 확인해요',
          onTap: _openDataPermissionSettings,
        ),
      ],
    );
    final refreshableBody = RefreshIndicator(
      color: WeatherCareTheme.of(context).primary,
      onRefresh: widget.onRefresh ?? () async {},
      child: body,
    );
    final content = Stack(
      children: [
        Positioned.fill(child: refreshableBody),
        Positioned(
          right: 16,
          bottom: 8,
          child: FutureBuilder<String?>(
            future: _appVersion,
            builder: (context, snapshot) {
              final version = snapshot.data;
              if (version == null) return const SizedBox.shrink();
              return Text(
                '버전 $version',
                key: const ValueKey('settings-app-version'),
                style: WeatherCareTheme.of(context).microTextStyle,
              );
            },
          ),
        ),
      ],
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: content,
    );
  }

  Future<String?> _loadAppVersion() async {
    try {
      final version = (await PackageInfo.fromPlatform()).version.trim();
      return version.isEmpty ? null : version;
    } catch (_) {
      return null;
    }
  }

  void _updateSettings(AppSettings updated) {
    setState(() => settings = updated);
    final callback = widget.onSettingsChanged;
    if (callback != null) {
      unawaited(callback(updated).catchError((Object _) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('설정을 저장하지 못했어요.\n다시 시도해주세요.')));
        }
      }));
    }
  }

  void _openGuide(SettingsGuide guide) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => SettingsGuideScreen(guide: guide),
    ));
  }

  void _openWeatherAlertsSettings() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => _WeatherAlertsSettingsScreen(
        initialSettings: settings,
        paused: widget.serverDataAccess?.paused ?? false,
        onSettingsChanged: _updateSettings,
      ),
    ));
  }

  void _openThemeModeSettings() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const _ThemeModeSettingsScreen(),
    ));
  }

  void _openNotificationStatusSettings() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ValueListenableBuilder<int>(
        valueListenable: _statusChanges,
        builder: (_, __, ___) => _NotificationStatusSettingsScreen(
          alertsEnabled: _alertsEnabled,
          saveState: widget.saveState,
          onRetrySave: widget.onRetrySave,
          notificationPermission: widget.notificationPermission,
          onRequestNotificationPermission:
              widget.onRequestNotificationPermission,
          onRefreshNotificationPermission:
              widget.onRefreshNotificationPermission,
          onOpenNotificationSettings: widget.onOpenNotificationSettings,
          backgroundLocation: widget.backgroundLocation,
          backgroundLocationEnabled: settings.backgroundLocationEnabled,
          backgroundLocationAvailable:
              settings.enabledNotificationRegionKeys.contains('GPS') &&
                  _alertsEnabled,
          onBackgroundLocationChanged: (value) async {
            final updated = settings.copyWith(backgroundLocationEnabled: value);
            setState(() => settings = updated);
            await widget.onSettingsChanged?.call(updated);
          },
          onBackgroundLocationPermission: widget.onBackgroundLocationPermission,
          onOpenGuide: () => _openGuide(SettingsGuide.notifications),
        ),
      ),
    ));
  }

  void _openAdRemovalPurchase() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => AdRemovalPurchaseScreen(
        controller: widget.adRemoval,
      ),
    ));
  }

  void _openDataPermissionSettings() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => _DataPermissionSettingsScreen(
        serverDataAccess: widget.serverDataAccess,
        onDeleteServerData: widget.onDeleteServerData,
        onResumeServerData: widget.onResumeServerData,
        onOpenGuide: _openGuide,
      ),
    ));
  }
}

class _WeatherAlertsSettingsScreen extends StatefulWidget {
  final AppSettings initialSettings;
  final bool paused;
  final ValueChanged<AppSettings> onSettingsChanged;

  const _WeatherAlertsSettingsScreen({
    required this.initialSettings,
    required this.paused,
    required this.onSettingsChanged,
  });

  @override
  State<_WeatherAlertsSettingsScreen> createState() =>
      _WeatherAlertsSettingsScreenState();
}

class _WeatherAlertsSettingsScreenState
    extends State<_WeatherAlertsSettingsScreen> {
  late AppSettings settings;

  @override
  void initState() {
    super.initState();
    settings = widget.initialSettings;
  }

  void _update(AppSettings updated) {
    setState(() => settings = updated);
    widget.onSettingsChanged(updated);
  }

  Future<void> _selectTime() async {
    if (!settings.notificationEnabled || widget.paused) return;
    final pieces = settings.notificationTime.split(':');
    final selected = await showNotificationTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(pieces.first) ?? 7,
        minute: int.tryParse(pieces.length > 1 ? pieces[1] : '') ?? 0,
      ),
      title: '알림 시간 선택',
    );
    if (selected == null || !mounted) return;
    final time =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    _update(settings.copyWith(notificationTime: time));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = settings.notificationEnabled && !widget.paused;
    return _SettingsDetailScaffold(
      title: '알림',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          key: const ValueKey('notification-save-notice'),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: WeatherCareTheme.of(context).surfaceMuted,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: WeatherCareTheme.of(context).textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '저장에 실패하면 데이터 저장·기기 권한 상태에서 다시 시도해주세요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WeatherCareTheme.of(context).textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          key: const ValueKey('weather-alerts-master-section'),
          icon: Icons.cloud,
          title: '날씨 알림',
          subtitle: '모든 날씨 알림의 사용 여부를 설정해요',
          child: _SettingsToggleTile(
            icon: Icons.notifications_active_outlined,
            settingId: 'notificationEnabled',
            title: '사용 여부',
            subtitle: enabled ? '알림이 켜져 있어요' : '알림이 꺼져 있어요',
            value: settings.notificationEnabled,
            enabled: !widget.paused,
            onChanged: (value) =>
                _update(settings.copyWith(notificationEnabled: value)),
          ),
        ),
        if (widget.paused) ...[
          const SizedBox(height: 8),
          const Text('서버 데이터 사용이 중지돼 있어 알림 설정을 변경할 수 없어요.'),
        ],
        const SizedBox(height: 12),
        _SettingsSection(
          key: const ValueKey('notification-time-section'),
          icon: Icons.schedule_outlined,
          title: '알림 시간',
          subtitle: '준비물 요약 알림 시간을 설정해요',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SettingsTimeControl(
              key: const ValueKey('notification-time-control'),
              label: '알림',
              value: settings.notificationTime,
              onTap: enabled ? _selectTime : null,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    notificationScheduleDescription(settings.notificationTime),
                    key: const ValueKey('notification-schedule-description'),
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: WeatherCareTheme.of(context)
                              .textSecondary
                              .withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                  ),
                ),
              ),
            ),
            if (!settings.dailyWeatherEnabled)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('준비물 요약 알림을 켜야 설정한 시간이 적용돼요.'),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          key: const ValueKey('commute-notification-menu'),
          icon: Icons.commute_rounded,
          title: '출퇴근 알림 시간',
          subtitle: '도로통제 알림을 받을 시간대를 설정해요',
          child: CommuteNotificationTimeControls(
            settings: settings,
            enabled: enabled,
            onSettingsChanged: _update,
          ),
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          key: const ValueKey('carry-notification-section'),
          icon: Icons.work_rounded,
          title: '챙겨요 알림',
          subtitle:
              enabled ? '준비물 요약에 포함할 항목을 선택해요' : '날씨 알림을 켜면 항목을 변경할 수 있어요',
          child: Column(children: [
            _SettingsToggleTile(
              icon: Icons.umbrella_outlined,
              settingId: 'umbrellaEnabled',
              title: '우산',
              subtitle: '준비물 요약과 현재 비 안내에 함께 적용돼요',
              value: settings.umbrellaEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(umbrellaEnabled: value)),
            ),
            _SettingsToggleTile(
              icon: Icons.wb_sunny_outlined,
              settingId: 'parasolEnabled',
              title: '양산',
              value: settings.parasolEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(parasolEnabled: value)),
            ),
            _SettingsToggleTile(
              icon: Icons.checkroom_rounded,
              settingId: 'outerwearEnabled',
              title: '겉옷',
              value: settings.outerwearEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(outerwearEnabled: value)),
            ),
            _SettingsToggleTile(
              icon: Icons.face_outlined,
              settingId: 'maskEnabled',
              title: '마스크',
              value: settings.maskEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(maskEnabled: value)),
            ),
            _SettingsToggleTile(
              icon: Icons.local_drink_outlined,
              settingId: 'waterEnabled',
              title: '물',
              value: settings.waterEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(waterEnabled: value)),
            ),
            _SettingsToggleTile(
              icon: Icons.spa_outlined,
              settingId: 'sunscreenEnabled',
              title: '선크림',
              value: settings.sunscreenEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(sunscreenEnabled: value)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          key: const ValueKey('weather-notification-section'),
          icon: Icons.shield,
          title: '기상·생활 알림',
          subtitle: '특보와 현재 날씨 안내를 관리해요',
          child: Column(children: [
            _SettingsToggleTile(
              icon: Icons.bolt_rounded,
              settingId: 'lightningEnabled',
              title: '낙뢰 감지 알림',
              subtitle: '선택 지역의 기상 격자에서 최근 30분 이내 관측된 낙뢰를 안내해요',
              value: settings.lightningEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(lightningEnabled: value)),
            ),
            _SettingsToggleTile(
              icon: Icons.thunderstorm_outlined,
              settingId: 'heavyRainEnabled',
              title: '호우특보 안내',
              subtitle: '발효된 호우특보의 시작·단계 변경·해제를 안내해요',
              value: settings.heavyRainEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(heavyRainEnabled: value)),
            ),
            _SettingsToggleTile(
              icon: Icons.ac_unit_rounded,
              settingId: 'heavySnowEnabled',
              title: '대설·많은 눈 안내',
              subtitle: '발효된 대설특보와 예보 기반 많은 눈 대비를 안내해요',
              value: settings.heavySnowEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(heavySnowEnabled: value)),
            ),
            _SettingsToggleTile(
              icon: Icons.device_thermostat_rounded,
              settingId: 'heatwaveEnabled',
              title: '폭염특보 안내',
              subtitle: '발효된 폭염특보의 시작·단계 변경·해제를 안내해요',
              value: settings.heatwaveEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(heatwaveEnabled: value)),
            ),
            _SettingsToggleTile(
              icon: Icons.severe_cold_outlined,
              settingId: 'coldWaveEnabled',
              title: '한파특보 안내',
              subtitle: '발효된 한파특보의 시작·단계 변경·해제를 안내해요',
              value: settings.coldWaveEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(coldWaveEnabled: value)),
            ),
            _SettingsToggleTile(
              icon: Icons.plumbing_rounded,
              settingId: 'pipeFreezeEnabled',
              title: '수도관 동파 대비 안내',
              subtitle:
                  '향후 48시간 기온 예보로 보온 점검이 필요할 때 하루 한 번 안내해요. 공식 동파 예보가 아닌 앱 참고 안내예요',
              value: settings.pipeFreezeEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(pipeFreezeEnabled: value)),
            ),
            _SettingsToggleTile(
              icon: Icons.water_drop_outlined,
              settingId: 'showerAndLightRainEnabled',
              title: '현재 비 안내',
              subtitle:
                  '관측분석·레이더가 일치한 현재 비를 안내해요.\n우산도 켜야 하며, 저장 지역은 예보 격자 기준으로 확인해요.\n소나기 예보 알림은 아니에요',
              value: settings.showerAndLightRainEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(showerAndLightRainEnabled: value)),
            ),
            _SettingsToggleTile(
              icon: Icons.wb_cloudy_outlined,
              settingId: 'dailyWeatherEnabled',
              title: '준비물 요약 알림',
              subtitle: '추천할 준비물이 있을 때만 설정한 시간에 하루 한 번, 선택한 항목 중 최대 3개를 안내해요',
              value: settings.dailyWeatherEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  _update(settings.copyWith(dailyWeatherEnabled: value)),
            ),
            const Divider(height: 24),
            const Text(
              '블랙아이스(도로살얼음)·도로통제·그 밖의 공식 특보는 개별 스위치 없이 전체 날씨 알림 설정을 따라요.\n도로통제 알림은 설정한 출퇴근 시간 안에서만 보내요.\n블랙아이스·도로통제는 서버에 등록된 정밀 위치와 해당 자료가 있어야 해요.',
              key: ValueKey('additional-notification-contract'),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SettingsDetailScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsDetailScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(key: ValueKey('settings-detail-back')),
        title: Text(title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [child],
        ),
      ),
    );
  }
}

String _themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => '라이트',
      ThemeMode.dark => '다크',
      ThemeMode.system => '시스템 설정에 따름',
    };

class _ThemeModeSettingsScreen extends StatelessWidget {
  const _ThemeModeSettingsScreen();

  Future<void> _selectMode(BuildContext context, ThemeMode mode) async {
    try {
      await ThemeModeSettings.instance.save(mode);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('테마를 저장하지 못했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailScaffold(
      title: '테마',
      child: _SettingsSection(
        icon: Icons.brightness_6_outlined,
        title: '화면 테마',
        subtitle: '앱 화면의 테마를 선택해요',
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeModeSettings.instance,
          builder: (context, selected, _) => RadioGroup<ThemeMode>(
            groupValue: selected,
            onChanged: (value) {
              if (value != null) unawaited(_selectMode(context, value));
            },
            child: Column(
              children: [
                for (final mode in [
                  ThemeMode.light,
                  ThemeMode.dark,
                  ThemeMode.system,
                ])
                  Material(
                    color: Colors.transparent,
                    child: RadioListTile<ThemeMode>(
                      key: ValueKey('theme-mode-${mode.name}'),
                      title: Text(_themeModeLabel(mode)),
                      value: mode,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationStatusSettingsScreen extends StatefulWidget {
  final bool alertsEnabled;
  final SettingsSaveState saveState;
  final Future<void> Function()? onRetrySave;
  final NotificationPermissionState notificationPermission;
  final Future<void> Function()? onRequestNotificationPermission;
  final Future<void> Function()? onRefreshNotificationPermission;
  final Future<void> Function()? onOpenNotificationSettings;
  final VoidCallback onOpenGuide;
  final BackgroundLocationService? backgroundLocation;
  final bool backgroundLocationEnabled;
  final bool backgroundLocationAvailable;
  final Future<void> Function(bool) onBackgroundLocationChanged;
  final Future<void> Function()? onBackgroundLocationPermission;

  const _NotificationStatusSettingsScreen({
    required this.alertsEnabled,
    required this.saveState,
    required this.onRetrySave,
    required this.notificationPermission,
    required this.onRequestNotificationPermission,
    required this.onRefreshNotificationPermission,
    required this.onOpenNotificationSettings,
    required this.onOpenGuide,
    required this.backgroundLocation,
    required this.backgroundLocationEnabled,
    required this.backgroundLocationAvailable,
    required this.onBackgroundLocationChanged,
    required this.onBackgroundLocationPermission,
  });

  @override
  State<_NotificationStatusSettingsScreen> createState() =>
      _NotificationStatusSettingsScreenState();
}

class _NotificationStatusSettingsScreenState
    extends State<_NotificationStatusSettingsScreen> {
  late bool _backgroundLocationEnabled;

  @override
  void initState() {
    super.initState();
    _backgroundLocationEnabled = widget.backgroundLocationEnabled;
  }

  @override
  void didUpdateWidget(covariant _NotificationStatusSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundLocationEnabled !=
        widget.backgroundLocationEnabled) {
      _backgroundLocationEnabled = widget.backgroundLocationEnabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final saveState = widget.saveState;
    final notificationPermission = widget.notificationPermission;
    return _SettingsDetailScaffold(
      title: '데이터 저장·기기 권한 상태',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsSection(
            icon: Icons.save_alt_outlined,
            title: '데이터 상태',
            subtitle: '각종 설정을 저장하고 서버에 반영해요',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(saveState.message,
                      key: const ValueKey('settings-save-status')),
                ),
                const SizedBox(height: 8),
                if (saveState.canRetry) ...[
                  const Divider(height: 24),
                  TextButton.icon(
                    key: const ValueKey('settings-save-retry'),
                    onPressed: widget.onRetrySave,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('설정 저장 다시 시도'),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            icon: Icons.device_unknown_outlined,
            title: '기기 권한 상태',
            subtitle: '기기 권한 상태를 확인해요',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 18,
                        color: WeatherCareTheme.of(context).primaryDeep),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('앱 알림',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(notificationPermission.message,
                      key: const ValueKey('notification-permission-status'),
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(height: 8),
                if (!widget.alertsEnabled) ...[
                  const SizedBox(height: 8),
                  Text('날씨 알림이 꺼져 있어요.\n서버에 등록된 정보가 있다면 발송 대상에서 제외돼요.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                if (notificationPermission ==
                        NotificationPermissionState.notDetermined ||
                    notificationPermission ==
                        NotificationPermissionState.denied ||
                    notificationPermission ==
                        NotificationPermissionState.deniedPermanently)
                  TextButton(
                    key: const ValueKey('notification-permission-refresh'),
                    onPressed: notificationPermission ==
                            NotificationPermissionState.deniedPermanently
                        ? widget.onOpenNotificationSettings
                        : widget.onRequestNotificationPermission ??
                            widget.onRefreshNotificationPermission,
                    child: const Text('권한 다시 확인'),
                  ),
                if (widget.backgroundLocation case final service?) ...[
                  const SizedBox(height: 12),
                  BackgroundLocationControl(
                    service: service,
                    enabled: _backgroundLocationEnabled,
                    available: widget.backgroundLocationAvailable,
                    onChanged: (value) async {
                      setState(() => _backgroundLocationEnabled = value);
                      await widget.onBackgroundLocationChanged(value);
                    },
                    onPermission: widget.onBackgroundLocationPermission ??
                        () => service.requestPermission(),
                  ),
                ],
                const Divider(height: 24),
                TextButton(
                  key: const ValueKey('notification-settings'),
                  onPressed: notificationPermission ==
                          NotificationPermissionState.checking
                      ? null
                      : widget.onOpenNotificationSettings,
                  child: const Text('기기 앱 설정 열기'),
                ),
                const SizedBox(height: 6),
                Text(
                    '기기 앱 설정에서 알림·위치 권한을 변경할 수 있어요.\n백그라운드 위치 갱신에는 위치 권한의 ‘항상 허용’이 필요해요.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          TextButton.icon(
            key: const ValueKey('notification-guide'),
            onPressed: widget.onOpenGuide,
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: const Text('데이터 저장과 알림·위치 권한은 어떻게 다른가요?'),
          ),
        ],
      ),
    );
  }
}

class _DataPermissionSettingsScreen extends StatelessWidget {
  final ServerDataAccess? serverDataAccess;
  final Future<void> Function()? onDeleteServerData;
  final Future<void> Function()? onResumeServerData;
  final ValueChanged<SettingsGuide> onOpenGuide;

  const _DataPermissionSettingsScreen({
    required this.serverDataAccess,
    required this.onDeleteServerData,
    required this.onResumeServerData,
    required this.onOpenGuide,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('서버 내 나의 데이터 삭제'),
              scrollable: true,
              content: const Text(
                  '이 설치의 서버 등록정보, 위치, 알림 토큰, 알림 설정과 발송 이력을 삭제해요.\n다른 기기의 정보는 삭제하지 않아요.\n\n'
                  '삭제 후 서버 알림과 자동 등록을 중지해요.\n기기에 저장한 지역·체크 기록은 남으며, 지역 날씨는 계속 조회할 수 있어요.\n\n'
                  '이미 전송 중인 알림은 도착할 수 있어요.\n운영 로그·백업과 Firebase·광고 서비스의 데이터까지 즉시 삭제하는 기능은 아니에요.\n\n'
                  '기존 설치는 알림 수신 경로로 본인 확인이 필요할 수 있어요.\n삭제 요청 중에는 앱을 열어 두세요.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                FilledButton(
                    key: const ValueKey('server-data-confirm-delete'),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('삭제하기'))
              ],
            ));
    final callback = onDeleteServerData;
    if (confirmed == true && callback != null) await callback();
  }

  Future<void> _confirmResume(BuildContext context) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('서버 기능 다시 사용'),
              scrollable: true,
              content: const Text(
                  '새 설치 식별자로 서버 등록을 시작해요.\n선택 지역과 설정을 보내며, GPS 정밀 위치가 확인되면 좌표도 전송해요.\n기기 알림이 허용되어 있으면 알림 토큰도 등록해요.\n\n날씨 알림 스위치는 자동으로 켜지지 않아요.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('다시 사용하기'))
              ],
            ));
    final callback = onResumeServerData;
    if (confirmed == true && callback != null) await callback();
  }

  Widget _content(BuildContext context, ServerDataAccess? access) {
    return Column(children: [
      _SettingsSection(
        icon: Icons.data_array_outlined,
        title: '데이터 권한 안내',
        subtitle: '자료 출처와 위치·알림 정보 사용을 확인하세요',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final guide in SettingsGuide.values)
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  key: ValueKey('guide-entry-${guide.name}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(guide.title),
                  subtitle: Text(guide.subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onOpenGuide(guide),
                ),
              ),
            AnalyticsConsentControl(
              onDeleteCollectedData: access?.requestAnalyticsDeletion,
            ),
            const Divider(height: 24),
            const AdsPrivacyControl(),
          ],
        ),
      ),
      if (access != null) ...[
        const SizedBox(height: 12),
        _SettingsSection(
          icon: Icons.settings_remote,
          title: '서버 내 나의 데이터 삭제',
          subtitle: switch (access.mode) {
            ServerDataMode.active =>
              '이 설치의 서버 등록정보·위치·알림 토큰·설정·발송 이력을 삭제할 수 있어요.',
            ServerDataMode.deleting => access.busy
                ? '본인 확인과 삭제 결과를 확인하고 있어요.\n앱을 열어 두세요.'
                : '삭제 완료는 확인되지 않았어요.\n자동 등록과 설정 전송은 중지했어요.',
            ServerDataMode.deleted => access.registrationMissing
                ? '서버에 이 설치의 등록정보가 없어요.\n자동 등록은 중지했어요.\n다시 사용하려면 아래에서 직접 선택하세요.'
                : '이 설치의 서버 데이터 삭제를 완료했어요.\n자동 등록과 서버 알림을 중지했어요.',
          },
          child: Column(
            children: [
              if (access.error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(access.error!,
                        key: const ValueKey('server-data-error'))),
              const SizedBox(height: 8),
              if (access.busy)
                const LinearProgressIndicator()
              else if (access.mode == ServerDataMode.deleted)
                OutlinedButton(
                    key: const ValueKey('server-data-resume'),
                    onPressed: onResumeServerData == null
                        ? null
                        : () => _confirmResume(context),
                    child: const Text('서버 기능 다시 사용'))
              else
                OutlinedButton.icon(
                    key: const ValueKey('server-data-delete'),
                    onPressed: onDeleteServerData == null
                        ? null
                        : () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(access.mode == ServerDataMode.deleting
                        ? '삭제 다시 시도'
                        : '서버 내 나의 데이터 삭제')),
            ],
          ),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final access = serverDataAccess;
    return _SettingsDetailScaffold(
      title: '데이터 권한 안내',
      child: access == null
          ? _content(context, null)
          : ListenableBuilder(
              listenable: access,
              builder: (context, _) => _content(context, access),
            ),
    );
  }
}

class _SettingsMenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsMenuButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration:
              WeatherCareTheme.of(context).surfaceDecoration(radius: 24),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: WeatherCareTheme.of(context).primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: WeatherCareTheme.of(context).primaryDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: WeatherCareTheme.of(context).textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdRemovalBanner extends StatelessWidget {
  final VoidCallback onTap;
  final bool isOwned;

  const _AdRemovalBanner({required this.onTap, required this.isOwned});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('ad-removal-menu'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: WeatherCareTheme.of(context)
              .mood(
                'clear',
                borderRadius: BorderRadius.circular(24),
              )
              .copyWith(
                border: Border.all(
                    color: WeatherCareTheme.of(context).primaryBorder),
              ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: WeatherCareTheme.of(context)
                      .surface
                      .withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  isOwned
                      ? Icons.verified_rounded
                      : Icons.workspace_premium_outlined,
                  size: 25,
                  color: WeatherCareTheme.of(context).primaryDeep,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOwned ? 'AD-FREE · 구매 완료' : 'AD-FREE · 평생 이용',
                      style: WeatherCareTheme.of(context)
                          .specialLabelStyle
                          .copyWith(
                            letterSpacing: 0.3,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isOwned ? '광고 없이 이용 중이에요' : '날씨만, 광고 없이 편안하게',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isOwned
                          ? '구매가 적용되어 모든 광고를 제거했어요'
                          : '한 번 구매하고 모든 광고를 제거해요',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: WeatherCareTheme.of(context)
                      .surface
                      .withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 19,
                  color: WeatherCareTheme.of(context).primaryDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsSection({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: WeatherCareTheme.of(context).surfaceDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: WeatherCareTheme.of(context).primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: WeatherCareTheme.of(context).primaryDeep,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  final String settingId;
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleTile({
    required this.settingId,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.46,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: WeatherCareTheme.of(context).primarySoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                size: 20,
                color: WeatherCareTheme.of(context).primaryDeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: WeatherCareTheme.of(context).microTextStyle,
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              key: ValueKey('notification-toggle-$settingId'),
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
