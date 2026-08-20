import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../theme/weather_theme.dart';
import 'location_mode.dart';

class SettingsScreen extends StatefulWidget {
  final bool embedded;

  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings settings = AppSettings.fallback('local-installation');

  bool get _alertsEnabled => settings.notificationEnabled;

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      key: widget.embedded ? const ValueKey('setting-tab') : null,
      padding: EdgeInsets.fromLTRB(16, widget.embedded ? 12 : 4, 16, 32),
      children: [
        if (widget.embedded) ...[
          Text('설정', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
        ],
        Text(
          '내 위치와 필요한 알림만 편안하게 맞춰보세요.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: WeatherCareTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 20),
        _SettingsSection(
          icon: Icons.location_on_outlined,
          title: '기준 지역',
          subtitle: '현재 수원 날씨를 기준으로 안내하고 있어요',
          child: RadioGroup<LocationMode>(
            groupValue: settings.locationMode == 'GPS'
                ? LocationMode.gps
                : LocationMode.manual,
            onChanged: (mode) {
              if (mode == null) return;
              setState(() {
                settings = settings.copyWith(locationMode: mode.label);
              });
            },
            child: Column(
              children: [
                _LocationRadioTile(
                  value: LocationMode.gps,
                  icon: Icons.my_location_rounded,
                  title: '현재 위치 사용',
                  subtitle: '필요할 때만 GPS로 위치를 갱신해요',
                  selected: settings.locationMode == 'GPS',
                ),
                const SizedBox(height: 8),
                _LocationRadioTile(
                  value: LocationMode.manual,
                  icon: Icons.map_outlined,
                  title: '지역 직접 선택',
                  subtitle: '선택한 지역을 계속 유지해요',
                  selected: settings.locationMode == 'MANUAL',
                ),
              ],
            ),
          ),
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
                      '필요한 준비물을 한 번에 알려드려요',
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
                value: settings.notificationEnabled,
                activeTrackColor: Colors.white.withValues(alpha: 0.45),
                activeThumbColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                inactiveThumbColor: WeatherCareTheme.primaryBorder,
                trackOutlineColor:
                    const WidgetStatePropertyAll(Colors.transparent),
                onChanged: (value) {
                  setState(() {
                    settings = settings.copyWith(notificationEnabled: value);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          icon: Icons.schedule_outlined,
          title: '알림 시간',
          subtitle: 'Morning Brief를 받을 기본 시간이에요',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
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
                    '매일 아침',
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
        const SizedBox(height: 16),
        _SettingsSection(
          icon: Icons.work_outline_rounded,
          title: '챙겨요 알림',
          subtitle: '아침 알림에 포함할 준비물을 선택해요',
          child: Column(
            children: [
              _SettingsToggleTile(
                icon: Icons.umbrella_outlined,
                title: '우산',
                value: settings.umbrellaEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => setState(() {
                  settings = settings.copyWith(umbrellaEnabled: value);
                }),
              ),
              _SettingsToggleTile(
                icon: Icons.wb_sunny_outlined,
                title: '양산',
                value: settings.parasolEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => setState(() {
                  settings = settings.copyWith(parasolEnabled: value);
                }),
              ),
              _SettingsToggleTile(
                icon: Icons.checkroom_rounded,
                title: '겉옷',
                value: settings.outerwearEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => setState(() {
                  settings = settings.copyWith(outerwearEnabled: value);
                }),
              ),
              _SettingsToggleTile(
                icon: Icons.face_outlined,
                title: '마스크',
                value: settings.maskEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => setState(() {
                  settings = settings.copyWith(maskEnabled: value);
                }),
              ),
              _SettingsToggleTile(
                icon: Icons.local_drink_outlined,
                title: '물',
                value: settings.waterEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => setState(() {
                  settings = settings.copyWith(waterEnabled: value);
                }),
              ),
              _SettingsToggleTile(
                icon: Icons.spa_outlined,
                title: '선크림',
                value: settings.sunscreenEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => setState(() {
                  settings = settings.copyWith(sunscreenEnabled: value);
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          icon: Icons.shield_outlined,
          title: '주의 및 날씨 안내',
          subtitle: '안전과 하루 날씨 알림을 관리해요',
          child: Column(
            children: [
              _SettingsToggleTile(
                icon: Icons.ac_unit_rounded,
                title: '폭설 주의',
                value: settings.heavySnowEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => setState(() {
                  settings = settings.copyWith(heavySnowEnabled: value);
                }),
              ),
              _SettingsToggleTile(
                icon: Icons.wb_cloudy_outlined,
                title: '오늘 날씨',
                value: settings.dailyWeatherEnabled,
                enabled: _alertsEnabled,
                onChanged: (value) => setState(() {
                  settings = settings.copyWith(dailyWeatherEnabled: value);
                }),
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
                  '현재 설정은 화면 안에서만 바뀌는 데모 상태예요. 서버 저장 기능은 아직 연결되지 않았어요.',
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
        Center(
          child: Text(
            '날씨 정보는 기상청 공식 API를 사용합니다.',
            textAlign: TextAlign.center,
            style: WeatherCareTheme.microTextStyle.copyWith(
              fontSize: 9,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: body,
    );
  }
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
  final IconData icon;
  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleTile({
    required this.icon,
    required this.title,
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
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
