import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/weather.dart';
import '../models/precipitation.dart';

const _kmaHost = 'apis.data.go.kr';
const _kmaPath = '/1360000/VilageFcstInfoService_2.0/getVilageFcst';
const _publicationHours = [2, 5, 8, 11, 14, 17, 20, 23];

class DirectKmaWeatherBundle {
  final TodayWeatherResponse today;
  final WeeklyWeatherResponse weekly;

  const DirectKmaWeatherBundle({
    required this.today,
    required this.weekly,
  });
}

class KmaDirectWeatherException implements Exception {
  final String message;
  final bool retryable;

  const KmaDirectWeatherException(this.message, {this.retryable = false});

  @override
  String toString() => 'KmaDirectWeatherException: $message';
}

class KmaDirectWeatherService {
  final String serviceKey;
  final http.Client client;
  final DateTime Function() now;
  final Duration timeout;

  KmaDirectWeatherService({
    required String serviceKey,
    http.Client? client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 8),
  })  : serviceKey = _normalizeServiceKey(serviceKey),
        client = client ?? http.Client(),
        now = now ?? DateTime.now;

  bool get isConfigured => serviceKey.isNotEmpty;

  Future<DirectKmaWeatherBundle> fetch({
    required int nx,
    required int ny,
  }) async {
    if (!isConfigured) {
      throw const KmaDirectWeatherException(
        'KMA_SERVICE_KEY가 설정되지 않았습니다.',
      );
    }

    final requestedAt = now();
    Object? lastError;
    for (final base in _latestBaseDateTimes(requestedAt, 4)) {
      try {
        final items = await _fetchItems(base, nx, ny);
        return _buildBundle(items, requestedAt, nx, ny, base);
      } on KmaDirectWeatherException catch (error) {
        lastError = error;
        if (!error.retryable) rethrow;
      }
    }

    throw KmaDirectWeatherException(
      lastError?.toString() ?? '기상청 단기예보를 가져오지 못했습니다.',
    );
  }

  Future<List<_KmaItem>> _fetchItems(
    _BaseDateTime base,
    int nx,
    int ny,
  ) async {
    final uri = Uri.https(_kmaHost, _kmaPath, {
      'serviceKey': serviceKey,
      'pageNo': '1',
      'numOfRows': '1000',
      'dataType': 'JSON',
      'base_date': base.date,
      'base_time': base.time,
      'nx': '$nx',
      'ny': '$ny',
    });
    final response = await client.get(uri,
        headers: const {'Accept': 'application/json'}).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw KmaDirectWeatherException(
        '기상청 API가 HTTP ${response.statusCode}를 반환했습니다.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const KmaDirectWeatherException('기상청 응답 형식이 올바르지 않습니다.');
    }

    final root = _asMap(decoded);
    final responseNode = _asMap(root?['response']);
    final header = _asMap(responseNode?['header']);
    final code = header?['resultCode']?.toString();
    final message = header?['resultMsg']?.toString() ?? '알 수 없는 오류';
    if (code != '00' && code != '0') {
      final noData = code == '03' || message.contains('NO_DATA');
      throw KmaDirectWeatherException(
        '기상청 API 오류 $code: $message',
        retryable: noData,
      );
    }

    final body = _asMap(responseNode?['body']);
    final itemsNode = _asMap(body?['items']);
    final rawItems = itemsNode?['item'];
    if (rawItems is! List || rawItems.isEmpty) {
      throw const KmaDirectWeatherException(
        '기상청 예보 자료가 아직 없습니다.',
        retryable: true,
      );
    }

    final items = rawItems
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map(_KmaItem.fromJson)
        .whereType<_KmaItem>()
        .toList();
    if (items.isEmpty) {
      throw const KmaDirectWeatherException('기상청 예보 항목을 해석하지 못했습니다.');
    }
    return items;
  }
}

DirectKmaWeatherBundle _buildBundle(
  List<_KmaItem> items,
  DateTime now,
  int nx,
  int ny,
  _BaseDateTime base,
) {
  final categoriesBySlot = <String, Map<String, String>>{};
  for (final item in items) {
    final slotKey = '${item.forecastDate}${item.forecastTime.padLeft(4, '0')}';
    categoriesBySlot.putIfAbsent(slotKey, () => {})[item.category] = item.value;
  }

  final allHourly = categoriesBySlot.entries
      .map((entry) => _snapshotFromSlot(entry.key, entry.value))
      .whereType<_DirectSnapshot>()
      .toList()
    ..sort((left, right) => left.observedAt.compareTo(right.observedAt));
  final cutoff = now.toUtc().subtract(const Duration(minutes: 30));
  final hourly = allHourly
      .where((item) => item.observedAt.toUtc().isAfter(cutoff))
      .take(48)
      .toList();
  if (hourly.isEmpty) {
    throw const KmaDirectWeatherException(
      '현재 시각 이후의 기상청 예보가 없습니다.',
      retryable: true,
    );
  }

  final todayDate = _formatKmaDate(now.toUtc().add(const Duration(hours: 9)));
  final daily = _buildDaily(items, allHourly)
      .where((item) => item.date.compareTo(todayDate) >= 0)
      .take(4)
      .toList();
  final current = hourly.first;
  final region = WeatherRegion(
    nx: nx,
    ny: ny,
    name: nx == 60 && ny == 121 ? '수원' : '선택 지역',
  );

  return DirectKmaWeatherBundle(
    today: TodayWeatherResponse(
      dataSource: '기상청 직접 조회',
      region: region,
      brief: '운영 서버 미연결 · 기상청 예보를 직접 표시합니다.',
      current: CurrentWeather(
        temperature: current.temperature,
        forecastAt: _kstIso(current.observedAt),
        apparentTemperature: current.apparentTemperature,
        apparentTemperatureSource: current.apparentTemperature == null
            ? null
            : 'APP_KMA_METHOD_FROM_FORECAST',
        humidity: current.humidity,
        windSpeed: current.windSpeed,
        sky: current.skyCondition,
      ),
      recommendations: const [],
      lifestyleMessages: const [],
      timeline: const [],
      hourly: hourly
          .map(
            (item) => HourlyWeatherItem(
              time: item.observedAt
                  .toUtc()
                  .add(const Duration(hours: 9))
                  .hour
                  .toString()
                  .padLeft(2, '0'),
              forecastDate: _isoDate(
                item.observedAt.toUtc().add(const Duration(hours: 9)),
              ),
              temperature: item.temperature,
              apparentTemperature: item.apparentTemperature,
              precipitationProbability: item.precipitationProbability,
              precipitationAmount: item.precipitationAmount,
              precipitationAmountLabel: item.precipitationAmountLabel,
              snowExpected: item.snowExpected,
              snowfallAmount: item.snowfallAmount,
              snowfallAmountLabel: item.snowfallAmountLabel,
              windSpeed: item.windSpeed,
              skyCondition: item.skyCondition,
            ),
          )
          .toList(),
    ),
    weekly: WeeklyWeatherResponse(
      days: daily
          .map(
            (item) => WeeklyForecastItem(
              date: _weekdayLabel(item.date),
              forecastDate: '${item.date.substring(0, 4)}-'
                  '${item.date.substring(4, 6)}-${item.date.substring(6, 8)}',
              weatherLabel: item.skyCondition,
              weatherDataComplete: item.weatherDataComplete,
              precipitationDetail:
                  _dailyPrecipitation(item.date, allHourly, base),
              min: item.minTemperature,
              max: item.maxTemperature,
              minTemperatureSource: item.minTemperatureSource,
              maxTemperatureSource: item.maxTemperatureSource,
              recommendationsAvailable: false,
              recommendations: const [],
            ),
          )
          .toList(),
    ),
  );
}

DailyPrecipitationDetail _dailyPrecipitation(
  String date,
  List<_DirectSnapshot> hourly,
  _BaseDateTime base,
) {
  final baseDay = _kmaSlotToDateTime('${base.date}0000');
  final extendedDate = _compactDate(baseDay.add(
    Duration(days: int.parse(base.time) < 1700 ? 3 : 4),
  ));
  final snapshots = hourly
      .where((item) =>
          _compactDate(item.observedAt.subtract(const Duration(hours: 1))) ==
          date)
      .toList();
  if (date.compareTo(extendedDate) >= 0) {
    return DailyPrecipitationDetail(
      kind: 'EXTENDED',
      hours: const [],
      extendedMaxProbability: _maximum(snapshots
          .map(
              (item) => precipitationProbability(item.precipitationProbability))
          .whereType<double>()
          .toList()),
    );
  }
  return DailyPrecipitationDetail(
    kind: 'HOURLY',
    hours: snapshots
        .map((item) => PrecipitationHour.fromJson({
              'forecastAt': item.observedAt
                  .toUtc()
                  .toIso8601String()
                  .replaceFirst('.000Z', 'Z'),
              'probability': item.precipitationProbability,
              'amountText': item.precipitationAmountText,
            }))
        .toList(),
  );
}

List<_DirectDaily> _buildDaily(
  List<_KmaItem> items,
  List<_DirectSnapshot> hourly,
) {
  final categoriesByDate = <String, Map<String, List<String>>>{};
  for (final item in items) {
    categoriesByDate
        .putIfAbsent(item.forecastDate, () => {})
        .putIfAbsent(item.category, () => [])
        .add(item.value);
  }

  final dates = categoriesByDate.keys.toList()..sort();
  return dates.map((date) {
    final categories = categoriesByDate[date]!;
    final snapshots =
        hourly.where((item) => _compactDate(item.observedAt) == date).toList();
    final temperatures =
        snapshots.map((item) => item.temperature).whereType<double>().toList();
    return _DirectDaily(
      date: date,
      minTemperature: _firstNumber(categories['TMN']) ?? _minimum(temperatures),
      maxTemperature: _firstNumber(categories['TMX']) ?? _maximum(temperatures),
      skyCondition: _representativeWeather(snapshots),
      weatherDataComplete: snapshots.isNotEmpty &&
          snapshots.every((item) => item.skyCondition != null) &&
          snapshots.last.observedAt
                      .difference(snapshots.first.observedAt)
                      .inHours +
                  1 ==
              snapshots.length,
      minTemperatureSource: _firstNumber(categories['TMN']) != null
          ? 'DAILY'
          : temperatures.isEmpty
              ? null
              : 'HOURLY',
      maxTemperatureSource: _firstNumber(categories['TMX']) != null
          ? 'DAILY'
          : temperatures.isEmpty
              ? null
              : 'HOURLY',
    );
  }).toList();
}

_DirectSnapshot? _snapshotFromSlot(
  String slotKey,
  Map<String, String> categories,
) {
  // TMN/TMX 전용 슬롯은 제외하지만, 기온만 누락된 시간대는 유지한다.
  const hourlyCategories = {
    'TMP',
    'REH',
    'WSD',
    'POP',
    'PCP',
    'SNO',
    'PTY',
    'SKY'
  };
  if (!categories.keys.any(hourlyCategories.contains)) return null;
  final temperature = _parseNumber(categories['TMP']);
  final precipitationType = _parseNumber(categories['PTY'])?.round();
  final precipitationProbability = _parseNumber(categories['POP']);
  final snowfallAmount = _parseAmount(categories['SNO']);
  return _DirectSnapshot(
    observedAt: _kmaSlotToDateTime(slotKey),
    temperature: temperature,
    humidity: _parseNumber(categories['REH']),
    windSpeed: _parseNumber(categories['WSD']),
    precipitationProbability: precipitationProbability,
    precipitationAmount: _parseAmount(categories['PCP']),
    precipitationAmountText: categories['PCP'],
    precipitationAmountLabel: _amountDisplayLabel(categories['PCP'], 'mm'),
    snowExpected: const [2, 3, 6, 7].contains(precipitationType) ||
            (snowfallAmount != null && snowfallAmount > 0)
        ? true
        : const [0, 1, 4, 5].contains(precipitationType)
            ? false
            : null,
    snowfallAmount: snowfallAmount,
    snowfallAmountLabel: _amountDisplayLabel(categories['SNO'], 'cm'),
    skyCondition: _weatherLabel(
      precipitationType,
      _parseNumber(categories['SKY'])?.round(),
    ),
  );
}

List<_BaseDateTime> _latestBaseDateTimes(DateTime now, int limit) {
  final effectiveKst = now
      .toUtc()
      .add(const Duration(hours: 9))
      .subtract(const Duration(minutes: 15));
  final candidates = <_BaseDateTime>[];
  for (var dayOffset = 0;
      candidates.length < limit && dayOffset < 3;
      dayOffset++) {
    final date = DateTime.utc(
      effectiveKst.year,
      effectiveKst.month,
      effectiveKst.day - dayOffset,
    );
    final currentMinutes = effectiveKst.hour * 60 + effectiveKst.minute;
    for (final hour in _publicationHours.reversed) {
      if (dayOffset == 0 && hour * 60 > currentMinutes) continue;
      candidates.add(
        _BaseDateTime(
          _formatKmaDate(date),
          '${hour.toString().padLeft(2, '0')}00',
        ),
      );
      if (candidates.length == limit) break;
    }
  }
  return candidates;
}

DateTime _kmaSlotToDateTime(String slotKey) {
  final year = int.parse(slotKey.substring(0, 4));
  final month = int.parse(slotKey.substring(4, 6));
  final day = int.parse(slotKey.substring(6, 8));
  final hour = int.parse(slotKey.substring(8, 10));
  final minute = int.parse(slotKey.substring(10, 12));
  return DateTime.utc(year, month, day, hour, minute)
      .subtract(const Duration(hours: 9));
}

String _weekdayLabel(String compactDate) {
  final date = DateTime.utc(
    int.parse(compactDate.substring(0, 4)),
    int.parse(compactDate.substring(4, 6)),
    int.parse(compactDate.substring(6, 8)),
  );
  return const ['일', '월', '화', '수', '목', '금', '토'][date.weekday % 7];
}

String _representativeWeather(List<_DirectSnapshot> snapshots) {
  const priority = [
    '눈',
    '비/눈',
    '소나기',
    '비',
    '눈날림',
    '빗방울/눈날림',
    '빗방울',
    '흐림',
    '구름 많음',
    '맑음',
  ];
  for (final label in priority) {
    if (snapshots.any((item) => item.skyCondition == label)) return label;
  }
  return '정보 없음';
}

String? _weatherLabel(int? precipitationType, int? skyCode) {
  const precipitationLabels = {
    1: '비',
    2: '비/눈',
    3: '눈',
    4: '소나기',
    5: '빗방울',
    6: '빗방울/눈날림',
    7: '눈날림',
  };
  // SKY만으로 강수 형태까지 확인됐다고 안내하지 않는다.
  if (precipitationType == 0) {
    return const {1: '맑음', 3: '구름 많음', 4: '흐림'}[skyCode];
  }
  return precipitationLabels[precipitationType];
}

double? _parseNumber(String? value) {
  final parsed = double.tryParse(value ?? '');
  return parsed?.isFinite == true ? parsed : null;
}

double? _parseAmount(String? value) {
  if (value == null) return null;
  if (value.trim() == '강수없음' || value.trim() == '적설없음') return 0;
  final match = RegExp(r'^\s*(\d+(?:[.,]\d+)?)').firstMatch(value);
  final number = _parseNumber(match?.group(1)?.replaceAll(',', '.'));
  if (number == null) return null;
  // 미만 구간의 상한을 정확한 양으로 사용하지 않는다. 표시는 원래 범위를 쓴다.
  return value.contains('미만') ? 0 : number;
}

String? _amountDisplayLabel(String? value, String unit) {
  if (value == null || value.contains('없음') || _parseAmount(value) == null) {
    return null;
  }
  final normalized = value.replaceAll(' ', '');
  if (normalized.isEmpty) return null;
  if (normalized.contains('미만')) {
    return '${normalized.replaceAll('미만', '').replaceAll(unit, '')}$unit 미만';
  }
  if (normalized.contains('이상')) {
    return '${normalized.replaceAll('이상', '').replaceAll(unit, '')}$unit 이상';
  }
  return normalized.contains(unit) ? normalized : '$normalized$unit';
}

double? _firstNumber(List<String>? values) {
  if (values == null) return null;
  for (final value in values) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  return null;
}

double? _minimum(List<double> values) {
  if (values.isEmpty) return null;
  return values.reduce((left, right) => left < right ? left : right);
}

double? _maximum(List<double> values) {
  if (values.isEmpty) return null;
  return values.reduce((left, right) => left > right ? left : right);
}

String _formatKmaDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}'
    '${date.month.toString().padLeft(2, '0')}'
    '${date.day.toString().padLeft(2, '0')}';

String _compactDate(DateTime date) => _formatKmaDate(
      date.toUtc().add(const Duration(hours: 9)),
    );

String _isoDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _kstIso(DateTime date) {
  final kst = date.toUtc().add(const Duration(hours: 9));
  return '${_isoDate(kst)}T${kst.hour.toString().padLeft(2, '0')}:'
      '${kst.minute.toString().padLeft(2, '0')}:00+09:00';
}

String _normalizeServiceKey(String value) {
  final trimmed = value.trim();
  try {
    return Uri.decodeComponent(trimmed);
  } on FormatException {
    return trimmed;
  }
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is! Map) return null;
  return value.map((key, value) => MapEntry(key.toString(), value));
}

class _BaseDateTime {
  final String date;
  final String time;

  const _BaseDateTime(this.date, this.time);
}

class _KmaItem {
  final String forecastDate;
  final String forecastTime;
  final String category;
  final String value;

  const _KmaItem({
    required this.forecastDate,
    required this.forecastTime,
    required this.category,
    required this.value,
  });

  static _KmaItem? fromJson(Map<String, dynamic> json) {
    final forecastDate = json['fcstDate']?.toString();
    final forecastTime = json['fcstTime']?.toString();
    final category = json['category']?.toString();
    final value = json['fcstValue']?.toString();
    if (forecastDate == null ||
        forecastTime == null ||
        category == null ||
        value == null) {
      return null;
    }
    return _KmaItem(
      forecastDate: forecastDate,
      forecastTime: forecastTime,
      category: category,
      value: value,
    );
  }
}

class _DirectSnapshot {
  final DateTime observedAt;
  final double? temperature;
  final double? humidity;
  final double? windSpeed;
  final double? precipitationProbability;
  final double? precipitationAmount;
  final String? precipitationAmountText;
  final String? precipitationAmountLabel;
  final bool? snowExpected;
  final double? snowfallAmount;
  final String? snowfallAmountLabel;
  final String? skyCondition;

  const _DirectSnapshot({
    required this.observedAt,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.precipitationProbability,
    required this.precipitationAmount,
    this.precipitationAmountText,
    required this.precipitationAmountLabel,
    required this.snowExpected,
    required this.snowfallAmount,
    required this.snowfallAmountLabel,
    required this.skyCondition,
  });

  double? get apparentTemperature {
    final availableTemperature = temperature;
    if (availableTemperature == null) return null;
    final forecastAtKst = observedAt.toUtc().add(const Duration(hours: 9));
    final summerInputsAvailable = forecastAtKst.month >= 5 &&
        forecastAtKst.month <= 9 &&
        humidity != null;
    final winterInputsAvailable =
        (forecastAtKst.month >= 10 || forecastAtKst.month <= 4) &&
            availableTemperature <= 10 &&
            windSpeed != null &&
            windSpeed! >= 1.3;
    if (!summerInputsAvailable && !winterInputsAvailable) return null;
    return calculateKmaApparentTemperature(
      availableTemperature,
      humidity: humidity,
      windSpeed: windSpeed,
      forecastAt: observedAt,
    );
  }
}

double calculateKmaApparentTemperature(
  double temperature, {
  double? humidity,
  double? windSpeed,
  required DateTime forecastAt,
}) {
  final forecastAtKst = forecastAt.toUtc().add(const Duration(hours: 9));
  final isSummer = forecastAtKst.month >= 5 && forecastAtKst.month <= 9;
  final isWinter = forecastAtKst.month >= 10 || forecastAtKst.month <= 4;

  if (isWinter && temperature <= 10 && (windSpeed ?? 0) >= 1.3) {
    final windKmh = (windSpeed ?? 0) * 3.6;
    return _roundOne(
      13.12 +
          0.6215 * temperature -
          11.37 * math.pow(windKmh, 0.16) +
          0.3965 * temperature * math.pow(windKmh, 0.16),
    );
  }
  if (isSummer && humidity != null) {
    final relativeHumidity = humidity.clamp(0, 100).toDouble();
    final wetBulbTemperature = temperature *
            math.atan(0.151977 * math.sqrt(relativeHumidity + 8.313659)) +
        math.atan(temperature + relativeHumidity) -
        math.atan(relativeHumidity - 1.67633) +
        0.00391838 *
            math.pow(relativeHumidity, 1.5) *
            math.atan(0.023101 * relativeHumidity) -
        4.686035;
    return _roundOne(
      -0.2442 +
          0.55399 * wetBulbTemperature +
          0.45535 * temperature -
          0.0022 * wetBulbTemperature * wetBulbTemperature +
          0.00278 * wetBulbTemperature * temperature +
          3.0,
    );
  }
  return _roundOne(temperature);
}

double _roundOne(num value) => (value * 10).round() / 10;

class _DirectDaily {
  final String date;
  final double? minTemperature;
  final double? maxTemperature;
  final String skyCondition;
  final bool weatherDataComplete;
  final String? minTemperatureSource;
  final String? maxTemperatureSource;

  const _DirectDaily({
    required this.date,
    required this.minTemperature,
    required this.maxTemperature,
    required this.skyCondition,
    required this.weatherDataComplete,
    this.minTemperatureSource,
    this.maxTemperatureSource,
  });
}
