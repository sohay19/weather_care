import '../../../models/precipitation.dart';
import '../../../models/weather.dart';
import '../../../utils/korea_date.dart';

/// Independent from weather/PTY: missing PCP or POP must not become zero.
List<String> weekPrecipitationLines(WeeklyForecastItem day) {
  final detail = day.precipitationDetail;
  final date = parseForecastDate(day.forecastDate);
  if (date == null || detail == null) return ['강수확률·강수량 자료를 확인하기 어려워요'];
  if (detail.kind == 'EXTENDED') {
    final probability = precipitationProbability(detail.extendedMaxProbability);
    return [
      if (probability != null && probability > 0)
        '확인된 시간대의 강수확률 중 최고 ${_percent(probability)}%',
      if (probability == null) '강수확률 자료를 확인하기 어려워요',
      '연장 예보의 강수량은 단계 정보로 제공되어 mm 합계를 계산하지 않아요.',
    ];
  }
  if (detail.hours.isEmpty) return ['강수확률·강수량 자료를 확인하기 어려워요'];
  final starts = <int>{};
  for (final hour in detail.hours) {
    final at = hour.forecastAt;
    if (at == null) return ['강수 자료의 날짜·시간에 오류가 있어 계산하기 어려워요'];
    final start =
        at.toUtc().add(const Duration(hours: 8)); // KST - previous hour
    if (start.year != date.year ||
        start.month != date.month ||
        start.day != date.day ||
        start.minute != 0 ||
        start.second != 0 ||
        !starts.add(start.hour)) {
      return ['강수 자료의 날짜·시간에 오류가 있어 계산하기 어려워요'];
    }
  }
  final sorted = starts.toList()..sort();
  final first = sorted.first;
  final last = sorted.last + 1;
  final expected = last - first;
  final period = '$first~$last시';
  final probabilityValues = detail.hours
      .map((hour) => precipitationProbability(hour.probability))
      .whereType<double>()
      .toList();
  final probabilityComplete = probabilityValues.length == expected;
  final amounts = detail.hours
      .map((hour) => hour.amount)
      .whereType<PrecipitationAmount>()
      .toList();
  final amountComplete = amounts.length == expected;
  final probability = probabilityValues.isEmpty
      ? null
      : probabilityValues.reduce((a, b) => a > b ? a : b);
  final amount = amountComplete ? amounts.reduce((a, b) => a.plus(b)) : null;
  final lines = <String>[
    if (probability != null && probability > 0)
      '${probabilityComplete ? '시간대별' : '확인된 시간대의'} 강수확률 중 최고 ${_percent(probability)}%',
    if (!probabilityComplete)
      '강수확률 ${probabilityValues.length}/$expected시간 자료 확인',
    if (amount != null && !amount.isZero) '예상 누적 강수량 ${amount.label}',
    if (!amountComplete)
      '일부 시간대 강수량 자료가 없거나 값이 올바르지 않아 $period 예상 누적량을 계산하기 어려워요',
  ];
  // Official unchanged "none" is not a default announcement.
  if (lines.isEmpty) return [];
  return [
    '$period 예보 기준${expected < 24 ? ' · 하루 중 일부 시간' : ''}',
    ...lines,
    if (probability != null && probability > 0)
      '강수확률은 시간대별 값 중 최댓값이며, 하루 전체의 확률이 아니에요.',
    if (amount != null && !amount.isZero) '누적량은 이 구간의 시간별 예보를 앱에서 합산했어요.',
  ];
}

String _percent(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
