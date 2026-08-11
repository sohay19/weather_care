import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import '../settings/location_mode.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings settings = AppSettings.fallback('local-installation');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('위치 모드', style: TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile<LocationMode>(
            title: const Text('GPS'),
            value: LocationMode.gps,
            groupValue: settings.locationMode == 'GPS' ? LocationMode.gps : LocationMode.manual,
            onChanged: (_) {
              setState(() {
                settings = settings.copyWith(locationMode: 'GPS');
              });
            },
          ),
          RadioListTile<LocationMode>(
            title: const Text('직접 선택 (MANUAL)'),
            value: LocationMode.manual,
            groupValue: settings.locationMode == 'GPS' ? LocationMode.gps : LocationMode.manual,
            onChanged: (_) {
              setState(() {
                settings = settings.copyWith(locationMode: 'MANUAL');
              });
            },
          ),
          const SizedBox(height: 12),
          const Text('알림 설정', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('알림 전체'),
            value: settings.notificationEnabled,
            onChanged: (v) => setState(() => settings = settings.copyWith(notificationEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('우산'),
            value: settings.umbrellaEnabled,
            onChanged: (v) => setState(() => settings = settings.copyWith(umbrellaEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('양산'),
            value: settings.parasolEnabled,
            onChanged: (v) => setState(() => settings = settings.copyWith(parasolEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('폭설 주의'),
            value: settings.heavySnowEnabled,
            onChanged: (v) => setState(() => settings = settings.copyWith(heavySnowEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('겉옷'),
            value: settings.outerwearEnabled,
            onChanged: (v) => setState(() => settings = settings.copyWith(outerwearEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('마스크'),
            value: settings.maskEnabled,
            onChanged: (v) => setState(() => settings = settings.copyWith(maskEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('물'),
            value: settings.waterEnabled,
            onChanged: (v) => setState(() => settings = settings.copyWith(waterEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('선크림'),
            value: settings.sunscreenEnabled,
            onChanged: (v) => setState(() => settings = settings.copyWith(sunscreenEnabled: v)),
          ),
        ],
      ),
    );
  }
}

