/// 저장한 알림 시각은 바꾸지 않고 서버 확인 주기와 수신 지연만 안내한다.
String notificationScheduleDescription(String time) {
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(time);
  if (match == null) return '알림 시간을 다시 선택해주세요.';
  return '10분 단위로 확인하며 실제 도착은 늦어질 수 있어요.';
}
