import '../../../utils/weather_number.dart';
import '../../../models/weather.dart';
import '../../../models/recommendation.dart';
import '../../../utils/korea_date.dart';
import 'week_precipitation.dart';

class WeekCalendarDay {
  final DateTime date;
  final WeeklyForecastItem? forecast;

  const WeekCalendarDay({required this.date, required this.forecast});
}

List<WeekCalendarDay> upcomingCalendarWeek(
  List<WeeklyForecastItem> forecasts,
  DateTime now,
) {
  final today = parseForecastDate(dateInKorea(now))!;
  final grouped = <String, List<WeeklyForecastItem>>{};
  for (final forecast in forecasts) {
    if (parseForecastDate(forecast.forecastDate) == null) continue;
    grouped.putIfAbsent(forecast.forecastDate!, () => []).add(forecast);
  }

  return List.generate(7, (index) {
    final date = today.add(Duration(days: index));
    final key = _calendarDateKey(date);
    final matches = grouped[key] ?? const <WeeklyForecastItem>[];
    final forecast = matches.length == 1 ? matches.single : null;
    return WeekCalendarDay(
      date: date,
      forecast: forecast,
    );
  });
}

String calendarWeekPeriodLabel(List<WeekCalendarDay> days) {
  if (days.length != 7) return '오늘부터 7일을 표시해요';
  final first = days.first.date;
  final last = days.last.date;
  final year = first.year == last.year ? '' : '${first.year}년 ';
  return '$year${first.month}월 ${first.day}일~'
      '${last.year != first.year ? '${last.year}년 ' : ''}'
      '${last.month}월 ${last.day}일';
}

String calendarDayLabel(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
}

String _calendarDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

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

String? weekWeatherLabel(WeeklyForecastItem day) {
  final label = day.weatherLabel?.trim().replaceAll(' ', '');
  return switch (label) {
    '맑음' => '맑음',
    '구름많음' => '구름 많음',
    '흐림' => '흐림',
    '비' => '비',
    '소나기' => '소나기',
    '빗방울' => '빗방울',
    '눈' => '눈',
    '눈날림' => '눈날림',
    '비/눈' || '비와눈' => '비/눈',
    '빗방울/눈날림' => '빗방울/눈날림',
    '비·눈기록없음' => '비·눈 기록 없음',
    '강수관측없음' => '강수 관측 없음',
    '하늘상태관측없음' => '하늘 상태 관측 없음',
    _ => null,
  };
}

bool? weekPrecipitation(WeeklyForecastItem day) {
  final label = weekWeatherLabel(day);
  if (label == null) return null;
  if (label == '비·눈 기록 없음' || label == '강수 관측 없음') return false;
  if (label == '하늘 상태 관측 없음') return null;
  if (!const ['맑음', '구름 많음', '흐림'].contains(label)) return true;
  // A clear received slot does not establish absence in missing slots.
  return day.weatherDataComplete == true ? false : null;
}

double? weekTemperature(WeeklyForecastItem day, {required bool maximum}) {
  if (day.min?.isFinite == true &&
      day.max?.isFinite == true &&
      day.min! > day.max!) {
    return null;
  }
  final value = maximum ? day.max : day.min;
  return value?.isFinite == true ? value : null;
}

String weekDegrees(double value) => '${formatWeatherNumber(value)}℃';

String weekTemperatureLabel(WeeklyForecastItem day, {required bool maximum}) {
  final label = maximum ? '최고' : '최저';
  final value = weekTemperature(day, maximum: maximum);
  if (value == null) return '$label 자료 없음';
  final source = maximum ? day.maxTemperatureSource : day.minTemperatureSource;
  return '${source == 'HOURLY' ? '시간별 ' : ''}$label ${weekDegrees(value)}';
}

List<WeatherRecommendation> weekRecommendations(WeeklyForecastItem day) {
  final seen = <RecommendationType>{};
  return day.recommendations
      .where((item) => item.recommended && seen.add(item.type))
      .toList();
}

class WeekSummaryMetric {
  final String value;
  const WeekSummaryMetric(this.value);
}

class WeekSummaryData {
  final WeekSummaryMetric precipitation;
  final WeekSummaryMetric precipitationAmount;
  final WeekSummaryMetric minimum;
  final WeekSummaryMetric maximum;
  final WeekSummaryMetric preparations;
  final WeekSummaryMetric preparationItems;
  final String? excludedNotice;
  const WeekSummaryData(
      this.precipitation,
      this.precipitationAmount,
      this.minimum,
      this.maximum,
      this.preparations,
      this.preparationItems,
      this.excludedNotice);
}

WeekSummaryData buildWeekSummary(List<WeeklyForecastItem> days,
    {required bool serverFeaturesAvailable, DateTime? today}) {
  final grouped = <String, List<WeeklyForecastItem>>{};
  var missingDates = 0;
  for (final day in days) {
    if (parseForecastDate(day.forecastDate) == null) {
      missingDates++;
    } else {
      grouped.putIfAbsent(day.forecastDate!, () => []).add(day);
    }
  }
  // Do not pick an arbitrary duplicate or count one calendar day twice.
  final eligible = grouped.values
      .where((items) => items.length == 1)
      .map((items) => items.single)
      .toList();
  final duplicates = grouped.length - eligible.length;
  final total = eligible.length;
  WeekSummaryMetric count(
    List<bool?> values, {
    int? denominator,
    bool zeroWhenNoPositive = false,
  }) {
    final known = values.whereType<bool>().toList();
    final positive = known.where((value) => value).length;
    final expected = denominator ?? total;
    final value = zeroWhenNoPositive && positive == 0
        ? '0일'
        : known.isEmpty
            ? '자료 없음'
            : known.length == expected
                ? '$positive일'
                : positive > 0
                    ? '$positive일 확인'
                    : '확인 어려움';
    return WeekSummaryMetric(value);
  }

  final maximumTemperatures = eligible
      .map((day) => weekTemperature(day, maximum: true))
      .whereType<double>()
      .toList();
  final minimumTemperatures = eligible
      .map((day) => weekTemperature(day, maximum: false))
      .whereType<double>()
      .toList();
  final max = maximumTemperatures.fold<double?>(
      null, (max, value) => max == null || value > max ? value : max);
  final min = minimumTemperatures.fold<double?>(
      null, (min, value) => min == null || value < min ? value : min);
  final knownAmounts = eligible
      .map((day) => (day: day, amount: weekPrecipitationAmount(day)))
      .where((item) => item.amount != null)
      .toList();
  knownAmounts.sort((a, b) =>
      (b.amount!.upper ?? 1000000000).compareTo(a.amount!.upper ?? 1000000000));
  final highestAmount = knownAmounts.isEmpty
      ? '자료 없음'
      : '${knownAmounts.first.amount!.label}'
          '${knownAmounts.first.day.forecastSource == 'KMA_OBSERVATION' ? '' : ' (예상)'}';
  final preparationDays = eligible
      .where((day) =>
          day.forecastSource != 'KMA_OBSERVATION' &&
          (today == null ||
              !parseForecastDate(day.forecastDate)!.isBefore(today)))
      .toList();
  final itemTypes = <RecommendationType>{
    for (final day in preparationDays)
      for (final item in weekRecommendations(day)) item.type,
  }.toList();
  final itemLabels = itemTypes.take(3).map((type) => type.label).join(', ');
  final incompletePreparations =
      preparationDays.any((day) => !day.recommendationsAvailable);
  final preparationLabels = itemTypes.isEmpty
      ? incompletePreparations
          ? '자료 없음'
          : '없음'
      : '$itemLabels${itemTypes.length > 3 ? ' 외 ${itemTypes.length - 3}종' : ''}'
          '${incompletePreparations ? ' · 일부 확인' : ''}';
  final exclusions = [
    if (missingDates > 0) '날짜 미확인 $missingDates개',
    if (duplicates > 0) '중복 날짜 $duplicates일',
  ];
  return WeekSummaryData(
    count(
      eligible.map(weekPrecipitation).toList(),
      zeroWhenNoPositive: true,
    ),
    WeekSummaryMetric(highestAmount),
    WeekSummaryMetric(min == null ? '자료 없음' : weekDegrees(min)),
    WeekSummaryMetric(max == null ? '자료 없음' : weekDegrees(max)),
    serverFeaturesAvailable
        ? count(
            preparationDays
                .map((day) => weekRecommendations(day).isNotEmpty
                    ? true
                    : day.recommendationsAvailable
                        ? false
                        : null)
                .toList(),
            denominator: preparationDays.length,
          )
        : const WeekSummaryMetric('미지원'),
    WeekSummaryMetric(serverFeaturesAvailable ? preparationLabels : '미지원'),
    exclusions.isEmpty ? null : '요약 제외: ${exclusions.join(' · ')}',
  );
}
