import 'dart:async';

import 'package:flutter/material.dart';

import 'notification_destination.dart';

class NotificationNavigationService {
  final GlobalKey<NavigatorState> navigatorKey;

  StreamSubscription<Map<String, dynamic>>? _subscription;
  NotificationDestination? _pendingDestination;
  bool _postFrameScheduled = false;

  NotificationNavigationService(this.navigatorKey);

  void start(Stream<Map<String, dynamic>> openedMessages) {
    _subscription ??= openedMessages.listen(openMessageData);
  }

  void openMessageData(Map<String, dynamic> data) {
    _pendingDestination = NotificationDestination.fromMessageData(data);
    _openPendingDestination();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _openPendingDestination() {
    final destination = _pendingDestination;
    if (destination == null) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _scheduleAfterFrame();
      return;
    }

    _pendingDestination = null;
    unawaited(
      navigator.pushNamedAndRemoveUntil(
        destination.routeName,
        (_) => false,
        arguments: destination,
      ),
    );
  }

  void _scheduleAfterFrame() {
    if (_postFrameScheduled) return;
    _postFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFrameScheduled = false;
      _openPendingDestination();
    });
  }
}
