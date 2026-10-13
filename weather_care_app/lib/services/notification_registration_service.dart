import 'dart:async';
import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';
import 'current_location_service.dart';
import 'minimum_age_policy.dart';

class NotificationRegistrationService {
  static const _diagnostics =
      MethodChannel('com.codesoha.weathercare/notification-diagnostics');
  final ApiClient client;
  final FirebaseMessaging? _messaging;
  final bool Function()? canRegister;
  final void Function(String)? diagnosticLog;
  final Future<void> Function()? registerForRemoteNotifications;
  final Duration apnsRetryDelay;
  FirebaseMessaging get messaging => _messaging ?? FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenSubscription;
  _RegistrationTarget? _target;
  Future<void> _registrationQueue = Future<void>.value();
  bool _disposed = false;

  NotificationRegistrationService(
    this.client, {
    FirebaseMessaging? messaging,
    this.canRegister,
    this.diagnosticLog,
    this.registerForRemoteNotifications,
    this.apnsRetryDelay = const Duration(milliseconds: 500),
  }) : _messaging = messaging {
    _record('service:ready');
  }

  void _record(String event) {
    if (diagnosticLog != null) {
      diagnosticLog!(event);
      return;
    }
    log('WeatherCareNotification $event');
    if (kDebugMode) debugPrint('WeatherCareNotification $event');
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(_diagnostics.invokeMethod<void>('record', event).catchError(
            (Object _) {},
          ));
    }
  }

  String _failure(Object error) {
    String safeCode(String code) =>
        RegExp(r'^[A-Za-z0-9_.-]{1,64}$').hasMatch(code) ? code : 'UNKNOWN';
    if (error is FirebaseException) {
      return 'firebase:${safeCode(error.code)}';
    }
    if (error is ApiException) {
      return 'http:${error.status}:${safeCode(error.code)}';
    }
    if (error is PlatformException) {
      return 'platform:${safeCode(error.code)}';
    }
    if (error is TimeoutException) return 'timeout';
    return error.runtimeType.toString();
  }

  Future<bool> _prepareApns() async {
    _record('apns:request');
    await (registerForRemoteNotifications?.call() ??
        _diagnostics.invokeMethod<void>('registerForRemoteNotifications'));
    for (var attempt = 0; attempt < 20; attempt++) {
      final token = await messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) {
        _record('apns:present');
        return true;
      }
      if (attempt < 19) await Future<void>.delayed(apnsRetryDelay);
    }
    _record('apns:missing');
    return false;
  }

  Future<void> initialize({
    required String installationId,
    required int nx,
    required int ny,
    required String locationMode,
    DeviceCoordinates? coordinates,
  }) async {
    if (_disposed || !(canRegister?.call() ?? true)) {
      _record('skip:inactive');
      return;
    }
    _target =
        _RegistrationTarget(installationId, nx, ny, locationMode, coordinates);
    try {
      await _registerCurrent();

      await _tokenSubscription?.cancel();
      if (_disposed) return;
      _tokenSubscription = messaging.onTokenRefresh.listen(
        (refreshedToken) => unawaited(_registerCurrent(refreshedToken)),
        onError: (Object error) {
          _record('fcm_refresh:error:${_failure(error)}');
        },
      );
    } catch (error) {
      _record('initialize:error:${_failure(error)}');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _target = null;
    await _tokenSubscription?.cancel();
  }

  // Prevent a token refresh from re-registering coordinates that are no longer
  // confirmed. The server retains its last registered region until a valid update.
  void invalidateLocation() {
    _target = null;
    _record('skip:no_location');
  }

  Future<void> syncInstallation({
    required String installationId,
    required int nx,
    required int ny,
    required String locationMode,
    DeviceCoordinates? coordinates,
  }) async {
    if (_disposed || !(canRegister?.call() ?? true)) {
      _record('skip:inactive');
      return;
    }
    _target =
        _RegistrationTarget(installationId, nx, ny, locationMode, coordinates);
    try {
      await _registerCurrent();
    } catch (error) {
      _record('sync:error:${_failure(error)}');
    }
  }

  Future<void> _registerCurrent([String? refreshedToken]) {
    _registrationQueue = _registrationQueue.then((_) async {
      if (_disposed || _target == null || !(canRegister?.call() ?? true)) {
        _record('skip:inactive_or_no_location');
        return;
      }
      _record('start');
      var stage = 'permission';
      try {
        // Read inside the queue so a delayed token refresh cannot restore a token
        // after a queued permission denial. Only explicit Settings actions ask.
        final permission = await messaging.getNotificationSettings();
        _record('permission:${permission.authorizationStatus.name}');
        final allowed = permission.authorizationStatus ==
                AuthorizationStatus.authorized ||
            permission.authorizationStatus == AuthorizationStatus.provisional;
        if (_disposed || _target == null || !(canRegister?.call() ?? true)) {
          _record('skip:inactive_or_no_location');
          return;
        }
        if (allowed && defaultTargetPlatform == TargetPlatform.iOS) {
          stage = 'apns';
          if (!await _prepareApns()) {
            _record('fcm:skipped_apns');
            return;
          }
        }
        stage = 'fcm';
        final token =
            allowed ? refreshedToken ?? await messaging.getToken() : null;
        _record(allowed
            ? token == null || token.isEmpty
                ? 'fcm:missing'
                : 'fcm:present'
            : 'fcm:skipped_permission');
        final target = _target;
        if (_disposed || target == null || !(canRegister?.call() ?? true)) {
          _record('skip:inactive_or_no_location');
          return;
        }
        stage = 'server';
        _record('server:request');
        await client.putJson(
          '/api/v1/installations/${target.installationId}',
          {
            ...minimumAgeServerAssertion,
            'fcmToken': token,
            'locationMode': target.locationMode,
            'platform': defaultTargetPlatform.name,
            'timezone': 'Asia/Seoul',
            'latitude': target.coordinates?.latitude,
            'longitude': target.coordinates?.longitude,
          },
          query: {'nx': '${target.nx}', 'ny': '${target.ny}'},
        );
        _record('server:success');
      } catch (error) {
        _record('$stage:error:${_failure(error)}');
      }
    }).catchError((Object error) {
      _record('queue:error:${_failure(error)}');
    });
    return _registrationQueue;
  }
}

class _RegistrationTarget {
  final String installationId;
  final int nx;
  final int ny;
  final String locationMode;
  final DeviceCoordinates? coordinates;

  const _RegistrationTarget(this.installationId, this.nx, this.ny,
      this.locationMode, this.coordinates);
}
