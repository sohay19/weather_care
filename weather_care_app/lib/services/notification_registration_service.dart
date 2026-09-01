import 'dart:async';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

class NotificationRegistrationService {
  final ApiClient client;
  final FirebaseMessaging messaging;
  StreamSubscription<String>? _tokenSubscription;

  NotificationRegistrationService(
    this.client, {
    FirebaseMessaging? messaging,
  }) : messaging = messaging ?? FirebaseMessaging.instance;

  Future<void> initialize({
    required String installationId,
    required int nx,
    required int ny,
    required String locationMode,
  }) async {
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
      await _register(
        installationId: installationId,
        token: token,
        nx: nx,
        ny: ny,
        locationMode: locationMode,
      );

      await _tokenSubscription?.cancel();
      _tokenSubscription = messaging.onTokenRefresh.listen(
        (refreshedToken) => unawaited(
          _register(
            installationId: installationId,
            token: refreshedToken,
            nx: nx,
            ny: ny,
            locationMode: locationMode,
          ),
        ),
        onError: (Object error) {
          log('FCM token refresh failed (${error.runtimeType})');
        },
      );
    } catch (error) {
      log('Notification registration unavailable (${error.runtimeType})');
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
  }

  Future<void> syncInstallation({
    required String installationId,
    required int nx,
    required int ny,
    required String locationMode,
  }) async {
    try {
      final permission = await messaging.getNotificationSettings();
      final authorized =
          permission.authorizationStatus == AuthorizationStatus.authorized ||
              permission.authorizationStatus == AuthorizationStatus.provisional;
      await _register(
        installationId: installationId,
        token: authorized ? await messaging.getToken() : null,
        nx: nx,
        ny: ny,
        locationMode: locationMode,
      );
    } catch (error) {
      log('Installation synchronization failed (${error.runtimeType})');
    }
  }

  Future<void> _register({
    required String installationId,
    required String? token,
    required int nx,
    required int ny,
    required String locationMode,
  }) async {
    try {
      await client.putJson(
        '/api/v1/installations/$installationId',
        {
          'fcmToken': token,
          'locationMode': locationMode,
          'platform': defaultTargetPlatform.name,
          'timezone': 'Asia/Seoul',
        },
        query: {'nx': '$nx', 'ny': '$ny'},
      );
    } catch (error) {
      log('Installation registration failed (${error.runtimeType})');
    }
  }
}
