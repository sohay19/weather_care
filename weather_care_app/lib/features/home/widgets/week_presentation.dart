import '../../../models/weather.dart';
import '../../../utils/korea_date.dart';

String weekDayLabel(WeeklyForecastItem day) {
  final date = parseForecastDate(day.forecastDate);
  if (date == null) return '날짜 확인 어려움';
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
}

String weekPeriodLabel(List<WeeklyForecastItem> days) {
  if (days.isEmpty) return '날짜별 예보 자료가 없어요';
  final dates = days
      .map((day) => parseForecastDate(day.forecastDate))
      .whereType<DateTime>()
      .toSet()
      .toList()
    ..sort();
  if (dates.isEmpty) return '날짜 정보가 없어 예보 기간을 확인하기 어려워요';
  final first = dates.first;
  final last = dates.last;
  final includeYear = first.year != last.year;
  String label(DateTime date) =>
      '${includeYear ? '${date.year}년 ' : ''}${date.month}월 ${date.day}일';
  final range = first == last ? label(first) : '${label(first)}~${label(last)}';
  final missingDates =
      days.where((day) => parseForecastDate(day.forecastDate) == null).length;
  final coverage = dates.length == last.difference(first).inDays + 1
      ? '${dates.length}일 예보'
      : '기간 내 ${dates.length}일 자료';
  return '$range · $coverage'
      '${missingDates > 0 ? ' · 날짜 미확인 $missingDates개' : ''}';
}
