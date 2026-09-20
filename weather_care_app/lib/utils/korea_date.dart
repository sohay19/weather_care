String dateInKorea(DateTime instant) => instant
    .toUtc()
    .add(const Duration(hours: 9))
    .toIso8601String()
    .substring(0, 10);

Duration untilKoreaMidnight(DateTime instant) {
  final korea = instant.toUtc().add(const Duration(hours: 9));
  return DateTime.utc(korea.year, korea.month, korea.day + 1).difference(korea);
}

Duration untilNextKoreaHour(DateTime instant) {
  final korea = instant.toUtc().add(const Duration(hours: 9));
  return DateTime.utc(
    korea.year,
    korea.month,
    korea.day,
    korea.hour + 1,
  ).difference(korea);
}

String koreaHourKey(DateTime instant) {
  final korea = instant.toUtc().add(const Duration(hours: 9));
  return '${korea.year.toString().padLeft(4, '0')}-'
      '${korea.month.toString().padLeft(2, '0')}-'
      '${korea.day.toString().padLeft(2, '0')}T'
      '${korea.hour.toString().padLeft(2, '0')}';
}

// A forecast date is a Korean calendar day, not an instant in device time.
DateTime? parseForecastDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
    return null;
  }
  return parsed;
}
