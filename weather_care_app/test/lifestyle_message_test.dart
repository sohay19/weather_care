import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/lifestyle_message.dart';

void main() {
  test('블랙아이스 API 항목을 공식 앱 명칭으로 표시한다', () {
    final message = LifestyleMessage.fromJson({
      'type': 'BLACK_ICE_CAUTION',
      'title': '출발 전에 최신 도로정보를 확인하세요',
      'parts': [
        {
          'role': 'APP_SUGGESTION',
          'text': '출발 전에 최신 도로정보를 확인하세요',
        },
      ],
    });

    expect(message.type, LifestyleMessageType.blackIceCaution);
    expect(message.type.title, '블랙아이스(도로살얼음)');
  });
}
