import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_settings.dart';
import '../../services/current_location_service.dart';
import '../../services/region_catalog.dart';
import '../../services/settings_save_controller.dart';
import '../../services/notification_permission_service.dart';
import '../../models/selectable_region.dart';
import '../../theme/weather_theme.dart';
import '../home/widgets/tab_page_header.dart';
import 'ad_removal_purchase_screen.dart';
import 'location_mode.dart';
import 'region_picker_screen.dart';
import 'notification_schedule.dart';
import 'settings_guide.dart';
import 'settings_guide_screen.dart';
import 'analytics_consent_control.dart';
import 'ads_privacy_control.dart';
import '../../services/server_data_access.dart';

const _weatherMapUrl = 'https://weather-care.pages.dev/weather-map';

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
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings settings;

  @override
  void initState() {
    super.initState();
    settings =
        widget.initialSettings ?? AppSettings.fallback('local-installation');
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updated = widget.initialSettings;
    if (updated != null && updated != oldWidget.initialSettings) {
      settings = updated;
    }
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
            subtitle: '나의 위치와 필요한 알람을 설정할 수 있어요.',
            icon: Icons.tune_rounded,
          )
        else
          Text(
            '나의 위치와 필요한 알람을 설정할 수 있어요.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: WeatherCareTheme.textSecondary,
                ),
          ),
        const SizedBox(height: 20),
        _AdRemovalBanner(onTap: _openAdRemovalPurchase),
        const SizedBox(height: 16),
        _SettingsMenuButton(
          key: const ValueKey('location-settings-menu'),
          icon: Icons.location_on_outlined,
          title: '지역 선택',
          subtitle: settings.locationMode == 'GPS'
              ? widget.location.hasLocation
                  ? '${widget.regionName ?? '확인한 위치'} 기준으로 안내해요'
                  : '현재 위치 확인이 필요해요'
              : widget.manualRegionName ?? '선택 지역을 확인해요',
          onTap: _openLocationSettings,
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
          title: '저장·기기 알림 상태',
          subtitle: '설정 저장과 기기 권한 상태를 확인해요',
          onTap: _openNotificationStatusSettings,
        ),
        const SizedBox(height: 16),
        _SettingsMenuButton(
          key: const ValueKey('data-permission-menu'),
          icon: Icons.info_outline_rounded,
          title: '데이터·권한 안내',
          subtitle: '자료 출처와 위치·알림 정보 사용을 확인해요',
          onTap: _openDataPermissionSettings,
        ),
      ],
    );
    final refreshableBody = RefreshIndicator(
      color: WeatherCareTheme.primary,
      onRefresh: widget.onRefresh ?? () async {},
      child: body,
    );
    if (widget.embedded) return refreshableBody;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: refreshableBody,
    );
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

  void _openLocationSettings() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => _LocationSettingsScreen(
        initialSettings: settings,
        location: widget.location,
        regionName: widget.regionName,
        manualRegionName: widget.manualRegionName,
        onLocate: widget.onLocate,
        onOpenLocationSettings: widget.onOpenLocationSettings,
        loadRegionCatalog: widget.loadRegionCatalog,
        onSettingsChanged: _updateSettings,
        onOpenGuide: () => _openGuide(SettingsGuide.location),
        openExternalLink: widget.openExternalLink,
      ),
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

  void _openNotificationStatusSettings() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => _NotificationStatusSettingsScreen(
        alertsEnabled: _alertsEnabled,
        saveState: widget.saveState,
        onRetrySave: widget.onRetrySave,
        notificationPermission: widget.notificationPermission,
        onRequestNotificationPermission: widget.onRequestNotificationPermission,
        onRefreshNotificationPermission: widget.onRefreshNotificationPermission,
        onOpenNotificationSettings: widget.onOpenNotificationSettings,
        onOpenGuide: () => _openGuide(SettingsGuide.notifications),
      ),
    ));
  }

  void _openAdRemovalPurchase() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const AdRemovalPurchaseScreen(),
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

class _LocationSettingsScreen extends StatefulWidget {
  final AppSettings initialSettings;
  final LocationResult location;
  final String? regionName;
  final String? manualRegionName;
  final Future<void> Function()? onLocate;
  final Future<void> Function()? onOpenLocationSettings;
  final Future<RegionCatalog> Function()? loadRegionCatalog;
  final ValueChanged<AppSettings> onSettingsChanged;
  final VoidCallback onOpenGuide;
  final Future<bool> Function(Uri)? openExternalLink;

  const _LocationSettingsScreen({
    required this.initialSettings,
    required this.location,
    required this.regionName,
    required this.manualRegionName,
    required this.onLocate,
    required this.onOpenLocationSettings,
    required this.loadRegionCatalog,
    required this.onSettingsChanged,
    required this.onOpenGuide,
    required this.openExternalLink,
  });

  @override
  State<_LocationSettingsScreen> createState() =>
      _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<_LocationSettingsScreen> {
  late AppSettings settings;
  bool _pickingRegion = false;
  bool _openingWeatherMap = false;

  @override
  void initState() {
    super.initState();
    settings = widget.initialSettings;
  }

  void _update(AppSettings updated) {
    setState(() => settings = updated);
    widget.onSettingsChanged(updated);
  }

  Future<void> _selectRegion() async {
    if (_pickingRegion) return;
    setState(() => _pickingRegion = true);
    final selected =
        await Navigator.of(context).push<ForecastRegion>(MaterialPageRoute(
      builder: (_) => RegionPickerScreen(
        loadCatalog: widget.loadRegionCatalog,
        selectedKey: settings.manualRegionKey,
      ),
    ));
    if (!mounted) return;
    setState(() => _pickingRegion = false);
    if (selected == null) return;
    _update(settings.copyWith(
      locationMode: 'MANUAL',
      currentRegionId: selected.gridId,
      manualRegionKey: selected.key,
    ));
  }

  Future<void> _openWeatherMap() async {
    if (_openingWeatherMap) return;
    setState(() => _openingWeatherMap = true);
    var opened = false;
    try {
      final uri = Uri.parse(_weatherMapUrl);
      opened = await (widget.openExternalLink?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // 브라우저가 없거나 실행할 수 없으면 아래 안내를 표시한다.
    }
    if (!mounted) return;
    setState(() => _openingWeatherMap = false);
    if (opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('예보 구역 지도를 열지 못했어요.\n인터넷 연결을 확인해주세요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailScaffold(
        title: '지역 선택',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsSection(
              icon: Icons.map_outlined,
              title: '지역 설정 방법',
              subtitle: settings.locationMode == 'GPS'
                  ? widget.location.hasLocation
                      ? '${widget.regionName ?? '확인한 위치'} 기준으로 지역 예보를 안내해요'
                      : '현재 위치 확인이 필요해요'
                  : settings.currentRegionId == null
                      ? '선택된 지역이 없어요'
                      : widget.manualRegionName ?? '저장한 지역 기준으로 안내해요',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioGroup<LocationMode>(
                      groupValue: settings.locationMode == 'GPS'
                          ? LocationMode.gps
                          : LocationMode.manual,
                      onChanged: (mode) {
                        if (mode == null) return;
                        if (mode == LocationMode.manual &&
                            settings.manualRegionKey == null) {
                          unawaited(_selectRegion());
                          return;
                        }
                        _update(settings.copyWith(locationMode: mode.label));
                      },
                      child: Column(children: [
                        _LocationRadioTile(
                          value: LocationMode.gps,
                          icon: Icons.my_location_rounded,
                          title: '현재 위치 사용',
                          subtitle: '앱 실행·복귀·새로고침 때 위치를 확인해요',
                          selected: settings.locationMode == 'GPS',
                        ),
                        const SizedBox(height: 8),
                        _LocationRadioTile(
                          value: LocationMode.manual,
                          icon: Icons.map_outlined,
                          title: '지역 직접 선택',
                          subtitle: settings.currentRegionId == null
                              ? '저장된 지역이 없어요'
                              : widget.manualRegionName ?? '저장한 지역을 사용할 수 있어요',
                          selected: settings.locationMode == 'MANUAL',
                        ),
                      ]),
                    ),
                    if (settings.locationMode == 'GPS') ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Text(widget.location.message,
                            key: const ValueKey('location-status')),
                      ),
                      const SizedBox(height: 20),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        FilledButton.tonalIcon(
                          key: const ValueKey('location-refresh'),
                          onPressed:
                              widget.location.state == LocationState.checking
                                  ? null
                                  : widget.onLocate,
                          icon: const Icon(Icons.my_location_rounded),
                          label: Text(widget.location.state ==
                                      LocationState.denied ||
                                  widget.location.state == LocationState.idle
                              ? '위치 권한 허용하고 확인'
                              : '위치 다시 확인'),
                        ),
                        if (widget.location.measuredAt != null) ...[
                          const SizedBox(height: 6),
                          Text(_locationTimeLabel(widget.location.measuredAt!),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                        if ({
                          LocationState.serviceDisabled,
                          LocationState.denied,
                          LocationState.deniedForever,
                          LocationState.approximate,
                        }.contains(widget.location.state))
                          TextButton(
                            key: const ValueKey('location-settings'),
                            onPressed: widget.onOpenLocationSettings,
                            child: Text(
                              widget.location.state ==
                                      LocationState.serviceDisabled
                                  ? '기기 위치 설정 열기'
                                  : '앱 권한 설정 열기',
                            ),
                          ),
                      ]),
                      const SizedBox(height: 15),
                      Text('백그라운드에서 위치를 계속 추적하지 않아요.\n알림은 마지막 등록 지역 기준이에요.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ] else ...[
                      const SizedBox(height: 10),
                      if (settings.currentRegionId == null)
                        const Text('저장된 지역이 없어 날씨를 조회할 수 없어요.\n위치를 선택해주세요.'),
                      FilledButton.tonalIcon(
                        key: const ValueKey('region-change'),
                        onPressed: _pickingRegion ? null : _selectRegion,
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('지역 선택·변경'),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                          '선택 지역의 대표 예보 지점 기준이며 정밀 강수·도로 분석에는 사용하지 않아요.'),
                    ],
                  ]),
            ),
            TextButton.icon(
              key: const ValueKey('location-guide'),
              onPressed: widget.onOpenGuide,
              icon: const Icon(Icons.help_outline_rounded, size: 18),
              label: const Text('위치 권한은 어디에 쓰이나요?'),
            ),
            TextButton.icon(
              key: const ValueKey('weather-grid-guide'),
              onPressed: _openingWeatherMap ? null : _openWeatherMap,
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              label: const Text('예보 기준 구역은 어떻게 되어있나요?'),
            ),
          ],
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
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(pieces.first) ?? 7,
        minute: int.tryParse(pieces.length > 1 ? pieces[1] : '') ?? 0,
      ),
      helpText: '알림 시간 선택',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
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
        Text('알림 시간과 받을 날씨·생활 알림을 영역별로 설정해요',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: WeatherCareTheme.textSecondary,
                )),
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
            Opacity(
              key: const ValueKey('notification-time-control'),
              opacity: enabled ? 1 : 0.46,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: enabled ? _selectTime : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                  decoration: BoxDecoration(
                    color: WeatherCareTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    const Icon(Icons.alarm_rounded,
                        color: WeatherCareTheme.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('설정 시각',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text(
                      settings.notificationTime,
                      style: const TextStyle(
                        color: WeatherCareTheme.primaryDeep,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: WeatherCareTheme.textSecondary),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              notificationScheduleDescription(settings.notificationTime),
              key: const ValueKey('notification-schedule-description'),
            ),
            if (!settings.dailyWeatherEnabled)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('준비물 요약 알림을 켜야 설정한 시간이 적용돼요.'),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: WeatherCareTheme.attentionSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 19,
                color: WeatherCareTheme.attention,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '설정 실패 시 저장·기기 알림 상태에서 재시도 해주세요.',
                  style: WeatherCareTheme.microTextStyle.copyWith(
                    color: WeatherCareTheme.attentionDeep,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
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
              icon: Icons.water_drop_outlined,
              settingId: 'showerAndLightRainEnabled',
              title: '현재 비 안내',
              subtitle:
                  '관측분석·레이더가 일치한 현재 비를 안내해요.\n우산도 켜고 GPS 정밀 위치를 확인해야 해요.\n소나기 예보 알림은 아니에요',
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
              '블랙아이스(도로살얼음)·도로통제·그 밖의 공식 특보는 개별 스위치 없이 전체 날씨 알림 설정을 따라요.\n블랙아이스·도로통제는 서버에 등록된 정밀 위치와 해당 자료가 있어야 해요.',
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

class _NotificationStatusSettingsScreen extends StatelessWidget {
  final bool alertsEnabled;
  final SettingsSaveState saveState;
  final Future<void> Function()? onRetrySave;
  final NotificationPermissionState notificationPermission;
  final Future<void> Function()? onRequestNotificationPermission;
  final Future<void> Function()? onRefreshNotificationPermission;
  final Future<void> Function()? onOpenNotificationSettings;
  final VoidCallback onOpenGuide;

  const _NotificationStatusSettingsScreen({
    required this.alertsEnabled,
    required this.saveState,
    required this.onRetrySave,
    required this.notificationPermission,
    required this.onRequestNotificationPermission,
    required this.onRefreshNotificationPermission,
    required this.onOpenNotificationSettings,
    required this.onOpenGuide,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailScaffold(
      title: '저장·기기 알림 상태',
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
                    onPressed: onRetrySave,
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
            title: '기기 상태',
            subtitle: '기기에서 알림을 보낼 수 있는 상태인지 확인해요',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(notificationPermission.message,
                      key: const ValueKey('notification-permission-status')),
                ),
                const SizedBox(height: 8),
                if (!alertsEnabled) ...[
                  const SizedBox(height: 8),
                  const Text('날씨 알림이 꺼져 있어요.\n서버에 등록된 정보가 있다면 발송 대상에서 제외돼요.'),
                ],
                const Divider(height: 24),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  if (notificationPermission ==
                          NotificationPermissionState.denied ||
                      notificationPermission ==
                          NotificationPermissionState.notDetermined)
                    FilledButton.tonal(
                      key: const ValueKey('notification-permission-request'),
                      onPressed: onRequestNotificationPermission,
                      child: const Text('알림 권한 요청'),
                    ),
                  TextButton(
                    key: const ValueKey('notification-permission-refresh'),
                    onPressed: notificationPermission ==
                            NotificationPermissionState.checking
                        ? null
                        : onRefreshNotificationPermission,
                    child: const Text('권한 다시 확인'),
                  ),
                  TextButton(
                    key: const ValueKey('notification-settings'),
                    onPressed: notificationPermission ==
                            NotificationPermissionState.checking
                        ? null
                        : onOpenNotificationSettings,
                    child: const Text('기기 앱 설정 열기'),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                    '기기 앱 설정의 알림 메뉴에서 변경할 수 있어요.\n서버 저장과 권한 허용만으로 실제 수신을 확인할 수는 없어요.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          TextButton.icon(
            key: const ValueKey('notification-guide'),
            onPressed: onOpenGuide,
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: const Text('알림 권한과 앱 설정은 어떻게 다른가요?'),
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
        title: '데이터·권한 안내',
        subtitle: '자료 출처와 위치·알림 정보 사용을 확인하세요',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final guide in SettingsGuide.values)
              ListTile(
                key: ValueKey('guide-entry-${guide.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(guide.title),
                subtitle: Text(guide.subtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onOpenGuide(guide),
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
      title: '데이터·권한 안내',
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
          decoration: WeatherCareTheme.surfaceDecoration(radius: 24),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: WeatherCareTheme.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: WeatherCareTheme.primaryDeep,
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
              const Icon(
                Icons.chevron_right_rounded,
                color: WeatherCareTheme.textSecondary,
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

  const _AdRemovalBanner({required this.onTap});

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
          decoration: WeatherCareTheme.mood(
            'clear',
            borderRadius: BorderRadius.circular(24),
          ).copyWith(
            border: Border.all(color: WeatherCareTheme.primaryBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  size: 25,
                  color: WeatherCareTheme.primaryDeep,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AD-FREE · 평생 이용',
                      style: WeatherCareTheme.specialLabelStyle.copyWith(
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '날씨만, 광고 없이 편안하게',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '한 번 구매하고 모든 광고를 제거해요',
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
                  color: Colors.white.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 19,
                  color: WeatherCareTheme.primaryDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _locationTimeLabel(DateTime time) {
  final korea = time.toUtc().add(const Duration(hours: 9));
  final minute = korea.minute.toString().padLeft(2, '0');
  return '위치 확인: ${korea.month}월 ${korea.day}일 ${korea.hour}:$minute';
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
      decoration: WeatherCareTheme.surfaceDecoration(radius: 24),
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
                  color: WeatherCareTheme.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: WeatherCareTheme.primaryDeep,
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

class _LocationRadioTile extends StatelessWidget {
  final LocationMode value;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;

  const _LocationRadioTile({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? WeatherCareTheme.primarySoft
            : WeatherCareTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? WeatherCareTheme.primaryBorder
              : WeatherCareTheme.outline,
        ),
      ),
      child: RadioListTile<LocationMode>(
        value: value,
        activeColor: WeatherCareTheme.primary,
        secondary: Icon(
          icon,
          color: selected
              ? WeatherCareTheme.primaryDeep
              : WeatherCareTheme.textSecondary,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                color: WeatherCareTheme.primarySoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                size: 20,
                color: WeatherCareTheme.primaryDeep,
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
                      style: WeatherCareTheme.microTextStyle,
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
