import 'dart:async';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'current_location_service.dart';

class NotificationRegistrationService {
  final ApiClient client;
  final FirebaseMessaging? _messaging;
  FirebaseMessaging get messaging => _messaging ?? FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenSubscription;
  _RegistrationTarget? _target;
  Future<void> _registrationQueue = Future<void>.value();
  bool _disposed = false;

  NotificationRegistrationService(
    this.client, {
    FirebaseMessaging? messaging,
  }) : _messaging = messaging;

  Future<void> initialize({
    required String installationId,
    required int nx,
    required int ny,
    required String locationMode,
    DeviceCoordinates? coordinates,
  }) async {
    if (_disposed) return;
    _target =
        _RegistrationTarget(installationId, nx, ny, locationMode, coordinates);
    try {
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final authorized =
          permission.authorizationStatus == AuthorizationStatus.authorized ||
              permission.authorizationStatus == AuthorizationStatus.provisional;
      final token = authorized ? await messaging.getToken() : null;
      await _registerCurrent(token);

      await _tokenSubscription?.cancel();
      if (_disposed) return;
      _tokenSubscription = messaging.onTokenRefresh.listen(
        (refreshedToken) => unawaited(_registerCurrent(refreshedToken)),
        onError: (Object error) {
          log('FCM token refresh failed (${error.runtimeType})');
        },
      );
    } catch (error) {
      log('Notification registration unavailable (${error.runtimeType})');
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
  }

  Future<void> syncInstallation({
    required String installationId,
    required int nx,
    required int ny,
    required String locationMode,
    DeviceCoordinates? coordinates,
  }) async {
    if (_disposed) return;
    _target =
        _RegistrationTarget(installationId, nx, ny, locationMode, coordinates);
    try {
      final permission = await messaging.getNotificationSettings();
      final authorized =
          permission.authorizationStatus == AuthorizationStatus.authorized ||
              permission.authorizationStatus == AuthorizationStatus.provisional;
      await _registerCurrent(authorized ? await messaging.getToken() : null);
    } catch (error) {
      log('Installation synchronization failed (${error.runtimeType})');
    }
  }

  Future<void> _registerCurrent(String? token) {
    _registrationQueue = _registrationQueue.then((_) async {
      final target = _target;
      if (_disposed || target == null) return;
      await client.putJson(
        '/api/v1/installations/${target.installationId}',
        {
          'fcmToken': token,
          'locationMode': target.locationMode,
          'platform': defaultTargetPlatform.name,
          'timezone': 'Asia/Seoul',
          'latitude': target.coordinates?.latitude,
          'longitude': target.coordinates?.longitude,
        },
        query: {'nx': '${target.nx}', 'ny': '${target.ny}'},
      );
    }).catchError((Object error) {
      log('Installation registration failed (${error.runtimeType})');
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
