/// 소수 첫째 자리까지 표시하되 작은 값이 0으로 사라지지 않게 한다.
String formatWeatherNumber(num value, {bool keepDecimal = false}) {
  if (!value.isFinite) return '자료 없음';
  if (value == 0) return keepDecimal ? '0.0' : '0';
  var digits = 1;
  var scaled = value.abs() * 10;
  while (scaled > 0 && scaled < 1 && digits < 20) {
    scaled *= 10;
    digits++;
  }
  final text = value.toStringAsFixed(digits);
  if (keepDecimal || !text.contains('.') || text.contains('e')) return text;
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
