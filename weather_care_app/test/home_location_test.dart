import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/features/home/home_screen.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/models/home_widget_snapshot.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/app_settings_repository.dart';
import 'package:weather_care/services/current_location_service.dart';
import 'package:weather_care/services/gps_region_name_service.dart';
import 'package:weather_care/services/home_widget_service.dart';
import 'package:weather_care/services/kma_grid.dart';
import 'package:weather_care/services/notification_registration_service.dart';
import 'package:weather_care/services/settings_sync_service.dart';
import 'package:weather_care/services/weather_service.dart';
import 'package:weather_care/services/region_catalog.dart';
import 'package:weather_care/services/settings_save_controller.dart';
import 'package:weather_care/services/notification_permission_service.dart';
import 'package:weather_care/services/permission_onboarding_store.dart';
import 'package:weather_care/services/server_data_access.dart';

const _seoul = DeviceCoordinates(latitude: 37.57, longitude: 126.98);
const _busan = DeviceCoordinates(latitude: 35.18, longitude: 129.07);

class _DeletionApi extends ApiClient {
  int deletes = 0;
  _DeletionApi() : super(baseUrl: 'https://example.invalid');
  @override
  Future<Map<String, dynamic>> requestJson(String method, String path,
      {Map<String, String>? query,
      Map<String, String>? headers,
      Map<String, dynamic>? body}) async {
    if (method != 'DELETE') throw StateError('Unexpected request');
    deletes++;
    return {};
  }
}

class _Location extends CurrentLocationService {
  LocationResult result =
      const LocationResult(LocationState.ready, coordinates: _seoul);
  LocationResult? cachedResult;
  final requests = <bool>[];
  final freshRequests = <bool>[];
  Completer<LocationResult>? pending;
  @override
  Future<LocationResult> locate({
    bool requestPermission = false,
    bool forceRefresh = false,
  }) async {
    requests.add(requestPermission);
    freshRequests.add(forceRefresh);
    return pending == null
        ? (!forceRefresh ? cachedResult ?? result : result)
        : await pending!.future;
  }
}

class _GpsRegionName extends GpsRegionNameService {
  String? result;
  final calls = <DeviceCoordinates>[];

  @override
  Future<String?> resolve(DeviceCoordinates coordinates) async {
    calls.add(coordinates);
    return result;
  }
}

WeatherLoadResult _weather(int nx, int ny,
        {String? regionName, String brief = '지역별 예보'}) =>
    WeatherLoadResult(
      today: TodayWeatherResponse.fromJson({
        'dataSource': 'test',
        'region': {'nx': nx, 'ny': ny, 'name': regionName ?? '검증 지역 $nx/$ny'},
        'current': {'temperature': 20},
        'brief': brief,
      }),
      weekly: WeeklyWeatherResponse.fromJson({'days': []}),
      mode: WeatherLoadMode.server,
      message: 'test',
    );

class _Weather extends WeatherService {
  final calls = <({int nx, int ny, DeviceCoordinates? coordinates})>[];
  final comparisonCalls = <({int nx, int ny})>[];
  Completer<WeatherLoadResult>? pending;
  Completer<ComparisonResponse>? comparisonPending;
  bool emitTodayWhilePending = false;
  void Function(WeeklyWeatherResponse)? pendingWeeklyCallback;
  TodayWeatherResponse? mainPreview;
  ComparisonResponse comparison = const ComparisonResponse.unavailable();
  String? regionName;
  WeatherLoadResult? response;
  _Weather() : super(ApiClient(baseUrl: ''));
  @override
  Future<TodayWeatherResponse?> fetchMainWeather({
    int nx = 60,
    int ny = 121,
    String? regionCode,
    String? regionName,
  }) async =>
      mainPreview;

  @override
  Future<ComparisonResponse> fetchYesterdayComparison({
    required String installationId,
    int nx = 60,
    int ny = 121,
  }) async {
    comparisonCalls.add((nx: nx, ny: ny));
    final held = comparisonPending;
    comparisonPending = null;
    return held == null ? comparison : await held.future;
  }

  @override
  Future<WeatherLoadResult> fetchServerWeather(
      {required String installationId,
      int nx = 60,
      int ny = 121,
      DeviceCoordinates? coordinates,
      String? regionCode,
      String? regionName,
      Future<String?>? regionNameFuture,
      void Function(TodayWeatherResponse today)? onToday,
      void Function(WeeklyWeatherResponse weekly)? onWeekly}) async {
    calls.add((nx: nx, ny: ny, coordinates: coordinates));
    final result = response ?? _weather(nx, ny, regionName: regionName);
    if (pending != null) {
      pendingWeeklyCallback = onWeekly;
      if (emitTodayWhilePending) onToday?.call(result.today!);
      return await pending!.future;
    }
    if (result.today case final today?) onToday?.call(today);
    if (result.weekly case final weekly?) onWeekly?.call(weekly);
    return result;
  }
}

class _WidgetService extends HomeWidgetService {
  final published = <HomeWidgetSnapshot>[];

  @override
  Future<void> publish(
    HomeWidgetSnapshot snapshot, {
    String? refreshUrl,
    bool gpsEnabled = false,
  }) async {
    published.add(snapshot);
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

class _NotificationPermission extends NotificationPermissionService {
  NotificationPermissionState result = NotificationPermissionState.denied;
  final requests = <bool>[];
  Completer<NotificationPermissionState>? pending;
  bool opened = false;
  @override
  Future<NotificationPermissionState> read({bool request = false}) async {
    requests.add(request);
    final held = pending;
    pending = null;
    return held == null ? result : await held.future;
  }

  @override
  Future<bool> openSettings() async => opened;
}

void main() {
  late _Location location;
  late _GpsRegionName gpsRegionName;
  late _Weather weather;
  late _Sync sync;
  late _Registration registration;
  late _NotificationPermission notificationPermission;
  final catalog = RegionCatalog.fromJson(
      jsonDecode(File('assets/data/kma_regions.json').readAsStringSync())
          as Map<String, dynamic>);
  setUp(() {
    rootBundle.evict('config/kma.config.json');
    rootBundle.evict('assets/data/kma_regions.json');
    SharedPreferences.setMockInitialValues({
      PermissionOnboardingStore.storageKey: true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    location = _Location();
    gpsRegionName = _GpsRegionName();
    weather = _Weather();
    sync = _Sync();
    registration = _Registration();
    notificationPermission = _NotificationPermission();
  });
  Future<void> start(WidgetTester tester,
      {bool settle = true,
      ServerDataAccess? access,
      HomeWidgetService? widgetService,
      int initialIndex = 4,
      VoidCallback? onHomeReady,
      DateTime Function()? now}) async {
    await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
            serverDataAccess: access,
            initialIndex: initialIndex,
            locationService: location,
            gpsRegionNameService: gpsRegionName,
            weatherService: weather,
            homeWidgetService: widgetService ?? const HomeWidgetService(),
            settingsSync: sync,
            regionCatalog: catalog,
            onHomeReady: onHomeReady,
            now: now,
            notificationPermission: notificationPermission,
            notificationRegistration: registration)));
    // Asset loading and SharedPreferences initialization are asynchronous.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    if (settle) await tester.pumpAndSettle();
  }

  SettingsScreen screen(WidgetTester tester) =>
      tester.widget<SettingsScreen>(find.byType(SettingsScreen));

  testWidgets('첫 안내 확인 한 번으로 알림과 위치 권한을 차례대로 요청한다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await start(tester, settle: false, initialIndex: 2);

    expect(find.byKey(const ValueKey('permission-onboarding-dialog')),
        findsOneWidget);
    expect(notificationPermission.requests, isEmpty);
    expect(location.requests, isEmpty);

    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('permission-onboarding-confirm')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(notificationPermission.requests, [true]);
    expect(location.requests, [true]);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(PermissionOnboardingStore.storageKey), isTrue);
    expect(find.byKey(const ValueKey('permission-onboarding-dialog')),
        findsNothing);
  });

  testWidgets('첫 안내에서 계속을 누르기 전에는 재개·새로고침에도 위치 권한을 요청하지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    location.result = const LocationResult(LocationState.denied);

    await start(tester, settle: false, initialIndex: 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('permission-onboarding-dialog')),
        findsOneWidget);
    expect(location.requests, isNot(contains(true)));

    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('permission-onboarding-confirm')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(location.requests, contains(true));
  });

  testWidgets('오늘 자료가 먼저 오면 주간 조회를 기다리지 않고 Main을 표시한다', (tester) async {
    weather.pending = Completer<WeatherLoadResult>();
    weather.emitTodayWhilePending = true;

    await start(tester, settle: false, initialIndex: 2);

    expect(find.byKey(const ValueKey('main-tab')), findsOneWidget);
    expect(find.textContaining('지금 날씨'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('first-load-duration-guide')), findsNothing);

    weather.pending!.complete(_weather(60, 127));
    await tester.pumpAndSettle();
  });

  testWidgets('오늘 자료가 먼저 와도 전체 새로고침 중에는 기본 브리핑을 표시하지 않는다', (tester) async {
    weather.pending = Completer<WeatherLoadResult>();
    weather.emitTodayWhilePending = true;
    weather.response = _weather(60, 127, brief: '최신 날씨를 확인해 주세요.');
    final comparison = Completer<ComparisonResponse>();
    weather.comparisonPending = comparison;

    await start(tester, settle: false, initialIndex: 2);

    final brief = find.byKey(const ValueKey('main-weather-brief'));
    expect(tester.widget<Text>(brief).data, '불러오는 중');
    weather.pending!.complete(_weather(60, 127, brief: '오늘은 맑아요.'));
    await tester.pump();
    expect(tester.widget<Text>(brief).data, '불러오는 중');
    comparison.complete(const ComparisonResponse.unavailable());
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(brief).data, '오늘은 맑아요.');
  });

  testWidgets('부분 응답이 먼저 와도 Main·Today·Week의 날씨 값은 완료 후 표시한다', (tester) async {
    final widgetService = _WidgetService();
    final result = WeatherLoadResult(
      today: TodayWeatherResponse.fromJson({
        'region': {'nx': 60, 'ny': 127, 'name': '검증 지역'},
        'brief': '맑고 포근해요.',
        'current': {
          'temperature': 23,
          'apparentTemperature': 21,
          'skyCondition': '맑음',
        },
        'nextForecast': {
          'temperature': 25,
          'forecastAt': '2026-10-01T14:00:00+09:00',
        },
      }),
      weekly: WeeklyWeatherResponse.fromJson({
        'days': [
          {
            'date': '목',
            'forecastDate': '2026-10-01',
            'min': 15,
            'max': 35,
          },
        ],
      }),
      mode: WeatherLoadMode.server,
      message: '운영 서버 연결',
    );
    weather.response = result;
    weather.pending = Completer<WeatherLoadResult>();
    weather.emitTodayWhilePending = true;

    await start(tester,
        settle: false,
        initialIndex: 2,
        widgetService: widgetService,
        now: () => DateTime(2026, 10, 1, 13));

    expect(find.text('23.0℃'), findsNothing);
    expect(find.text('21.0℃'), findsNothing);
    expect(find.text('--°'), findsWidgets);
    expect(widgetService.published, isEmpty);
    await tester.tap(find.text('Today'));
    await tester.pump();
    expect(find.text('23.0℃'), findsNothing);
    expect(find.text('--°'), findsWidgets);

    weather.pendingWeeklyCallback?.call(result.weekly!);
    await tester.pump();
    expect(widgetService.published, isEmpty);
    await tester.tap(find.text('Week'));
    await tester.pump();
    expect(find.text('35℃'), findsNothing);

    weather.pending!.complete(result);
    await tester.pumpAndSettle();
    expect(find.text('35℃'), findsWidgets);
    expect(widgetService.published, hasLength(1));
    await tester.tap(find.text('Main'));
    await tester.pump();
    expect(find.text('23.0℃'), findsOneWidget);
    expect(find.text('21.0℃'), findsOneWidget);
  });

  testWidgets('핵심 날씨만 도착한 동안 빈 항목은 불러오는 중으로 표시한다', (tester) async {
    weather.mainPreview = _weather(60, 127).today;
    weather.pending = Completer<WeatherLoadResult>();

    await start(tester, settle: false, initialIndex: 2);

    expect(find.text('오늘 날씨 자료를 불러오고 있어요.'), findsOneWidget);
    expect(find.text('불러오는 중'), findsWidgets);
    await tester.dragUntilVisible(
      find.text('미래 예상 날씨를 불러오고 있어요'),
      find.byKey(const ValueKey('main-tab')),
      const Offset(0, -200),
    );
    expect(find.text('미래 예상 날씨를 불러오고 있어요'), findsOneWidget);

    weather.pending!.complete(_weather(60, 127));
    await tester.pumpAndSettle();

    expect(find.text('오늘 날씨 자료를 불러오고 있어요.'), findsNothing);
    expect(find.text('불러오는 중'), findsNothing);
    expect(find.text('자료 없음'), findsWidgets);
  });

  testWidgets('자료 대기 중 Today·Detail·Week도 로딩 문구를 표시한다', (tester) async {
    weather.mainPreview = _weather(60, 127).today;
    weather.pending = Completer<WeatherLoadResult>();
    await start(tester, settle: false, initialIndex: 0);

    expect(find.text('오늘 날씨 자료를 불러오고 있어요.'), findsOneWidget);
    expect(find.text('불러오는 중'), findsWidgets);
    expect(find.text('시간별 예보를 불러오고 있어요.'), findsOneWidget);

    await tester.tap(find.text('Detail'));
    await tester.pump();
    expect(find.text('상세 날씨 자료를 불러오고 있어요.'), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pump();
    expect(find.text('주간 자료를 불러오고 있어요'), findsOneWidget);

    weather.pending!.complete(_weather(60, 127));
    await tester.pumpAndSettle();
  });

  testWidgets('Main 콘텐츠가 준비된 뒤 홈 준비 완료를 한 번만 알린다', (tester) async {
    var readyCount = 0;
    weather.pending = Completer<WeatherLoadResult>();

    await start(
      tester,
      settle: false,
      initialIndex: 2,
      onHomeReady: () => readyCount += 1,
    );
    expect(readyCount, 0);

    weather.pending!.complete(_weather(60, 127));
    await tester.pumpAndSettle();
    expect(readyCount, 1);

    await tester.pump();
    expect(readyCount, 1);
  });

  testWidgets('탭 스와이프 새로고침이 서버 실패하면 기존 자료와 팝업을 유지한다', (tester) async {
    await start(tester, initialIndex: 2);
    final originalRegion = find.text('현재 위치 날씨');
    expect(originalRegion, findsOneWidget);
    weather.response = const WeatherLoadResult(
      today: null,
      weekly: null,
      mode: WeatherLoadMode.unavailable,
      message: '운영 서버에 연결하지 못했습니다.',
    );

    await tester.drag(
      find.byKey(const ValueKey('main-tab')),
      const Offset(0, 320),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('날씨 자료를 새로고침하지 못했어요'), findsOneWidget);
    expect(find.textContaining('현재 화면의 기존 자료는 유지'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(originalRegion, findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(originalRegion, findsOneWidget);
    expect(
      find.text('오늘 날씨 자료를 서버에서 불러오지 못했어요. 이전 자료가 표시될 수 있어요.'),
      findsOneWidget,
    );
    expect(find.text('서버 연결 실패'), findsWidgets);

    await tester.tap(find.text('Today'));
    await tester.pump();
    expect(
      find.text('오늘 날씨 자료를 서버에서 불러오지 못했어요. 이전 자료가 표시될 수 있어요.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Detail'));
    await tester.pump();
    expect(
      find.text('상세 날씨 자료를 서버에서 불러오지 못했어요. 이전 자료가 표시될 수 있어요.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Week'));
    await tester.pump();
    expect(
      find.text('주간 날씨 자료를 서버에서 불러오지 못했어요. 이전 자료가 표시될 수 있어요.'),
      findsOneWidget,
    );
  });

  for (final tab in <({int index, String key})>[
    (index: 0, key: 'today-tab'),
    (index: 1, key: 'detail-tab'),
    (index: 2, key: 'main-tab'),
    (index: 3, key: 'week-tab'),
  ]) {
    testWidgets('${tab.key} 새로고침은 오늘·주간·비교 자료를 모두 받을 때까지 기다린다', (tester) async {
      await start(tester, initialIndex: tab.index);
      final weatherCalls = weather.calls.length;
      final comparisonCalls = weather.comparisonCalls.length;
      final pending = Completer<ComparisonResponse>();
      weather.comparisonPending = pending;

      final indicator = tester.widget<RefreshIndicator>(find.ancestor(
        of: find.byKey(ValueKey(tab.key)),
        matching: find.byType(RefreshIndicator),
      ));
      var completed = false;
      final refresh =
          indicator.onRefresh().whenComplete(() => completed = true);
      for (var i = 0; i < 10 && weather.calls.length == weatherCalls; i++) {
        await tester.pump();
      }

      expect(weather.calls.length, weatherCalls + 1);
      expect(weather.comparisonCalls.length, comparisonCalls + 1);
      expect(location.freshRequests.last, isTrue);
      expect(completed, isFalse);

      pending.complete(const ComparisonResponse.unavailable());
      await refresh;
      await tester.pump();
      expect(completed, isTrue);
    });
  }

  testWidgets('한국시간 정시가 되면 현재 탭과 관계없이 전체 날씨를 다시 받는다', (tester) async {
    var now = DateTime.parse('2026-09-21T22:59:50Z');
    await start(tester, initialIndex: 3, now: () => now);
    final weatherCalls = weather.calls.length;
    final comparisonCalls = weather.comparisonCalls.length;

    now = DateTime.parse('2026-09-21T23:00:00Z');
    await tester.pump(const Duration(seconds: 10));
    for (var i = 0; i < 10 && weather.calls.length == weatherCalls; i++) {
      await tester.pump();
    }

    expect(weather.calls.length, weatherCalls + 1);
    expect(weather.comparisonCalls.length, comparisonCalls + 1);
  });

  testWidgets('탭 스와이프에서 일부 자료만 받아도 부분 실패 팝업을 표시한다', (tester) async {
    await start(tester, initialIndex: 3);
    weather.response = WeatherLoadResult(
      today: _weather(60, 127).today,
      weekly: null,
      mode: WeatherLoadMode.server,
      message: '일부 날씨 자료만 연결됐습니다.',
    );

    await tester.drag(
      find.byKey(const ValueKey('week-tab')),
      const Offset(0, 320),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('날씨 자료를 모두 새로고침하지 못했어요'), findsOneWidget);
    expect(find.textContaining('일부 자료만 새로 받았어요'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const ValueKey('week-tab')), findsOneWidget);
  });

  testWidgets('Main은 현재 격자의 어제 비교 자료를 별도 조회해 표시한다', (tester) async {
    weather.comparison = const ComparisonResponse(
      comparisonAvailable: true,
      current: ComparisonWeatherSnapshot(temperature: 20),
      comparison: ComparisonWeatherSnapshot(temperature: 18),
    );

    await start(tester, initialIndex: 2);

    expect(weather.comparisonCalls, [(nx: 60, ny: 127)]);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('yesterday-comparison-card')),
      find.byKey(const ValueKey('main-tab')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('기온은 어제보다 2.0℃ 높아요.'), findsOneWidget);
  });

  testWidgets('경량 자료가 먼저 오면 전체 Today 전에 Main 핵심 카드를 표시한다', (tester) async {
    final widgetService = _WidgetService();
    weather.mainPreview = _weather(60, 127).today;
    weather.pending = Completer<WeatherLoadResult>();

    await start(tester,
        settle: false, initialIndex: 2, widgetService: widgetService);

    expect(find.byKey(const ValueKey('main-tab')), findsOneWidget);
    expect(widgetService.published, isEmpty);
    expect(weather.pendingWeeklyCallback, isNotNull);
    weather.pendingWeeklyCallback?.call(_weather(60, 127).weekly!);
    await tester.pump();
    expect(widgetService.published, isEmpty);
    await tester.dragUntilVisible(
      find.text('Check List를 불러오고 있어요'),
      find.byKey(const ValueKey('main-tab')),
      const Offset(0, -200),
    );
    await tester.pump();
    expect(find.text('Check List를 불러오고 있어요'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('시간별 자료를 불러오고 있어요'),
      find.byKey(const ValueKey('main-tab')),
      const Offset(0, -200),
    );
    await tester.pump();
    expect(find.text('시간별 자료를 불러오고 있어요'), findsOneWidget);

    weather.pending!.complete(_weather(60, 127));
    await tester.pumpAndSettle();
    expect(find.text('Check List를 불러오고 있어요'), findsNothing);
    expect(widgetService.published, isNotEmpty);
  });

  testWidgets('실제 삭제 콜백 후 복귀·새로고침·설정 변경으로 서버에 다시 등록하지 않는다', (tester) async {
    var stored = jsonEncode({
      'mode': 'active',
      'serverId': 'wc_fixture_server_1234567890',
      'secret': 'a' * 64
    });
    final api = _DeletionApi();
    final access = ServerDataAccess(
        api: api,
        legacyInstallationId: 'wc_fixture_local_1234567890',
        readStore: () async => stored,
        writeStore: (value) async {
          stored = value;
        });
    addTearDown(access.dispose);
    await const AppSettingsRepository().save(AppSettings.fallback('test')
        .copyWith(
            locationMode: 'MANUAL',
            currentRegionId: '98_76',
            notificationTime: '06:35',
            umbrellaEnabled: false));
    await start(tester, access: access);
    final registrations = registration.calls.length;
    final settingsWrites = sync.calls.length;
    await screen(tester).onDeleteServerData!();
    await tester.pumpAndSettle();
    expect(api.deletes, 1);
    expect(access.mode, ServerDataMode.deleted);
    expect(screen(tester).saveState, SettingsSaveState.localOnly);
    final saved = await const AppSettingsRepository().load('test');
    expect(saved.notificationEnabled, false);
    expect(saved.currentRegionId, '98_76');
    expect(saved.notificationTime, '06:35');
    expect(saved.umbrellaEnabled, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await screen(tester).onRefresh!();
    await screen(tester)
        .onSettingsChanged!(saved.copyWith(notificationEnabled: true));
    await tester.pumpAndSettle();
    expect(registration.calls.length, registrations);
    expect(sync.calls.length, settingsWrites);
    expect(screen(tester).initialSettings!.notificationEnabled, false);
    expect(jsonDecode(stored)['mode'], 'deleted');
  });

  testWidgets('서버 저장 실패 표시와 최신 설정 재시도를 연결한다', (tester) async {
    sync.fail = true;
    await start(tester);
    expect(screen(tester).saveState, SettingsSaveState.serverFailed);
    final latest =
        screen(tester).initialSettings!.copyWith(notificationEnabled: false);
    await screen(tester).onSettingsChanged!(latest);
    await tester.pumpAndSettle();
    expect(screen(tester).saveState, SettingsSaveState.serverFailed);
    expect(
        (await const AppSettingsRepository().load('test')).notificationEnabled,
        false);
    sync.fail = false;
    await screen(tester).onRetrySave!();
    await tester.pumpAndSettle();
    expect(sync.calls.last.notificationEnabled, false);
    expect(screen(tester).saveState, SettingsSaveState.saved);
  });

  testWidgets('수동 지역에서도 복귀 시 알림 권한을 읽고 등록을 갱신한다', (tester) async {
    await const AppSettingsRepository().save(AppSettings.fallback('test')
        .copyWith(locationMode: 'MANUAL', currentRegionId: '98_76'));
    await start(tester);
    expect(screen(tester).notificationPermission,
        NotificationPermissionState.denied);
    expect(notificationPermission.requests, [false]);
    final initialRegistrations = registration.calls.length;
    notificationPermission.result = NotificationPermissionState.authorized;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(screen(tester).notificationPermission,
        NotificationPermissionState.authorized);
    expect(notificationPermission.requests, [false, false]);
    expect(registration.calls.length, initialRegistrations + 1);
    expect(registration.calls.last.nx, 98);
    expect(location.requests, isEmpty);
  });

  testWidgets('위치가 없어도 명시적으로 알림 권한을 요청하고 중복 요청을 막는다', (tester) async {
    location.result = const LocationResult(LocationState.denied);
    await start(tester);
    final held = Completer<NotificationPermissionState>();
    notificationPermission.pending = held;
    final request = screen(tester).onRequestNotificationPermission!();
    final duplicate = screen(tester).onRequestNotificationPermission!();
    await tester.pump();
    notificationPermission.result = NotificationPermissionState.authorized;
    held.complete(NotificationPermissionState.authorized);
    await Future.wait([request, duplicate]);
    await tester.pumpAndSettle();
    expect(notificationPermission.requests.where((ask) => ask), hasLength(1));
    expect(screen(tester).notificationPermission,
        NotificationPermissionState.authorized);
    expect(registration.calls, isEmpty);
    expect(location.requests, [false]);
  });

  testWidgets('권한 조회 대기 중 복귀하면 이전 상태를 다시 확인한다', (tester) async {
    await start(tester);
    final held = Completer<NotificationPermissionState>();
    notificationPermission.pending = held;
    final reading = screen(tester).onRefreshNotificationPermission!();
    await tester.pump();
    notificationPermission.result = NotificationPermissionState.authorized;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    held.complete(NotificationPermissionState.denied);
    await reading;
    await tester.pumpAndSettle();
    expect(screen(tester).notificationPermission,
        NotificationPermissionState.authorized);
  });

  testWidgets('기기 알림 설정 열기 실패를 안내한다', (tester) async {
    await start(tester);
    await screen(tester).onOpenNotificationSettings!();
    await tester.pump();
    expect(find.textContaining('설정을 열지 못했어요.\n기기 설정에서 날씨챙겨'), findsOneWidget);
  });

  testWidgets('날씨 요청 대기가 설정 저장 완료와 다음 변경을 막지 않는다', (tester) async {
    await start(tester);
    weather.pending = Completer<WeatherLoadResult>();
    await screen(tester).onSettingsChanged!(
        screen(tester).initialSettings!.copyWith(umbrellaEnabled: false));
    await tester.pump();
    expect(screen(tester).saveState, SettingsSaveState.saved);
    await screen(tester).onSettingsChanged!(
        screen(tester).initialSettings!.copyWith(notificationEnabled: false));
    await tester.pump();
    expect(screen(tester).saveState, SettingsSaveState.saved);
    expect(sync.calls.last.notificationEnabled, false);
    weather.pending!.complete(_weather(60, 127));
    await tester.pumpAndSettle();
  });

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
    expect(
        find.byKey(const ValueKey('location-primary-action')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('manual-location-action')), findsOneWidget);
    location.result =
        const LocationResult(LocationState.ready, coordinates: _seoul);
    await tester.tap(find.byKey(const ValueKey('location-primary-action')));
    await tester.pumpAndSettle();
    final grid = KmaGrid.fromCoordinates(
        latitude: _seoul.latitude, longitude: _seoul.longitude);
    expect(location.requests, [false, true]);
    expect(
        (weather.calls.single.nx, weather.calls.single.ny), (grid.nx, grid.ny));
    expect(registration.calls.single.coordinates, _seoul);
    await tester.tap(find.text('Setting'));
    await tester.pumpAndSettle();
    expect(screen(tester).location.state, LocationState.ready);
  });
  testWidgets('위치를 확인하지 못하면 수동 지역 메뉴로 이동할 수 있다', (tester) async {
    location.result = const LocationResult(LocationState.denied);
    await start(tester, initialIndex: 2);

    await tester.tap(find.byKey(const ValueKey('manual-location-action')));
    await tester.pumpAndSettle();

    final navigation = tester.widget<NavigationBar>(
        find.byKey(const ValueKey('main-bottom-navigation')));
    expect(navigation.selectedIndex, 4);
    expect(find.text('지역 선택'), findsOneWidget);
  });
  testWidgets('선택한 항목의 근거는 다른 탭으로 이동하면 초기화된다', (tester) async {
    weather.response = WeatherLoadResult(
      today: TodayWeatherResponse.fromJson({
        'dataSource': 'test',
        'region': {'nx': 60, 'ny': 127, 'name': '서울'},
        'current': {'temperature': 20},
        'brief': '비 예보가 있어요',
        'recommendations': [
          {
            'type': 'UMBRELLA',
            'recommended': true,
            'priority': 90,
            'title': '우산이 필요해요',
            'description': '오후에 비가 와요.',
            'notificationEligible': true,
          },
        ],
        'lifestyleMessages': [
          {
            'type': 'RAIN_GEAR_USEFUL',
            'title': '우산을 챙겨요',
            'priority': 90,
            'parts': [
              {'role': 'APP_SUGGESTION', 'text': '우산을 챙겨요'},
              {'role': 'OFFICIAL_FACT', 'text': '오후에 비가 예보됐어요'},
            ],
          },
        ],
      }),
      weekly: WeeklyWeatherResponse.fromJson({'days': []}),
      mode: WeatherLoadMode.server,
      message: 'test',
    );
    await start(tester, initialIndex: 2);

    final detailButton = find.byKey(const ValueKey('bag-detail-umbrella'));
    await tester.scrollUntilVisible(
      detailButton,
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('main-tab')),
        matching: find.byType(Scrollable),
      ),
    );
    tester.widget<IconButton>(detailButton).onPressed!.call();
    await tester.pumpAndSettle();
    expect(find.text('선택한 항목의 근거'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detail'));
    await tester.pumpAndSettle();

    expect(find.text('선택한 항목의 근거'), findsNothing);
    expect(find.text('우산을 챙겨요'), findsWidgets);
  });
  testWidgets('GPS 응답의 선택 지역 임시명은 현재 위치로 표시한다', (tester) async {
    weather.regionName = '선택 지역';
    await start(tester);
    expect(screen(tester).regionName, '현재 위치');

    await tester.tap(find.text('Main'));
    await tester.pumpAndSettle();
    expect(find.text('현재 위치 날씨'), findsOneWidget);
    expect(find.text('선택 지역 날씨'), findsNothing);
  });
  testWidgets('정밀 GPS 역지오코딩 지역명을 동까지 표시한다', (tester) async {
    gpsRegionName.result = '서울 강남구 역삼동';
    await start(tester);
    expect(gpsRegionName.calls, [_seoul]);
    expect(screen(tester).regionName, '서울 강남구 역삼동');

    await tester.tap(find.text('Main'));
    await tester.pumpAndSettle();
    expect(find.text('서울 강남구 역삼동 날씨'), findsOneWidget);
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
    location.cachedResult =
        const LocationResult(LocationState.ready, coordinates: _busan);
    location.result =
        const LocationResult(LocationState.ready, coordinates: _seoul);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(location.requests, [false, false, false]);
    expect(location.freshRequests, [false, true, true]);
    expect(weather.calls.last.coordinates, _seoul);
    expect(registration.calls.last.coordinates, _seoul);
  });
  testWidgets('지역 선택의 위치 다시 확인은 새 위치를 읽고 열린 화면을 갱신한다', (tester) async {
    gpsRegionName.result = '서울 강남구 역삼동';
    await start(tester);
    await tester.tap(find.byKey(const ValueKey('location-settings-menu')));
    await tester.pumpAndSettle();
    expect(find.text('서울 강남구 역삼동 기준으로 지역 예보를 안내해요'), findsOneWidget);

    location.result =
        const LocationResult(LocationState.ready, coordinates: _busan);
    gpsRegionName.result = '부산 해운대구 우동';
    await tester.tap(find.byKey(const ValueKey('location-refresh')));
    await tester.pumpAndSettle();

    expect(location.freshRequests.last, isTrue);
    expect(weather.calls.last.coordinates, _busan);
    expect(find.text('부산 해운대구 우동 기준으로 지역 예보를 안내해요'), findsOneWidget);
  });
  testWidgets('대략적 위치는 날씨와 알림 양쪽에 정밀 좌표를 보내지 않는다', (tester) async {
    location.result =
        const LocationResult(LocationState.approximate, coordinates: _seoul);
    await start(tester);
    expect(weather.calls.single.coordinates, isNull);
    expect(registration.calls.single.coordinates, isNull);
    expect(gpsRegionName.calls, isEmpty);
    expect(screen(tester).regionName, '현재 위치');
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
    expect(find.textContaining('선택한 지역과 다른 날씨 자료'), findsOneWidget);
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
