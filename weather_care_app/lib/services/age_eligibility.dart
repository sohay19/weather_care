import 'dart:async';

import 'package:flutter/foundation.dart';

import 'age_eligibility_store.dart';

class AgeEligibilityController extends ChangeNotifier {
  AgeEligibilityController({
    required this.read,
    required this.write,
  });

  final Future<AgeEligibility> Function() read;
  final Future<void> Function(AgeEligibility) write;

  static final instance = AgeEligibilityController(
    read: AgeEligibilityStore.instance.read,
    write: AgeEligibilityStore.instance.write,
  );

  AgeEligibility eligibility = AgeEligibility.unknown;
  bool ready = false;
  bool busy = false;
  String? error;

  bool get sdkAccessAllowed =>
      ready &&
      !busy &&
      error == null &&
      eligibility == AgeEligibility.atLeast14;

  Future<void> initialize() async {
    if (ready || busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      eligibility = await read().timeout(const Duration(seconds: 3));
    } catch (_) {
      eligibility = AgeEligibility.unknown;
      error = '저장된 연령대를 확인하지 못했어요. 다시 선택해주세요.';
    } finally {
      ready = true;
      busy = false;
      notifyListeners();
    }
  }

  Future<void> select(AgeEligibility value) async {
    if (busy || value == AgeEligibility.unknown) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await write(value);
      eligibility = value;
      ready = true;
    } catch (_) {
      eligibility = AgeEligibility.unknown;
      ready = true;
      error = '연령대를 안전하게 저장하지 못했어요. 온라인 기능을 시작하지 않았어요.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> chooseAgain() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await write(AgeEligibility.unknown);
      eligibility = AgeEligibility.unknown;
      ready = true;
    } catch (_) {
      eligibility = AgeEligibility.under14;
      ready = true;
      error = '연령대 선택을 초기화하지 못했어요. 온라인 기능은 계속 시작하지 않아요.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
