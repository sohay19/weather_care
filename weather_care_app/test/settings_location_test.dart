import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/current_location_service.dart';

void main() {
  testWidgets('권한 거부는 현재 위치 사용 중이라고 안내하지 않고 복구 버튼을 제공한다', (tester) async {
    var located = 0;
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
      location: const LocationResult(LocationState.denied),
      onLocate: () async => located++,
      onOpenLocationSettings: () async => opened++,
    )));
    expect(find.text('현재 위치 확인이 필요해요'), findsOneWidget);
    expect(find.textContaining('확인한 현재 위치를 기준'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('location-refresh')));
    await tester.tap(find.byKey(const ValueKey('location-refresh')));
    await tester.tap(find.byKey(const ValueKey('location-settings')));
    expect(located, 1);
    expect(opened, 1);
  });
  testWidgets('확인 중 중복 버튼을 막고 기기 위치 설정을 구분한다', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
      location: const LocationResult(LocationState.checking),
      onLocate: () async {},
    )));
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('location-refresh')))
            .onPressed,
        isNull);
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
      location: const LocationResult(LocationState.serviceDisabled),
      onOpenLocationSettings: () async {},
    )));
    expect(find.text('기기 위치 설정 열기'), findsOneWidget);
  });
  testWidgets('대략적 위치와 측정 시각은 360px 큰 글자에서도 표시된다', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
        home: SettingsScreen(
          location: LocationResult(LocationState.approximate,
              coordinates:
                  const DeviceCoordinates(latitude: 37.57, longitude: 126.98),
              measuredAt: DateTime.utc(2026, 9, 10, 7, 22)),
          regionName: '서울',
        )));
    await tester.ensureVisible(find.byKey(const ValueKey('location-status')));
    expect(find.textContaining('세밀한 강수·도로 분석은 사용하지 않아요'), findsOneWidget);
    expect(find.text('위치 확인: 9월 10일 16:22'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('저장한 수동 지역이 없으면 수원 또는 현재 위치로 안내하지 않는다', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
      initialSettings:
          AppSettings.fallback('test').copyWith(locationMode: 'MANUAL'),
    )));
    expect(find.text('선택된 지역이 없어요'), findsOneWidget);
    expect(find.textContaining('수원'), findsNothing);
    expect(find.byKey(const ValueKey('location-refresh')), findsNothing);
  });
}
