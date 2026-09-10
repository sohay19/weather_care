String dateInKorea(DateTime instant) => instant
    .toUtc()
    .add(const Duration(hours: 9))
    .toIso8601String()
    .substring(0, 10);

Duration untilKoreaMidnight(DateTime instant) {
  final korea = instant.toUtc().add(const Duration(hours: 9));
  return DateTime.utc(korea.year, korea.month, korea.day + 1).difference(korea);
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
