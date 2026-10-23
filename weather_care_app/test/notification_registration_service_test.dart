import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/current_location_service.dart';
import 'package:weather_care/services/notification_registration_service.dart';

class _Permission implements NotificationSettings {
  @override
  final AuthorizationStatus authorizationStatus;
  _Permission(this.authorizationStatus);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Messaging implements FirebaseMessaging {
  final tokens = StreamController<String>.broadcast();
  AuthorizationStatus authorization = AuthorizationStatus.authorized;
  Completer<NotificationSettings>? pendingPermission;
  String? apnsToken;
  int apnsAvailableAfter = 1;
  int apnsReads = 0;
  int tokenRequests = 0;
  Object? tokenError;
  int requests = 0;
  @override
  Stream<String> get onTokenRefresh => tokens.stream;
  @override
  Future<String?> getToken(
      {String? vapidKey, String? serviceWorkerScriptPath}) async {
    tokenRequests++;
    if (tokenError != null) throw tokenError!;
    return 'test-token';
  }

  @override
  Future<String?> getAPNSToken() async {
    apnsReads++;
    return apnsReads >= apnsAvailableAfter ? apnsToken : null;
  }

  @override
  Future<NotificationSettings> getNotificationSettings() async {
    final pending = pendingPermission;
    pendingPermission = null;
    return pending == null ? _Permission(authorization) : await pending.future;
  }

  @override
  Future<NotificationSettings> requestPermission(
      {bool alert = true,
      bool announcement = false,
      bool badge = true,
      bool carPlay = false,
      bool criticalAlert = false,
      bool provisional = false,
      bool sound = true,
      bool providesAppNotificationSettings = false}) async {
    requests++;
    return _Permission(authorization);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client extends ApiClient {
  final calls = <({Map<String, dynamic> body, Map<String, String>? query})>[];
  Completer<void>? pending;
  bool fail = false;
  Object? error;
  int active = 0;
  int maxActive = 0;
  _Client() : super(baseUrl: '');
  @override
  Future<void> putJson(String path, Map<String, dynamic> body,
      {Map<String, String>? query}) async {
    calls.add((body: body, query: query));
    active++;
    if (active > maxActive) maxActive = active;
    try {
      if (fail) throw StateError('offline');
      if (error != null) throw error!;
      await pending?.future;
    } finally {
      active--;
    }
  }
}

void main() {
  late _Messaging messaging;
  late _Client client;
  late NotificationRegistrationService service;
  late List<String> events;
  late int apnsRegistrationRequests;
  setUp(() {
    messaging = _Messaging();
    client = _Client();
    events = [];
    apnsRegistrationRequests = 0;
    service = NotificationRegistrationService(client,
        messaging: messaging,
        diagnosticLog: events.add,
        readAppVersion: () async => '1.2.0+120',
        registerForRemoteNotifications: () async {
          apnsRegistrationRequests++;
        },
        apnsRetryDelay: Duration.zero);
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await service.dispose();
    await messaging.tokens.close();
  });
  Future<void> initialize() => service.initialize(
      installationId: 'test',
      nx: 60,
      ny: 127,
      locationMode: 'GPS',
      coordinates: const DeviceCoordinates(latitude: 37.57, longitude: 126.98));
  Future<void> moved() => service.syncInstallation(
      installationId: 'test',
      nx: 98,
      ny: 76,
      locationMode: 'GPS',
      coordinates: const DeviceCoordinates(latitude: 35.18, longitude: 129.07));
  Future<void> flush() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('FCM 토큰 갱신은 앱 시작 위치가 아니라 마지막 확인 위치로 등록한다', () async {
    await initialize();
    await moved();
    messaging.tokens.add('refreshed-token');
    await flush();
    expect(client.calls, hasLength(3));
    expect(client.calls.last.query, {'nx': '98', 'ny': '76'});
    expect(client.calls.last.body['latitude'], 35.18);
    expect(client.calls.last.body['fcmToken'], 'refreshed-token');
    expect(client.calls.last.body['minimumAgeConfirmed'], isTrue);
    expect(client.calls.last.body['agePolicyVersion'], 1);
    expect(client.calls.last.body['appVersion'], '1.2.0+120');
  });

  test('버전 조회 실패도 FCM·위치 등록을 막지 않는다', () async {
    await service.dispose();
    service = NotificationRegistrationService(client,
        messaging: messaging,
        readAppVersion: () async => throw StateError('unavailable'));
    await initialize();
    expect(client.calls, hasLength(1));
    expect(client.calls.single.body.containsKey('appVersion'), isFalse);
    expect(client.calls.single.body['fcmToken'], 'test-token');
  });

  test('서버 삭제 중지 상태면 토큰 갱신·앱 복귀로 다시 등록하지 않는다', () async {
    await service.dispose();
    var allowed = true;
    service = NotificationRegistrationService(client,
        messaging: messaging,
        canRegister: () => allowed,
        diagnosticLog: events.add);
    await initialize();
    expect(client.calls, hasLength(1));
    allowed = false;
    messaging.tokens.add('late-token');
    await moved();
    await initialize();
    await flush();
    expect(client.calls, hasLength(1));
  });

  test('권한 응답을 기다리던 등록도 삭제 중지 상태를 다시 확인한다', () async {
    await service.dispose();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var allowed = true;
    service = NotificationRegistrationService(client,
        messaging: messaging,
        canRegister: () => allowed,
        diagnosticLog: events.add,
        registerForRemoteNotifications: () async {
          apnsRegistrationRequests++;
        },
        apnsRetryDelay: Duration.zero);
    final pending = Completer<NotificationSettings>();
    messaging.pendingPermission = pending;
    final work = initialize();
    await flush();
    allowed = false;
    pending.complete(_Permission(AuthorizationStatus.authorized));
    await work;
    expect(client.calls, isEmpty);
    expect(apnsRegistrationRequests, 0);
  });
  test('대략적 위치로 바뀌면 기존 정밀 좌표를 null로 갱신한다', () async {
    await initialize();
    await service.syncInstallation(
        installationId: 'test', nx: 98, ny: 76, locationMode: 'GPS');
    expect(client.calls.last.body['latitude'], isNull);
    expect(client.calls.last.body['longitude'], isNull);
    expect(client.calls.last.query, {'nx': '98', 'ny': '76'});
  });
  test('위치 확인 실패 후 토큰 갱신은 이전 좌표를 다시 보내지 않는다', () async {
    await initialize();
    service.invalidateLocation();
    expect(events, contains('skip:no_location'));
    messaging.tokens.add('refreshed-token');
    await flush();
    expect(client.calls, hasLength(1));
    await moved();
    expect(client.calls, hasLength(2));
  });
  test('이전 요청이 지연돼도 등록은 직렬화되어 최신 지역으로 끝난다', () async {
    final pending = Completer<void>();
    client.pending = pending;
    final first = initialize();
    await flush();
    final latest = moved();
    await flush();
    expect(client.calls, hasLength(1));
    client.pending = null;
    pending.complete();
    await Future.wait([first, latest]);
    expect(client.maxActive, 1);
    expect(client.calls.last.query, {'nx': '98', 'ny': '76'});
  });
  test('초기 알림 권한 대기 중 위치가 바뀌어도 이전 위치를 등록하지 않는다', () async {
    final pending = Completer<NotificationSettings>();
    messaging.pendingPermission = pending;
    final first = initialize();
    await flush();
    final moving = moved();
    pending.complete(_Permission(AuthorizationStatus.authorized));
    await Future.wait([first, moving]);
    expect(client.calls.every((call) => call.query?['nx'] == '98'), isTrue);
  });
  test('등록 실패 후 다시 동기화할 수 있고 종료 후에는 등록하지 않는다', () async {
    client.fail = true;
    await initialize();
    client.fail = false;
    await moved();
    expect(client.calls, hasLength(2));
    await service.dispose();
    messaging.tokens.add('after-dispose');
    await moved();
    await flush();
    expect(client.calls, hasLength(2));
  });
  test('알림 권한이 없으면 토큰 없이 지역만 등록한다', () async {
    messaging.authorization = AuthorizationStatus.denied;
    await initialize();
    expect(client.calls.single.body['fcmToken'], isNull);
    expect(client.calls.single.query, {'nx': '60', 'ny': '127'});
    expect(messaging.requests, 0);
  });
  test('OS에서 차단 후 토큰 갱신이 와도 토큰을 등록하지 않는다', () async {
    await initialize();
    messaging.authorization = AuthorizationStatus.deniedPermanently;
    messaging.tokens.add('blocked-token');
    await flush();
    expect(client.calls.last.body['fcmToken'], isNull);
    expect(messaging.requests, 0);
  });
  test('등록 대기 중 권한이 바뀌면 대기 중인 토큰에도 최신 권한을 적용한다', () async {
    await initialize();
    final pending = Completer<void>();
    client.pending = pending;
    final moving = moved();
    await flush();
    messaging.tokens.add('queued-token');
    await flush();
    messaging.authorization = AuthorizationStatus.denied;
    client.pending = null;
    pending.complete();
    await moving;
    await flush();
    expect(client.calls.last.body['fcmToken'], isNull);
    expect(client.maxActive, 1);
    messaging.authorization = AuthorizationStatus.authorized;
    await moved();
    expect(client.calls.last.body['fcmToken'], 'test-token');
  });

  test('iOS APNs 미발급이면 FCM 조회와 서버 등록을 건너뛴다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await initialize();

    expect(events.first, 'service:ready');
    expect(
        events,
        containsAllInOrder([
          'start',
          'permission:authorized',
          'apns:request',
          'apns:missing',
          'fcm:skipped_apns',
        ]));
    expect(apnsRegistrationRequests, 1);
    expect(messaging.tokenRequests, 0);
    expect(client.calls, isEmpty);
  });

  test('iOS APNs 등록이 늦어도 토큰을 기다린 뒤 서버 오류를 기록한다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messaging.apnsToken = 'private-apns-token';
    messaging.apnsAvailableAfter = 3;
    client.error = const ApiException(401, 'INSTALLATION_AUTH_REQUIRED');

    await initialize();

    expect(
        events,
        containsAllInOrder([
          'apns:request',
          'apns:present',
          'fcm:present',
          'server:request',
          'server:error:http:401:INSTALLATION_AUTH_REQUIRED',
        ]));
    expect(messaging.apnsReads, 3);
    expect(apnsRegistrationRequests, 1);
    expect(events.join(' '), isNot(contains('private-apns-token')));
    expect(events.join(' '), isNot(contains('test-token')));
  });

  test('APNs 등록 후 FCM 오류 코드는 기록하고 서버 요청은 보내지 않는다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messaging.apnsToken = 'private-apns-token';
    messaging.tokenError = FirebaseException(
        plugin: 'firebase_messaging',
        code: 'unavailable',
        message: 'private-token-must-not-be-logged');

    await initialize();

    expect(events, contains('fcm:error:firebase:unavailable'));
    expect(client.calls, isEmpty);
    expect(events.join(' '), isNot(contains('private-token')));
  });

  test('iOS 알림 권한이 없으면 APNs 등록과 FCM 조회를 시작하지 않는다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messaging.authorization = AuthorizationStatus.denied;

    await initialize();

    expect(apnsRegistrationRequests, 0);
    expect(messaging.tokenRequests, 0);
    expect(client.calls.single.body['fcmToken'], isNull);
  });
}
