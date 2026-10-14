/// 서버 응답 생성 시각을 한국시간 기준으로 표시한다.
String weatherRefreshLabel(String? generatedAt, {DateTime? now}) {
  final parsed = generatedAt == null ? null : DateTime.tryParse(generatedAt);
  final source = parsed ?? now ?? DateTime.now();
  final inKorea = source.isUtc ? source.add(const Duration(hours: 9)) : source;
  final period = inKorea.hour < 12 ? '오전' : '오후';
  final hour = inKorea.hour % 12 == 0 ? 12 : inKorea.hour % 12;
  final minute = inKorea.minute.toString().padLeft(2, '0');
  return '${inKorea.month}월 ${inKorea.day}일 $period $hour시 $minute분 기준';
}

String? humidityDescription(double? percent) {
  if (percent == null) return null;
  if (percent <= 35) return '건조';
  if (percent < 70) return '쾌적';
  if (percent < 80) return '습한 편';
  return '매우 습함';
}

String? apparentTemperatureDescription(double? celsius) {
  if (celsius == null) return null;
  if (celsius >= 38) return '위험한 더위';
  if (celsius >= 35) return '더위 경계';
  if (celsius >= 33) return '더위 주의';
  if (celsius >= 28) return '더움';
  if (celsius >= 20) return '조금 더움';
  if (celsius >= 10) return '선선한 편';
  if (celsius >= 0) return '쌀쌀한 편';
  return '추운 날씨';
}

String? windDescription(double? metersPerSecond) {
  if (metersPerSecond == null) return null;
  if (metersPerSecond < 4) return '약한 바람';
  if (metersPerSecond < 9) return '약간 강한 바람';
  if (metersPerSecond < 14) return '강한 바람';
  return '매우 강한 바람';
}

String? uvDescription(double? index) {
  if (index == null) return null;
  if (index <= 2) return '낮음';
  if (index <= 5) return '보통';
  if (index <= 7) return '높음';
  if (index <= 10) return '매우 높음';
  return '위험';
}

String? ozoneDescription(double? ppm) {
  if (ppm == null || ppm < 0) return null;
  if (ppm <= 0.03) return '좋음';
  if (ppm <= 0.09) return '보통';
  if (ppm <= 0.15) return '나쁨';
  return '매우 나쁨';
}

String? visibilityDescription(double? meters) {
  if (meters == null) return null;
  if (meters < 200) return '매우 짧음';
  if (meters < 1000) return '짧음';
  if (meters < 5000) return '나쁨';
  if (meters < 10000) return '보통';
  if (meters < 20000) return '좋음';
  return '매우 좋음';
}

const apparentTemperatureRanges = '표현 기준 (체감온도)\n'
    '0℃ 미만: 추운 날씨\n0~10℃ 미만: 쌀쌀한 편\n'
    '10~20℃ 미만: 선선한 편\n20~28℃ 미만: 조금 더움\n'
    '28~33℃ 미만: 더움\n33~35℃ 미만: 더위 주의\n'
    '35~38℃ 미만: 더위 경계\n38℃ 이상: 위험한 더위';

const humidityRanges = '표현 기준 (실외 상대습도)\n'
    '35% 이하: 건조\n35% 초과~70% 미만: 쾌적\n'
    '70% 이상~80% 미만: 습한 편\n80% 이상: 매우 습함';

const windRanges = '표현 기준 (풍속)\n'
    '4m/s 미만: 약한 바람\n4~9m/s 미만: 약간 강한 바람\n'
    '9~14m/s 미만: 강한 바람\n14m/s 이상: 매우 강한 바람';

const uvRanges = '표현 기준 (자외선지수)\n'
    '2 이하: 낮음\n2 초과~5 이하: 보통\n5 초과~7 이하: 높음\n'
    '7 초과~10 이하: 매우 높음\n10 초과: 위험';

const visibilityRanges = '표현 기준 (가시거리)\n'
    '200m 미만: 매우 짧음\n200m~1km 미만: 짧음\n'
    '1~5km 미만: 나쁨\n5~10km 미만: 보통\n'
    '10~20km 미만: 좋음\n20km 이상: 매우 좋음';
