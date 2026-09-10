import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/server_data_access.dart';
import 'package:weather_care/features/settings/server_data_controls.dart';

const legacyId = 'wc_legacy_fixture_1234567890';
const newId = 'wc_server_fixture_1234567890';
final secret = 'a' * 64;

class _Api extends ApiClient {
  final calls = <({
    String method,
    String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers
  })>[];
  bool legacy = false;
  Object? deletionError;
  Completer<void>? pendingDelete;
  StreamController<RemoteMessage>? messages;
  _Api() : super(baseUrl: 'https://example.invalid');
  @override
  Future<Map<String, dynamic>> requestJson(String method, String path,
      {Map<String, String>? query,
      Map<String, String>? headers,
      Map<String, dynamic>? body}) async {
    calls.add((method: method, path: path, body: body, headers: headers));
    if (method == 'DELETE') {
      await pendingDelete?.future;
      if (deletionError != null) throw deletionError!;
      return {};
    }
    if (path.endsWith('/enroll')) {
      if (legacy) throw const ApiException(409, 'LEGACY_VERIFICATION_REQUIRED');
      return {'installationId': newId};
    }
    if (path.endsWith('/ownership-challenge')) {
      messages?.add(RemoteMessage(data: {
        'kind': 'installation_ownership',
        'installationId': legacyId,
        'requestId': body!['requestId'],
        'proof': 'b' * 64
      }));
      return {'ok': true};
    }
    if (path.endsWith('/claim')) return {'installationId': legacyId};
    return {};
  }
}

class _Boundary extends InstallationApiClient {
  final reads = <({
    String path,
    Map<String, String>? query,
    Map<String, String>? headers
  })>[];
  _Boundary(ServerDataAccess access)
      : super(baseUrl: 'https://example.invalid', access: access);
  @override
  Future<Map<String, dynamic>> requestJson(String method, String path,
      {Map<String, String>? query,
      Map<String, String>? headers,
      Map<String, dynamic>? body}) async {
    reads.add((path: path, query: query, headers: headers));
    return {};
  }
}

void main() {
  late _Api api;
  late ServerDataAccess access;
  String? stored;
  bool failWrite = false;
  setUp(() {
    api = _Api();
    stored = null;
    failWrite = false;
    access = ServerDataAccess(
        api: api,
        legacyInstallationId: legacyId,
        readStore: () async => stored,
        writeStore: (value) async {
          if (failWrite) throw StateError('disk');
          stored = value;
        },
        ownershipMessages: () => api.messages!.stream,
        proofTimeout: const Duration(milliseconds: 10));
  });
  tearDown(() async {
    access.dispose();
    await api.messages?.close();
  });
  Future<void> established() async {
    stored = jsonEncode({
      'mode': 'active',
      'serverId': newId,
      'secret': secret,
      'skipLegacy': false
    });
    await access.load();
  }

  test(
      'securely persists enrollment before sending personal data; resolves server ID at boundary',
      () async {
    await access.load();
    final boundary = _Boundary(access);
    await boundary
        .putJson('/api/v1/installations/$legacyId', {'fcmToken': 'synthetic'});
    expect(jsonDecode(stored!)['serverId'], newId);
    expect(jsonDecode(stored!)['secret'], matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(boundary.reads.single.path, '/api/v1/installations/$newId');
    expect(
        boundary.reads.single.headers!['Authorization'], startsWith('Bearer '));
    expect(boundary.reads.single.query, isNull);
    expect(api.calls.where((c) => c.path.endsWith('/enroll')), hasLength(1));
  });

  test('a secure-store write failure does not send personal data or DELETE',
      () async {
    await access.load();
    failWrite = true;
    await expectLater(
        access.mutate((_) async => fail('must not write')), throwsStateError);
    await access.deleteData();
    expect(api.calls, isEmpty);
    expect(access.mode, ServerDataMode.deleting);
    expect(access.error, isNotNull);
  });

  test('an unreadable secure store fails closed instead of replacing identity',
      () async {
    stored = '{bad';
    await expectLater(access.load(), throwsFormatException);
    expect(access.paused, isTrue);
    await access.deleteData();
    expect(api.calls, isEmpty);
  });

  test(
      'deletes the established ID, clears local credential only after success, and stays paused',
      () async {
    await established();
    await access.deleteData();
    expect(api.calls.single.method, 'DELETE');
    expect(api.calls.single.path, endsWith(newId));
    expect(access.mode, ServerDataMode.deleted);
    expect(access.credential, isNull);
    expect(jsonDecode(stored!)['secret'], isNull);
    expect(access.paused, isTrue);
    await expectLater(access.mutate((_) async => fail('must not register')),
        throwsA(isA<ServerDataPaused>()));
    await access.deleteData();
    expect(api.calls, hasLength(1));
  });

  test(
      'network uncertainty persists deletion intent and retries the same credential after restart',
      () async {
    await established();
    api.deletionError = TimeoutException('synthetic');
    await access.deleteData();
    expect(jsonDecode(stored!)['mode'], 'deleting');
    expect(access.mode, ServerDataMode.deleting);
    expect(access.error, contains('삭제 완료를 확인하지 못했어요'));
    final restarted = ServerDataAccess(
        api: api,
        legacyInstallationId: legacyId,
        readStore: () async => stored,
        writeStore: (value) async => stored = value);
    await restarted.load();
    expect(restarted.paused, isTrue);
    api.deletionError = null;
    await restarted.deleteData();
    expect(api.calls, hasLength(2));
    expect(api.calls[0].path, api.calls[1].path);
    expect(restarted.mode, ServerDataMode.deleted);
    restarted.dispose();
  });

  test(
      'blocks late queued writes and waits for an in-flight write before DELETE',
      () async {
    await established();
    final running = Completer<void>();
    final entered = Completer<void>();
    final order = <String>[];
    final first = access.mutate((_) async {
      order.add('write-start');
      entered.complete();
      await running.future;
      order.add('write-end');
    });
    await entered.future;
    final late = expectLater(access.mutate((_) async => fail('late write')),
        throwsA(isA<ServerDataPaused>()));
    final deletion = access.deleteData();
    expect(access.paused, isTrue);
    expect(api.calls, isEmpty);
    running.complete();
    await first;
    await late;
    await deletion;
    expect(order, ['write-start', 'write-end']);
    expect(api.calls.single.method, 'DELETE');
  });

  test(
      'duplicate delete taps send once; restart marker is written before network',
      () async {
    await established();
    api.pendingDelete = Completer<void>();
    final first = access.deleteData();
    await Future<void>.delayed(Duration.zero);
    expect(jsonDecode(stored!)['mode'], 'deleting');
    await access.deleteData();
    expect(api.calls, hasLength(1));
    api.pendingDelete!.complete();
    await first;
  });

  test(
      'cannot resume an uncertain deletion; explicit resume after success uses a fresh enrollment',
      () async {
    await established();
    api.deletionError = const ApiException(500, 'FAIL');
    await access.deleteData();
    await access.resume();
    expect(access.mode, ServerDataMode.deleting);
    api.deletionError = null;
    await access.deleteData();
    await access.resume();
    expect(access.mode, ServerDataMode.active);
    expect(access.credential, isNull);
    await access.mutate((_) async {});
    expect(api.calls.last.body, isEmpty); // Never reclaim the erased legacy ID.
  });

  test(
      'deleted mode strips installation ID and precise coordinates from forecast requests',
      () async {
    await established();
    final boundary = _Boundary(access);
    await boundary.get('/api/v1/weather/today', query: {
      'installationId': legacyId,
      'nx': '60',
      'latitude': '37.2',
      'longitude': '127.1'
    });
    expect(boundary.reads.last.query!['installationId'], newId);
    await access.deleteData();
    await boundary.get('/api/v1/weather/today', query: {
      'installationId': legacyId,
      'nx': '60',
      'latitude': '37.2',
      'longitude': '127.1'
    });
    expect(boundary.reads.last.query, {'nx': '60'});
    expect(boundary.reads.last.headers, isNull);
  });

  test(
      'legacy proof goes through receipt, claim and authenticated deletion in order',
      () async {
    api.legacy = true;
    api.messages = StreamController<RemoteMessage>.broadcast();
    await access.load();
    await access.deleteData();
    expect(access.mode, ServerDataMode.deleted);
    expect(api.calls.map((c) => c.path.split('/').last),
        ['enroll', 'ownership-challenge', 'claim', legacyId]);
    expect(api.calls[2].body!['proof'], 'b' * 64);
    expect(api.calls[2].headers, api.calls[3].headers);
  });

  test('missing legacy delivery never reports deletion success', () async {
    api.legacy = true;
    api.messages = StreamController<RemoteMessage>.broadcast();
    // A separate empty stream simulates non-delivery of the ownership proof.
    final inaccessible = ServerDataAccess(
        api: api,
        legacyInstallationId: legacyId,
        readStore: () async => null,
        writeStore: (_) async {},
        ownershipMessages: () => const Stream.empty(),
        proofTimeout: const Duration(milliseconds: 1));
    await inaccessible.load();
    await inaccessible.deleteData();
    expect(inaccessible.mode, ServerDataMode.deleting);
    expect(inaccessible.error, isNotNull);
    expect(api.calls.any((c) => c.method == 'DELETE'), isFalse);
    inaccessible.dispose();
  });

  test('completion-marker storage failure retains retryable deletion state',
      () async {
    var writes = 0;
    final session = ServerDataAccess(
        api: api,
        legacyInstallationId: legacyId,
        readStore: () async =>
            jsonEncode({'mode': 'active', 'serverId': newId, 'secret': secret}),
        writeStore: (_) async {
          if (++writes >= 3) throw StateError('completion disk error');
        });
    await session.load();
    await session.deleteData();
    expect(api.calls.single.method, 'DELETE');
    expect(session.mode, ServerDataMode.deleting);
    expect(session.credential, isNotNull);
    session.dispose();
  });

  testWidgets('confirmation explains scope and cancellation never deletes',
      (tester) async {
    await tester.runAsync(established);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ServerDataControls(
                access: access,
                onDelete: access.deleteData,
                onResume: access.resume))));
    await tester.tap(find.byKey(const ValueKey('server-data-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('운영 로그·백업'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
  });

  testWidgets(
      '360px large-text confirmation scrolls and shows success only after the reply',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(established);
    api.pendingDelete = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
                size: Size(360, 760), textScaler: TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: ServerDataControls(
                    access: access,
                    onDelete: access.deleteData,
                    onResume: access.resume)))));
    await tester.tap(find.byKey(const ValueKey('server-data-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('server-data-confirm-delete')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('삭제를 완료했어요'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      api.pendingDelete!.complete();
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('삭제를 완료했어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('server-data-resume')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
