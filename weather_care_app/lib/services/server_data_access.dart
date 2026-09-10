import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

enum ServerDataMode { active, deleting, deleted }

class InstallationCredential {
  final String id;
  final String secret;
  const InstallationCredential(this.id, this.secret);
  Map<String, String> get headers => {'Authorization': 'Bearer $secret'};
}

class ServerDataPaused implements Exception {
  const ServerDataPaused();
}

/// One gate for registration, settings, deletion and re-enrollment. A deletion
/// intent is persisted BEFORE its network call, and survives uncertain replies.
class ServerDataAccess extends ChangeNotifier {
  final ApiClient api;
  final String legacyInstallationId;
  final Future<String?> Function() readStore;
  final Future<void> Function(String) writeStore;
  final Stream<RemoteMessage> Function() ownershipMessages;
  final Duration proofTimeout;
  Future<void> _queue = Future<void>.value();
  bool _loaded = false;
  bool _disposed = false;
  String? _secret;
  String? _serverId;
  bool _skipLegacy = false;
  ServerDataMode mode = ServerDataMode.active;
  bool busy = false;
  String? error;

  ServerDataAccess({
    required this.api,
    required this.legacyInstallationId,
    Future<String?> Function()? readStore,
    Future<void> Function(String)? writeStore,
    Stream<RemoteMessage> Function()? ownershipMessages,
    this.proofTimeout = const Duration(seconds: 45),
  })  : readStore = readStore ??
            (() => const FlutterSecureStorage()
                .read(key: 'weather_care_server_access')),
        writeStore = writeStore ??
            ((value) => const FlutterSecureStorage()
                .write(key: 'weather_care_server_access', value: value)),
        ownershipMessages =
            ownershipMessages ?? (() => FirebaseMessaging.onMessage);

  bool get paused => !_loaded || mode != ServerDataMode.active;
  InstallationCredential? get credential =>
      _loaded && _serverId != null && _secret != null
          ? InstallationCredential(_serverId!, _secret!)
          : null;

  Future<void> load() => _serial(() async {
        if (_loaded) return;
        final encoded =
            await readStore(); // Fail closed; never replace unreadable keys.
        if (encoded != null) {
          final data = jsonDecode(encoded) as Map<String, dynamic>;
          mode = ServerDataMode.values.byName(data['mode'] as String);
          _secret = data['secret'] as String?;
          _serverId = data['serverId'] as String?;
          _skipLegacy = data['skipLegacy'] == true;
          if ((_secret != null &&
                  !RegExp(r'^[0-9a-f]{64}$').hasMatch(_secret!)) ||
              (_serverId != null && _secret == null)) {
            throw StateError('Invalid stored credential');
          }
        }
        _loaded = true;
        _notify();
      });

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _persist() => writeStore(jsonEncode({
        'mode': mode.name,
        'serverId': _serverId,
        'secret': _secret,
        'skipLegacy': _skipLegacy,
      }));

  Future<InstallationCredential> _ensureCredential() async {
    if (!_loaded) throw StateError('Secure storage is not loaded');
    if (credential case final existing?) {
      await _persist();
      return existing;
    }
    _secret ??= _randomSecret();
    await _persist(); // The new secret must survive a lost claim response.
    final headers = {'Authorization': 'Bearer $_secret'};
    Map<String, dynamic> response;
    try {
      response = await api.requestJson('POST', '/api/v1/installations/enroll',
          headers: headers,
          body: {
            if (!_skipLegacy) 'legacyInstallationId': legacyInstallationId
          });
    } on ApiException catch (exception) {
      if (exception.code != 'LEGACY_VERIFICATION_REQUIRED') rethrow;
      response = await _claimLegacy(headers);
    }
    final id = response['installationId'];
    if (id is! String || !RegExp(r'^wc_[A-Za-z0-9_-]{20,80}$').hasMatch(id)) {
      throw const ApiException(502, 'INVALID_RESPONSE');
    }
    _serverId = id;
    await _persist(); // Never send personal data until the ID is durable.
    return credential!;
  }

  Future<Map<String, dynamic>> _claimLegacy(Map<String, String> headers) async {
    final requestId = _randomSecret();
    final proof = Completer<String>();
    final subscription = ownershipMessages().listen((message) {
      final data = message.data;
      if (data['kind'] == 'installation_ownership' &&
          data['requestId'] == requestId &&
          data['installationId'] == legacyInstallationId &&
          data['proof'] is String &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(data['proof'] as String) &&
          !proof.isCompleted) {
        proof.complete(data['proof'] as String);
      }
    });
    try {
      await api.requestJson('POST',
          '/api/v1/installations/$legacyInstallationId/ownership-challenge',
          headers: headers, body: {'requestId': requestId});
      final received = await proof.future.timeout(proofTimeout);
      return await api.requestJson(
          'POST', '/api/v1/installations/$legacyInstallationId/claim',
          headers: headers, body: {'requestId': requestId, 'proof': received});
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> mutate(Future<void> Function(InstallationCredential) action) =>
      _serial(() async {
        if (paused) throw const ServerDataPaused();
        final owner = await _ensureCredential();
        if (paused) throw const ServerDataPaused();
        await action(owner);
      });

  Future<void> deleteData() async {
    if (busy || mode == ServerDataMode.deleted) return;
    // Stop newly queued writes immediately, before waiting for in-flight ones.
    mode = ServerDataMode.deleting;
    busy = true;
    error = null;
    _notify();
    try {
      await _serial(() async {
        if (!_loaded) throw StateError('Secure storage is not loaded');
        await _persist();
        final owner = await _ensureCredential();
        await api.requestJson('DELETE', '/api/v1/installations/${owner.id}',
            headers: owner.headers);
        // Retain credentials until the completed marker is safely written: a
        // timeout or disk error must support the same idempotent DELETE retry.
        await writeStore(jsonEncode({
          'mode': ServerDataMode.deleted.name,
          'serverId': null,
          'secret': null,
          'skipLegacy': true
        }));
        mode = ServerDataMode.deleted;
        _serverId = null;
        _secret = null;
        _skipLegacy = true;
      });
    } catch (failure) {
      error = switch (failure) {
        ApiException(
          code: 'OWNERSHIP_UNAVAILABLE' ||
              'OWNERSHIP_PROOF_REJECTED' ||
              'INSTALLATION_AUTH_REQUIRED'
        ) =>
          '이 설치의 소유 여부를 확인하지 못해 삭제하지 않았어요. 코드소하(CODESOHA) sy40222@gmail.com으로 문의해주세요. 인증키나 알림 토큰은 보내지 마세요.',
        ApiException(code: 'CHALLENGE_RETRY_LATER' || 'ENROLL_RETRY_LATER') =>
          '본인 확인을 다시 요청하려면 1분 뒤에 시도해주세요. 삭제 완료는 확인되지 않았어요.',
        _ => '삭제 완료를 확인하지 못했어요. 앱을 열어 둔 상태에서 다시 시도해주세요. 자동 등록과 설정 전송은 중지했어요.',
      };
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Only the explicit, separately confirmed "서버 기능 다시 사용" action calls this.
  Future<void> resume() async {
    if (busy || mode != ServerDataMode.deleted) return;
    busy = true;
    error = null;
    _notify();
    try {
      await _serial(() async {
        await writeStore(jsonEncode({
          'mode': ServerDataMode.active.name,
          'serverId': null,
          'secret': null,
          'skipLegacy': true
        }));
        mode = ServerDataMode.active;
      });
    } catch (_) {
      error = '기기에 사용 상태를 저장하지 못해 서버 기능을 다시 켜지 않았어요. 다시 시도해주세요.';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String _randomSecret() {
  final random = Random.secure();
  return List.generate(
      32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Existing services keep a local ID; only this boundary resolves the server ID.
class InstallationApiClient extends ApiClient {
  final ServerDataAccess access;
  InstallationApiClient({required super.baseUrl, required this.access});

  @override
  Future<void> putJson(String path, Map<String, dynamic> body,
      {Map<String, String>? query}) {
    return access.mutate((owner) async {
      final resolved = path.replaceFirst(access.legacyInstallationId, owner.id);
      await requestJson('PUT', resolved,
          query: query, body: body, headers: owner.headers);
    });
  }

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) {
    final owner = access.paused ? null : access.credential;
    final parameters = {...?query}..remove('installationId');
    if (owner != null && query?.containsKey('installationId') == true) {
      parameters['installationId'] = owner.id;
    }
    // Deleted/uncertain mode permits anonymous regional forecasts, without
    // sending a persistent installation ID or precise coordinates.
    if (access.paused) {
      parameters.remove('latitude');
      parameters.remove('longitude');
    }
    return requestJson('GET', path, query: parameters, headers: owner?.headers);
  }
}
