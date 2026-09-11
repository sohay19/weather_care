import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../services/current_location_service.dart';
import '../../services/region_catalog.dart';
import '../../services/settings_save_controller.dart';
import '../../services/notification_permission_service.dart';
import '../../models/selectable_region.dart';
import '../../theme/weather_theme.dart';
import '../home/widgets/tab_page_header.dart';
import 'location_mode.dart';
import 'region_picker_screen.dart';
import 'notification_schedule.dart';
import 'settings_guide.dart';
import 'settings_guide_screen.dart';
import 'server_data_controls.dart';
import 'analytics_consent_control.dart';
import 'ads_privacy_control.dart';
import '../../services/server_data_access.dart';

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
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings settings;
  bool _pickingRegion = false;

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
        _SettingsSection(
          icon: Icons.location_on_outlined,
          title: '기준 지역',
          subtitle: settings.locationMode == 'GPS'
              ? widget.location.hasLocation
                  ? '${widget.regionName ?? '확인한 위치'} 기준으로 지역 예보를 안내해요'
                  : '현재 위치 확인이 필요해요'
              : settings.currentRegionId == null
                  ? '선택된 지역이 없어요'
                  : settings.manualRegionKey != null &&
                          widget.manualRegionName == null
                      ? '저장한 지역을 다시 선택해주세요'
                      : '${widget.manualRegionName ?? widget.regionName ?? '저장한 지역'} 기준으로 안내해요',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                _updateSettings(settings.copyWith(locationMode: mode.label));
              },
              child: Column(
                children: [
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
                ],
              ),
            ),
            if (settings.locationMode == 'GPS') ...[
              const SizedBox(height: 12),
              Text(widget.location.message,
                  key: const ValueKey('location-status')),
              if (widget.location.measuredAt != null) ...[
                const SizedBox(height: 6),
                Text(_locationTimeLabel(widget.location.measuredAt!),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                FilledButton.tonalIcon(
                  key: const ValueKey('location-refresh'),
                  onPressed: widget.location.state == LocationState.checking
                      ? null
                      : widget.onLocate,
                  icon: const Icon(Icons.my_location_rounded),
                  label: Text(widget.location.state == LocationState.denied ||
                          widget.location.state == LocationState.idle
                      ? '위치 권한 허용하고 확인'
                      : '위치 다시 확인'),
                ),
                if ([
                  LocationState.serviceDisabled,
                  LocationState.denied,
                  LocationState.deniedForever,
                  LocationState.approximate
                ].contains(widget.location.state))
                  TextButton(
                      key: const ValueKey('location-settings'),
                      onPressed: widget.onOpenLocationSettings,
                      child: Text(
                          widget.location.state == LocationState.serviceDisabled
                              ? '기기 위치 설정 열기'
                              : '앱 권한 설정 열기')),
              ]),
              const SizedBox(height: 6),
              Text('백그라운드에서 위치를 계속 추적하지 않아요. 알림은 서버에 마지막으로 등록된 지역 기준이에요.',
                  style: Theme.of(context).textTheme.bodySmall),
            ] else ...[
              const SizedBox(height: 10),
              if (settings.currentRegionId == null)
                const Text('저장된 지역이 없어 날씨를 조회할 수 없어요. 기준 지역을 선택해주세요.'),
              FilledButton.tonalIcon(
                  key: const ValueKey('region-change'),
                  onPressed: _pickingRegion ? null : _selectRegion,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('지역 선택·변경')),
              const SizedBox(height: 6),
              const Text(
                  '선택 지역의 대표 예보 지점 기준이에요. 현재 위치를 추적하지 않으며, 정밀 강수·도로 분석에는 사용하지 않아요.'),
            ],
            TextButton.icon(
              key: const ValueKey('location-guide'),
              onPressed: () => _openGuide(SettingsGuide.location),
              icon: const Icon(Icons.help_outline_rounded, size: 18),
              label: const Text('위치 권한은 어디에 쓰이나요?'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                WeatherCareTheme.primaryDeep,
                WeatherCareTheme.primary,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: WeatherCareTheme.shadow,
                blurRadius: 24,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '날씨 알림',
                      style: TextStyle(
                        fontFamily: WeatherCareTheme.fontNeoHyundai,
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '준비물과 기상·도로 안내를 받아요',
                      style: TextStyle(
                        fontFamily: WeatherCareTheme.fontChosunSg,
                        color: Color(0xE6FFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _alertsEnabled,
                activeTrackColor: Colors.white.withValues(alpha: 0.45),
                activeThumbColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                inactiveThumbColor: WeatherCareTheme.primaryBorder,
                trackOutlineColor:
                    const WidgetStatePropertyAll(Colors.transparent),
                onChanged: (widget.serverDataAccess?.paused ?? false)
                    ? null
                    : (value) {
                        _updateSettings(
                          settings.copyWith(notificationEnabled: value),
                        );
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          icon: Icons.sync_rounded,
          title: '저장·기기 알림 상태',
          subtitle: '설정 저장과 기기의 알림 허용은 별개예요',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(
              liveRegion: true,
              child: Text(widget.saveState.message,
                  key: const ValueKey('settings-save-status')),
            ),
            if (widget.saveState.canRetry)
              TextButton.icon(
                  key: const ValueKey('settings-save-retry'),
                  onPressed: widget.onRetrySave,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('설정 저장 다시 시도')),
            const Divider(height: 24),
            Semantics(
              liveRegion: true,
              child: Text(widget.notificationPermission.message,
                  key: const ValueKey('notification-permission-status')),
            ),
            if (!_alertsEnabled) ...[
              const SizedBox(height: 8),
              const Text(
                  '날씨 알림이 꺼져 있어요. 서버에 등록된 정보가 있다면 서버 반영 후 발송 대상에서 제외돼요. 이미 처리 중이거나 발송된 알림은 도착할 수 있어요.'),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (widget.notificationPermission ==
                      NotificationPermissionState.denied ||
                  widget.notificationPermission ==
                      NotificationPermissionState.notDetermined)
                FilledButton.tonal(
                    key: const ValueKey('notification-permission-request'),
                    onPressed: widget.onRequestNotificationPermission,
                    child: const Text('알림 권한 요청')),
              TextButton(
                  key: const ValueKey('notification-permission-refresh'),
                  onPressed: widget.notificationPermission ==
                          NotificationPermissionState.checking
                      ? null
                      : widget.onRefreshNotificationPermission,
                  child: const Text('권한 다시 확인')),
              TextButton(
                  key: const ValueKey('notification-settings'),
                  onPressed: widget.notificationPermission ==
                          NotificationPermissionState.checking
                      ? null
                      : widget.onOpenNotificationSettings,
                  child: const Text('기기 앱 설정 열기')),
            ]),
            const SizedBox(height: 6),
            Text(
                '기기 앱 설정의 알림 메뉴에서 변경할 수 있어요. 개별 알림 종류·집중 모드·소리 설정에 따라 표시 방식이 달라질 수 있어요. 서버 저장과 권한 허용만으로 실제 수신을 확인할 수는 없어요.',
                style: Theme.of(context).textTheme.bodySmall),
            TextButton.icon(
              key: const ValueKey('notification-guide'),
              onPressed: () => _openGuide(SettingsGuide.notifications),
              icon: const Icon(Icons.help_outline_rounded, size: 18),
              label: const Text('알림 권한과 앱 설정은 어떻게 다른가요?'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          icon: Icons.schedule_outlined,
          title: '알림 시간',
          subtitle: '준비물 요약에만 적용돼요. 특보·현재 비·도로 안내는 별도로 확인해요',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IgnorePointer(
              ignoring: !_alertsEnabled,
              child: Opacity(
                key: const ValueKey('notification-time-control'),
                opacity: _alertsEnabled ? 1 : 0.46,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _selectNotificationTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 14),
                    decoration: BoxDecoration(
                      color: WeatherCareTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.alarm_rounded,
                          color: WeatherCareTheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '설정 시각',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
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
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: WeatherCareTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(notificationScheduleDescription(settings.notificationTime),
                key: const ValueKey('notification-schedule-description')),
            if (!settings.dailyWeatherEnabled)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('준비물 요약 알림을 켜야 설정한 시간이 적용돼요.'),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          icon: Icons.work_outline_rounded,
          title: '챙겨요 알림',
          subtitle: '준비물 요약 알림에 포함할 항목을 선택해요',
          child: Column(
            children: [
              _SettingsToggleTile(
                icon: Icons.umbrella_outlined,
                settingId: 'umbrellaEnabled',
                title: '우산',
                subtitle: '준비물 요약과 현재 비 안내에 함께 적용돼요',
                value: settings.umbrellaEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(umbrellaEnabled: value),
                ),
              ),
              _SettingsToggleTile(
                icon: Icons.wb_sunny_outlined,
                settingId: 'parasolEnabled',
                title: '양산',
                value: settings.parasolEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(parasolEnabled: value),
                ),
              ),
              _SettingsToggleTile(
                icon: Icons.checkroom_rounded,
                settingId: 'outerwearEnabled',
                title: '겉옷',
                value: settings.outerwearEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(outerwearEnabled: value),
                ),
              ),
              _SettingsToggleTile(
                icon: Icons.face_outlined,
                settingId: 'maskEnabled',
                title: '마스크',
                value: settings.maskEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(maskEnabled: value),
                ),
              ),
              _SettingsToggleTile(
                icon: Icons.local_drink_outlined,
                settingId: 'waterEnabled',
                title: '물',
                value: settings.waterEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(waterEnabled: value),
                ),
              ),
              _SettingsToggleTile(
                icon: Icons.spa_outlined,
                settingId: 'sunscreenEnabled',
                title: '선크림',
                value: settings.sunscreenEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(sunscreenEnabled: value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          icon: Icons.shield_outlined,
          title: '기상·생활 알림',
          subtitle: '발효된 공식 정보와 생활 준비 알림을 관리해요',
          child: Column(
            children: [
              _SettingsToggleTile(
                icon: Icons.thunderstorm_outlined,
                settingId: 'heavyRainEnabled',
                title: '호우특보 안내',
                subtitle: '발효된 호우특보의 시작·단계 변경·해제를 안내해요',
                value: settings.heavyRainEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(heavyRainEnabled: value),
                ),
              ),
              _SettingsToggleTile(
                icon: Icons.ac_unit_rounded,
                settingId: 'heavySnowEnabled',
                title: '대설·많은 눈 안내',
                subtitle: '발효된 대설특보와 예보 기반 많은 눈 대비를 안내해요',
                value: settings.heavySnowEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(heavySnowEnabled: value),
                ),
              ),
              _SettingsToggleTile(
                icon: Icons.device_thermostat_rounded,
                settingId: 'heatwaveEnabled',
                title: '폭염특보 안내',
                subtitle: '발효된 폭염특보의 시작·단계 변경·해제를 안내해요',
                value: settings.heatwaveEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(heatwaveEnabled: value),
                ),
              ),
              _SettingsToggleTile(
                icon: Icons.severe_cold_outlined,
                settingId: 'coldWaveEnabled',
                title: '한파특보 안내',
                subtitle: '발효된 한파특보의 시작·단계 변경·해제를 안내해요',
                value: settings.coldWaveEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(coldWaveEnabled: value),
                ),
              ),
              _SettingsToggleTile(
                icon: Icons.water_drop_outlined,
                settingId: 'showerAndLightRainEnabled',
                title: '현재 비 안내',
                subtitle:
                    '관측분석·레이더가 일치한 현재 비를 안내해요. 우산도 켜고 GPS 정밀 위치를 확인해야 해요. 소나기 예보 알림은 아니에요',
                value: settings.showerAndLightRainEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(showerAndLightRainEnabled: value),
                ),
              ),
              _SettingsToggleTile(
                icon: Icons.wb_cloudy_outlined,
                settingId: 'dailyWeatherEnabled',
                title: '준비물 요약 알림',
                subtitle: '추천할 준비물이 있을 때만 설정한 시간에 하루 한 번, 선택한 항목 중 최대 3개를 안내해요',
                value: settings.dailyWeatherEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(dailyWeatherEnabled: value),
                ),
              ),
              const Divider(height: 24),
              const Text(
                '추가 안내: 블랙아이스(도로살얼음)·도로통제·그 밖의 공식 특보는 개별 스위치 없이 전체 날씨 알림 설정을 따라요. 블랙아이스·도로통제는 서버에 등록된 정밀 위치와 해당 자료가 있어야 해요.',
                key: ValueKey('additional-notification-contract'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
                  '변경한 설정의 반영 결과는 위의 저장·기기 알림 상태에서 확인해주세요.',
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
          icon: Icons.info_outline_rounded,
          title: '데이터·권한 안내',
          subtitle: '자료 출처와 위치·알림 정보 사용을 확인하세요',
          child: Column(
            children: [
              for (final guide in SettingsGuide.values)
                ListTile(
                  key: ValueKey('guide-entry-${guide.name}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(guide.title),
                  subtitle: Text(guide.subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openGuide(guide),
                ),
              AnalyticsConsentControl(
                onDeleteCollectedData:
                    widget.serverDataAccess?.requestAnalyticsDeletion,
              ),
              const AdsPrivacyControl(),
              if (widget.serverDataAccess != null) ...[
                const Divider(height: 24),
                ServerDataControls(
                    access: widget.serverDataAccess!,
                    onDelete: widget.onDeleteServerData ?? () async {},
                    onResume: widget.onResumeServerData ?? () async {}),
              ],
            ],
          ),
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
              const SnackBar(content: Text('설정을 저장하지 못했어요. 다시 시도해주세요.')));
        }
      }));
    }
  }

  void _openGuide(SettingsGuide guide) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => SettingsGuideScreen(guide: guide),
    ));
  }

  Future<void> _selectRegion() async {
    if (_pickingRegion) return;
    setState(() => _pickingRegion = true);
    final selected =
        await Navigator.of(context).push<ForecastRegion>(MaterialPageRoute(
      builder: (_) => RegionPickerScreen(
          loadCatalog: widget.loadRegionCatalog,
          selectedKey: settings.manualRegionKey),
    ));
    if (!mounted) return;
    setState(() => _pickingRegion = false);
    if (selected == null) return;
    _updateSettings(settings.copyWith(
        locationMode: 'MANUAL',
        currentRegionId: selected.gridId,
        manualRegionKey: selected.key));
  }

  Future<void> _selectNotificationTime() async {
    if (!_alertsEnabled) return;
    final pieces = settings.notificationTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(pieces.first) ?? 7,
      minute: int.tryParse(pieces.length > 1 ? pieces[1] : '') ?? 0,
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: '알림 시간 선택',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    final time =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    _updateSettings(settings.copyWith(notificationTime: time));
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
