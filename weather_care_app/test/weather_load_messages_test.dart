import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/widgets/weather_status_view.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/weather_service.dart';

class _FailedApiClient extends ApiClient {
  _FailedApiClient() : super(baseUrl: 'https://example.invalid');

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async =>
      throw StateError('connection failed');
}

void main() {
  testWidgets('날씨 요청 대기와 서버 연결 실패 문구를 구분한다', (tester) async {
    Widget view({required bool loading}) => MaterialApp(
          home: Scaffold(
            body: WeatherStatusView(
              viewKey: 'weather-status',
              loading: loading,
              offline: !loading,
              message: loading ? '요청 중' : '운영 서버에 연결하지 못했습니다.',
              onRetry: () async {},
            ),
          ),
        );

    await tester.pumpWidget(view(loading: true));
    expect(find.text('날씨 정보를 불러오고 있어요'), findsOneWidget);
    expect(find.text('서버에서 날씨를 불러오지 못했어요'), findsNothing);

    await tester.pumpWidget(view(loading: false));
    expect(find.text('서버에서 날씨를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('날씨 정보를 불러오고 있어요'), findsNothing);
  });

  test('어제 비교 요청 실패는 정상 응답의 자료 없음과 구분한다', () async {
    final result = await WeatherService(_FailedApiClient())
        .fetchYesterdayComparison(installationId: 'test');

    expect(result.requestFailed, isTrue);
    expect(result.comparisonAvailable, isFalse);
    expect(const ComparisonResponse.unavailable().requestFailed, isFalse);
  });
}
