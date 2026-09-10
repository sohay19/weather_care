import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/features/home/home_screen.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/app_settings_repository.dart';
import 'package:weather_care/services/current_location_service.dart';
import 'package:weather_care/services/kma_direct_weather_service.dart';
import 'package:weather_care/services/kma_grid.dart';
import 'package:weather_care/services/notification_registration_service.dart';
import 'package:weather_care/services/settings_sync_service.dart';
import 'package:weather_care/services/weather_service.dart';
import 'package:weather_care/services/region_catalog.dart';

const _seoul = DeviceCoordinates(latitude: 37.57, longitude: 126.98);
const _busan = DeviceCoordinates(latitude: 35.18, longitude: 129.07);

class _Location extends CurrentLocationService {
  LocationResult result =
      const LocationResult(LocationState.ready, coordinates: _seoul);
  final requests = <bool>[];
  Completer<LocationResult>? pending;
  @override
  Future<LocationResult> locate({bool requestPermission = false}) async {
    requests.add(requestPermission);
    return pending == null ? result : await pending!.future;
  }
}

WeatherLoadResult _weather(int nx, int ny) => WeatherLoadResult(
      today: TodayWeatherResponse.fromJson({
        'dataSource': 'test',
        'region': {'nx': nx, 'ny': ny, 'name': '검증 지역 $nx/$ny'},
        'current': {'temperature': 20},
        'brief': '지역별 예보',
      }),
      weekly: WeeklyWeatherResponse.fromJson({'days': []}),
      mode: WeatherLoadMode.server,
      message: 'test',
    );

class _Weather extends WeatherService {
  final calls = <({int nx, int ny, DeviceCoordinates? coordinates})>[];
  Completer<WeatherLoadResult>? pending;
  _Weather()
      : super(ApiClient(baseUrl: ''),
            directKma: KmaDirectWeatherService(serviceKey: ''));
  @override
  Future<WeatherLoadResult> fetchServerWeather(
      {required String installationId,
      int nx = 60,
      int ny = 121,
      DeviceCoordinates? coordinates}) async {
    calls.add((nx: nx, ny: ny, coordinates: coordinates));
    return pending == null ? _weather(nx, ny) : await pending!.future;
  }
}

class _Sync extends SettingsSyncService {
  final calls = <AppSettings>[];
  bool fail = false;
  Completer<void>? pending;
  _Sync() : super(ApiClient(baseUrl: ''));
  @override
  Future<void> save(AppSettings settings) async {
    calls.add(settings);
    if (fail) throw StateError('offline');
    await pending?.future;
  }
}

class _Registration extends NotificationRegistrationService {
  final calls = <({int nx, int ny, DeviceCoordinates? coordinates})>[];
  int invalidated = 0;
  _Registration() : super(ApiClient(baseUrl: ''));
  @override
  Future<void> initialize(
      {required String installationId,
      required int nx,
      required int ny,
      required String locationMode,
      DeviceCoordinates? coordinates}) async {
    calls.add((nx: nx, ny: ny, coordinates: coordinates));
  }

  @override
  Future<void> syncInstallation(
          {required String installationId,
          required int nx,
          required int ny,
          required String locationMode,
          DeviceCoordinates? coordinates}) =>
      initialize(
          installationId: installationId,
          nx: nx,
          ny: ny,
          locationMode: locationMode,
          coordinates: coordinates);
  @override
  void invalidateLocation() {
    invalidated++;
  }
}

void main() {
  late _Location location;
  late _Weather weather;
  late _Sync sync;
  late _Registration registration;
  final catalog = RegionCatalog.fromJson(
      jsonDecode(File('assets/data/kma_regions.json').readAsStringSync())
          as Map<String, dynamic>);
  setUp(() {
    rootBundle.evict('config/kma.config.json');
    rootBundle.evict('assets/data/kma_regions.json');
    SharedPreferences.setMockInitialValues({});
    location = _Location();
    weather = _Weather();
    sync = _Sync();
    registration = _Registration();
  });
  Future<void> start(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
            initialIndex: 4,
            locationService: location,
            weatherService: weather,
            settingsSync: sync,
            regionCatalog: catalog,
            notificationRegistration: registration)));
    // Asset loading and SharedPreferences initialization are asynchronous.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    if (settle) await tester.pumpAndSettle();
  }

  SettingsScreen screen(WidgetTester tester) =>
      tester.widget<SettingsScreen>(find.byType(SettingsScreen));

  testWidgets('권한 거부 시 지역 대체 없이 대기하다 명시적 확인으로 복구한다', (tester) async {
    location.result = const LocationResult(LocationState.denied);
    await start(tester);
    expect(location.requests, [false]);
    expect(weather.calls, isEmpty);
    expect(registration.calls, isEmpty);
    await tester.tap(find.text('Main'));
    await tester.pumpAndSettle();
    expect(find.text('기준 위치를 확인해주세요'), findsOneWidget);
    expect(find.text('날씨 정보 미지원'), findsNothing);
    await tester.tap(find.text('Setting'));
    await tester.pumpAndSettle();
    location.result =
        const LocationResult(LocationState.ready, coordinates: _seoul);
    await screen(tester).onLocate!();
    await tester.pumpAndSettle();
    final grid = KmaGrid.fromCoordinates(
        latitude: _seoul.latitude, longitude: _seoul.longitude);
    expect(location.requests, [false, true]);
    expect(
        (weather.calls.single.nx, weather.calls.single.ny), (grid.nx, grid.ny));
    expect(registration.calls.single.coordinates, _seoul);
    expect(screen(tester).location.state, LocationState.ready);
  });
  testWidgets('새로고침과 앱 복귀는 위치를 다시 읽고 알림 지역도 갱신한다', (tester) async {
    await start(tester);
    location.result =
        const LocationResult(LocationState.ready, coordinates: _busan);
    await screen(tester).onRefresh!();
    await tester.pumpAndSettle();
    expect(weather.calls.last.coordinates, _busan);
    expect(registration.calls.last.coordinates, _busan);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(location.requests, [false, false]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(location.requests, [false, false, false]);
  });
  testWidgets('대략적 위치는 날씨와 알림 양쪽에 정밀 좌표를 보내지 않는다', (tester) async {
    location.result =
        const LocationResult(LocationState.approximate, coordinates: _seoul);
    await start(tester);
    expect(weather.calls.single.coordinates, isNull);
    expect(registration.calls.single.coordinates, isNull);
    expect(screen(tester).location.hasLocation, isTrue);
  });
  testWidgets('서버 설정 저장 실패가 GPS와 지역 변경을 막지 않는다', (tester) async {
    sync.fail = true;
    await start(tester);
    expect(weather.calls, hasLength(1));
    final settings = screen(tester).initialSettings!;
    await screen(tester).onSettingsChanged!(
        settings.copyWith(locationMode: 'MANUAL', currentRegionId: '98_76'));
    await tester.pumpAndSettle();
    expect((weather.calls.last.nx, weather.calls.last.ny), (98, 76));
    expect(weather.calls.last.coordinates, isNull);
  });
  testWidgets('위치 확인 중 수동 전환하면 이전 위치 결과를 버린다', (tester) async {
    final pending = Completer<LocationResult>();
    location.pending = pending;
    await start(tester, settle: false);
    final settings = screen(tester).initialSettings!;
    await screen(tester).onSettingsChanged!(
        settings.copyWith(locationMode: 'MANUAL', currentRegionId: '98_76'));
    pending.complete(
        const LocationResult(LocationState.ready, coordinates: _seoul));
    await tester.pumpAndSettle();
    expect(weather.calls, hasLength(1));
    expect((weather.calls.single.nx, weather.calls.single.ny), (98, 76));
    expect(weather.calls.single.coordinates, isNull);
  });
  testWidgets('늦은 이전 날씨 응답은 새 지역 화면에 적용하지 않는다', (tester) async {
    final pending = Completer<WeatherLoadResult>();
    weather.pending = pending;
    await start(tester, settle: false);
    final settings = screen(tester).initialSettings!;
    await screen(tester).onSettingsChanged!(
        settings.copyWith(locationMode: 'MANUAL', currentRegionId: '98_76'));
    weather.pending = null;
    pending.complete(_weather(60, 127));
    await tester.pumpAndSettle();
    expect(screen(tester).regionName, '검증 지역 98/76');
    expect(registration.calls.last.coordinates, isNull);
  });
  testWidgets('저장한 수동 지역이 없거나 잘못됐으면 조회와 등록을 하지 않는다', (tester) async {
    await const AppSettingsRepository().save(AppSettings.fallback('test')
        .copyWith(locationMode: 'MANUAL', currentRegionId: '0_999'));
    await start(tester);
    expect(location.requests, isEmpty);
    expect(weather.calls, isEmpty);
    expect(registration.calls, isEmpty);
  });
  testWidgets('동시 새로고침은 위치 요청을 하나만 만들고 실패하면 기존 날씨를 지운다', (tester) async {
    await start(tester);
    final pending = Completer<LocationResult>();
    location.pending = pending;
    final callback = screen(tester).onRefresh!;
    final first = callback();
    final second = callback();
    await tester.pump();
    expect(location.requests, hasLength(2));
    pending.complete(const LocationResult(LocationState.serviceDisabled));
    await Future.wait([first, second]);
    await tester.pumpAndSettle();
    expect(weather.calls, hasLength(1));
    expect(screen(tester).regionName, isNull);
    expect(screen(tester).location.state, LocationState.serviceDisabled);
    expect(registration.invalidated, 1);
  });
  testWidgets('시작 시 서버 저장이 지연돼도 GPS를 읽고 설정 저장 순서를 보존한다', (tester) async {
    final pending = Completer<void>();
    sync.pending = pending;
    await start(tester);
    expect(weather.calls, hasLength(1));
    final settings = screen(tester).initialSettings!;
    final saving = screen(tester).onSettingsChanged!(
        settings.copyWith(locationMode: 'MANUAL', currentRegionId: '98_76'));
    await tester.pumpAndSettle();
    expect(weather.calls.last.nx, 98);
    expect(sync.calls, hasLength(1));
    sync.pending = null;
    pending.complete();
    await saving;
    expect(sync.calls.last.locationMode, 'MANUAL');
    expect(sync.calls, hasLength(2));
  });

  testWidgets('선택 지역은 GPS 없이 저장·조회·알림 등록되고 다시 시작해도 복원된다', (tester) async {
    final selected = catalog.search('부산 해운대 좌1동').single;
    await const AppSettingsRepository().save(AppSettings.fallback('test')
        .copyWith(
            locationMode: 'MANUAL',
            currentRegionId: selected.gridId,
            manualRegionKey: selected.key));
    await start(tester);
    expect(location.requests, isEmpty);
    expect((weather.calls.single.nx, weather.calls.single.ny),
        (selected.nx, selected.ny));
    expect(registration.calls.single.coordinates, isNull);
    expect(screen(tester).regionName, selected.fullName);
    expect(screen(tester).manualRegionName, selected.fullName);
    final saved = await const AppSettingsRepository().load('test');
    expect(saved.manualRegionKey, selected.key);
    expect(saved.currentRegionId, selected.gridId);
    await tester.pumpWidget(const SizedBox());
    await start(tester);
    expect(screen(tester).regionName, selected.fullName);
    expect(location.requests, isEmpty);
  });

  testWidgets('GPS로 전환해도 선택 지역을 보존하고 수동 복귀 때 다시 사용한다', (tester) async {
    final selected = catalog.search('제주 우도면').single;
    await start(tester);
    var settings = screen(tester).initialSettings!;
    await screen(tester).onSettingsChanged!(settings.copyWith(
        locationMode: 'MANUAL',
        currentRegionId: selected.gridId,
        manualRegionKey: selected.key));
    await tester.pumpAndSettle();
    expect(screen(tester).regionName, selected.fullName);
    settings = screen(tester).initialSettings!;
    await screen(tester)
        .onSettingsChanged!(settings.copyWith(locationMode: 'GPS'));
    await tester.pumpAndSettle();
    expect(screen(tester).initialSettings!.manualRegionKey, selected.key);
    expect(weather.calls.last.coordinates, _seoul);
    settings = screen(tester).initialSettings!;
    await screen(tester)
        .onSettingsChanged!(settings.copyWith(locationMode: 'MANUAL'));
    await tester.pumpAndSettle();
    expect(screen(tester).regionName, selected.fullName);
    expect(weather.calls.last.coordinates, isNull);
  });

  testWidgets('삭제되거나 변경된 지역 식별자를 이전 격자로 대체하지 않는다', (tester) async {
    await const AppSettingsRepository().save(AppSettings.fallback('test')
        .copyWith(
            locationMode: 'MANUAL',
            currentRegionId: '60_121',
            manualRegionKey: 'removed'));
    await start(tester);
    expect(weather.calls, isEmpty);
    expect(registration.calls, isEmpty);
    expect(screen(tester).regionName, isNull);
  });

  testWidgets('응답 격자가 다르면 선택 지역의 날씨로 바꿔 표시하지 않는다', (tester) async {
    final selected = catalog.search('제주 우도면').single;
    await const AppSettingsRepository().save(AppSettings.fallback('test')
        .copyWith(
            locationMode: 'MANUAL',
            currentRegionId: selected.gridId,
            manualRegionKey: selected.key));
    weather.pending = Completer<WeatherLoadResult>()
      ..complete(_weather(60, 121));
    await start(tester);
    expect(screen(tester).regionName, isNull);
    await tester.tap(find.text('Main'));
    await tester.pumpAndSettle();
    expect(find.textContaining('기준 지역과 다른 날씨 자료'), findsOneWidget);
  });

  testWidgets('같은 격자의 다른 동을 선택해도 선택한 지역명이 갱신된다', (tester) async {
    final group = catalog.regions.where((r) => r.gridId == '60_127').toList();
    final first = group.first;
    final second = group.last;
    await start(tester);
    var settings = screen(tester).initialSettings!;
    await screen(tester).onSettingsChanged!(settings.copyWith(
        locationMode: 'MANUAL',
        currentRegionId: first.gridId,
        manualRegionKey: first.key));
    await tester.pumpAndSettle();
    settings = screen(tester).initialSettings!;
    await screen(tester)
        .onSettingsChanged!(settings.copyWith(manualRegionKey: second.key));
    await tester.pumpAndSettle();
    expect(screen(tester).regionName, second.fullName);
  });
}
