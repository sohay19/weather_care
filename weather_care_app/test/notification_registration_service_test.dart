import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
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
  int requests = 0;
  @override
  Stream<String> get onTokenRefresh => tokens.stream;
  @override
  Future<String?> getToken(
          {String? vapidKey, String? serviceWorkerScriptPath}) async =>
      'test-token';
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
  setUp(() {
    messaging = _Messaging();
    client = _Client();
    service = NotificationRegistrationService(client, messaging: messaging);
  });
  tearDown(() async {
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
  });

  test('서버 삭제 중지 상태면 토큰 갱신·앱 복귀로 다시 등록하지 않는다', () async {
    await service.dispose();
    var allowed = true;
    service = NotificationRegistrationService(client,
        messaging: messaging, canRegister: () => allowed);
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
    var allowed = true;
    service = NotificationRegistrationService(client,
        messaging: messaging, canRegister: () => allowed);
    final pending = Completer<NotificationSettings>();
    messaging.pendingPermission = pending;
    final work = initialize();
    await flush();
    allowed = false;
    pending.complete(_Permission(AuthorizationStatus.authorized));
    await work;
    expect(client.calls, isEmpty);
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
}
