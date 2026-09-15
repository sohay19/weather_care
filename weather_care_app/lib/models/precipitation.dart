import '../utils/korea_date.dart';

/// A source-confirmed one-hour precipitation window, with an exclusive end.
class PrecipitationPeriod {
  final DateTime start;
  final DateTime end;

  const PrecipitationPeriod({required this.start, required this.end});

  static PrecipitationPeriod? fromJson(Object? value, Object? forecastAt) {
    if (value is! Map<String, dynamic>) return null;
    DateTime? parse(Object? raw) {
      if (raw is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:00:00(?:\.000)?(?:Z|\+09:00)$')
              .hasMatch(raw) ||
          parseForecastDate(raw.substring(0, 10)) == null ||
          int.parse(raw.substring(11, 13)) >= 24) {
        return null;
      }
      return DateTime.tryParse(raw)?.toUtc();
    }

    final start = parse(value['start']);
    final end = parse(value['end']);
    if (start == null ||
        end == null ||
        end != parse(forecastAt) ||
        end.difference(start) != const Duration(hours: 1)) {
      return null;
    }
    return PrecipitationPeriod(start: start, end: end);
  }

  String get date => dateInKorea(start);

  String get label {
    final first = start.toUtc().add(const Duration(hours: 9)).hour;
    final last = end.toUtc().add(const Duration(hours: 9)).hour;
    return '$first~${last == 0 ? 24 : last}시';
  }
}

/// Preserves the source PCP text until range-aware aggregation in the UI.
class DailyPrecipitationDetail {
  final String kind;
  final List<PrecipitationHour> hours;
  final double? extendedMaxProbability;
  final double? observedAmount;

  const DailyPrecipitationDetail({
    required this.kind,
    required this.hours,
    this.extendedMaxProbability,
    this.observedAmount,
  });

  static DailyPrecipitationDetail? fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        !const ['HOURLY', 'EXTENDED', 'OBSERVATION'].contains(value['kind']) ||
        value['hours'] is! List) {
      return null;
    }
    final hours = value['hours'] as List;
    // A daily one-hour series cannot exceed 24 entries. Keep malformed rows so
    // filtering them out cannot silently turn a broken total into a valid one.
    if (hours.length > 24) return null;
    return DailyPrecipitationDetail(
      kind: value['kind'] as String,
      hours: hours.map(PrecipitationHour.fromJson).toList(),
      extendedMaxProbability:
          precipitationProbability(value['extendedMaxProbability']),
      observedAmount: _nonNegativeAmount(value['observedAmount']),
    );
  }
}

double? _nonNegativeAmount(Object? value) {
  final number = value is num ? value.toDouble() : null;
  return number != null && number.isFinite && number >= 0 && number <= 2000
      ? number
      : null;
}

class PrecipitationHour {
  /// End of the previous one-hour interval, in UTC.
  final DateTime? forecastAt;
  final double? probability;
  final PrecipitationAmount? amount;

  const PrecipitationHour({this.forecastAt, this.probability, this.amount});

  factory PrecipitationHour.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return const PrecipitationHour();
    final rawAt = value['forecastAt'];
    DateTime? at;
    if (rawAt is String &&
        RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:00:00(?:Z|\+09:00)$')
            .hasMatch(rawAt) &&
        parseForecastDate(rawAt.substring(0, 10)) != null &&
        int.parse(rawAt.substring(11, 13)) < 24) {
      at = DateTime.tryParse(rawAt)?.toUtc();
    }
    return PrecipitationHour(
      forecastAt: at,
      probability: precipitationProbability(value['probability']),
      amount: PrecipitationAmount.parse(value['amountText']),
    );
  }
}

double? precipitationProbability(Object? value) {
  final number = value is num ? value.toDouble() : null;
  return number != null && number.isFinite && number >= 0 && number <= 100
      ? number
      : null;
}

/// Thousandths of a millimetre avoid floating-point drift while adding bounds.
class PrecipitationAmount {
  final int lower;
  final int? upper;
  final bool upperExclusive;

  const PrecipitationAmount(this.lower, this.upper,
      {this.upperExclusive = false});

  static PrecipitationAmount? parse(Object? raw) {
    if (raw is! String) return null;
    final value = raw.replaceAll(RegExp(r'\s'), '').toLowerCase();
    if (value == '강수없음' || value == '0') {
      return const PrecipitationAmount(0, 0);
    }
    // Require mm: unitless positive values may be qualitative forecast codes.
    const number = r'(\d{1,6}(?:[.,]\d{1,3})?)';
    final match =
        RegExp('^$number(?:[~-]$number)?mm(미만|이상)?\$').firstMatch(value);
    if (match == null) return null;
    int scaled(String text) {
      final parts = text.replaceAll(',', '.').split('.');
      return int.parse(parts[0]) * 1000 +
          int.parse(parts.length == 1 ? '0' : parts[1].padRight(3, '0'));
    }

    final first = scaled(match.group(1)!);
    final second = match.group(2);
    final qualifier = match.group(3);
    if (second != null) {
      final last = scaled(second);
      if (qualifier != null || first > last) return null;
      return PrecipitationAmount(first, last);
    }
    if (qualifier == '미만') {
      return first == 0
          ? null
          : PrecipitationAmount(0, first, upperExclusive: true);
    }
    if (qualifier == '이상') return PrecipitationAmount(first, null);
    return PrecipitationAmount(first, first);
  }

  PrecipitationAmount plus(PrecipitationAmount other) => PrecipitationAmount(
        lower + other.lower,
        upper == null || other.upper == null ? null : upper! + other.upper!,
        upperExclusive: upperExclusive || other.upperExclusive,
      );

  bool get isZero => lower == 0 && upper == 0;

  String get label {
    String mm(int value) =>
        (value / 1000).toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    if (upper == null) return '${mm(lower)}mm 이상';
    if (lower == upper) return '${mm(lower)}mm';
    if (upperExclusive) {
      return lower == 0
          ? '${mm(upper!)}mm 미만'
          : '${mm(lower)}mm 이상 ${mm(upper!)}mm 미만';
    }
    return '${mm(lower)}~${mm(upper!)}mm';
  }
}
