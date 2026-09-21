import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/detail_tab.dart';
import 'package:weather_care/models/lifestyle_message.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/notification_destination.dart';

void main() {
  testWidgets('모든 근거와 자료 상태를 항목 제목별 카드로 표시한다', (tester) async {
    final statuses = List.generate(
        7,
        (index) => WeatherMessagePart(
              role: WeatherMessageRole.dataStatus,
              text: '자료 상태 원문 $index',
              itemTitle: '자료 항목 ${index % 3}',
            ));
    await _pump(tester, messages: _messages(8), statuses: statuses);
    for (var index = 0; index < 8; index++) {
      expect(find.text('생활 근거 $index'), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('detail-evidence-toggle')), findsNothing);
    for (final status in statuses) {
      expect(find.text(status.text), findsOneWidget);
    }
    expect(tester.getTopLeft(find.text('생활 근거 7')).dy,
        greaterThan(tester.getTopLeft(find.text('생활 근거 6')).dy));
    expect(find.text('자료 상태 원문 6'), findsOneWidget);
    expect(find.text('공통 자료 상태'), findsNothing);
    for (var index = 0; index < 3; index++) {
      expect(find.text('자료 항목 $index'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('5개 이하에는 더 보기나 불필요한 자료 상태 영역이 없다', (tester) async {
    await _pump(tester, messages: _messages(5));
    expect(find.text('생활 근거 4'), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-evidence-toggle')), findsNothing);
    expect(find.text('자료 상태'), findsNothing);
  });

  testWidgets('근거 없이 자료 상태만 있어도 원문을 모두 보여준다', (tester) async {
    const texts = [
      '자료를 받아오지 못해 현재 호우특보 상태를 확인하기 어려워요',
      '오후 2시 풍속은 자료에 오류가 있어 확인이 어려워요',
      '마지막 관측은 오후 1시 50분 자료예요 · 현재 상태는 달라졌을 수 있어요',
      '강수량, 초단기예보는 오후 4~5시 20~40mm, 단기예보는 같은 시간 30~50mm로 예상했어요',
    ];
    await _pump(tester, statuses: [
      for (final text in texts)
        WeatherMessagePart(role: WeatherMessageRole.dataStatus, text: text),
      const WeatherMessagePart(role: WeatherMessageRole.dataStatus, text: ' '),
    ]);
    expect(find.text('현재 예보에서 안내할 체크 항목과 근거가 없어요.'), findsNothing);
    expect(find.text('현재 조건에서는 별도 준비물 추천이 없어요.'), findsNothing);
    expect(find.textContaining('정상'), findsNothing);
    for (final text in texts) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.text(' '), findsNothing);
  });

  testWidgets('제공기간이 아닌 블랙아이스 자료는 카드 자체를 표시하지 않는다', (tester) async {
    const seasonalMessage =
        '블랙아이스(도로살얼음)는 현재 제공기간이 아닌 항목이에요 (11월 15일~3월 15일 제공)';
    await _pump(
      tester,
      statuses: const [
        WeatherMessagePart(
          role: WeatherMessageRole.dataStatus,
          text: seasonalMessage,
          itemTitle: '블랙아이스(도로살얼음)',
          retryable: false,
        ),
      ],
      onRetryData: () async {},
    );

    expect(find.text(seasonalMessage), findsNothing);
    expect(find.text('블랙아이스(도로살얼음)'), findsNothing);
    expect(find.byKey(const ValueKey('detail-data-retry-블랙아이스(도로살얼음)')),
        findsNothing);
  });

  testWidgets('재시도는 서버 저장 자료를 다시 받는 동작으로 안내한다', (tester) async {
    var retryCount = 0;
    await _pump(
      tester,
      statuses: const [
        WeatherMessagePart(
          role: WeatherMessageRole.dataStatus,
          text: '마지막으로 확인한 대기질은 오후 12시 자료예요',
          itemTitle: '대기질',
          retryable: true,
        ),
        WeatherMessagePart(
          role: WeatherMessageRole.dataStatus,
          text: '자외선지수 자료를 받아오지 못했어요',
          itemTitle: '자외선지수',
          retryable: true,
        ),
      ],
      onRetryData: () async => retryCount += 1,
    );

    expect(
      find.text(
        '서버에 저장된 대기질 자료를 다시 받아올 수 있어요. '
        '외부 자료는 서버가 다음 수집 주기에 다시 확인해요.',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '서버의 대기질 자료 다시 받기',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '서버의 자외선지수 자료 다시 받기',
      ),
      findsOneWidget,
    );
    final airQualityRetry = find.byKey(const ValueKey('detail-data-retry-대기질'));
    await tester.ensureVisible(airQualityRetry);
    await tester.pumpAndSettle();
    await tester.tap(airQualityRetry);
    await tester.pump();
    expect(retryCount, 1);
    final uvRetry = find.byKey(const ValueKey('detail-data-retry-자외선지수'));
    await tester.ensureVisible(uvRetry);
    await tester.pumpAndSettle();
    await tester.tap(uvRetry);
    await tester.pump();
    expect(retryCount, 2);
  });

  testWidgets('제목과 다른 첫 근거를 버리지 않고 역할을 보존한다', (tester) async {
    await _pump(tester, messages: [
      LifestyleMessage(
        type: LifestyleMessageType.outdoorCaution,
        title: '외출 전에 강풍 정보를 확인하세요',
        parts: const [
          WeatherMessagePart(
              role: WeatherMessageRole.officialFact,
              text: '수원에는 강풍주의보가 발효 중이에요'),
          WeatherMessagePart(
              role: WeatherMessageRole.internalPossibility,
              text: '강한 바람에 우산이 뒤집힐 수 있어요'),
          WeatherMessagePart(
              role: WeatherMessageRole.calculatedFact,
              text: '예보 풍속으로 계산한 값이에요'),
          WeatherMessagePart(
              role: WeatherMessageRole.dataStatus, text: '이전 자료와 차이가 있어요'),
        ],
      ),
    ]);
    expect(find.text('사용한 자료'), findsOneWidget);
    expect(find.text('수원에는 강풍주의보가 발효 중이에요'), findsOneWidget);
    expect(find.text('판단 근거'), findsOneWidget);
    expect(find.text('강한 바람에 우산이 뒤집힐 수 있어요'), findsOneWidget);
    expect(find.text('계산 근거'), findsOneWidget);
    expect(find.text('예보 풍속으로 계산한 값이에요'), findsOneWidget);
    expect(find.text('자료 상태'), findsOneWidget);
    expect(find.text('이전 자료와 차이가 있어요'), findsOneWidget);
  });

  testWidgets('판단 근거의 날씨챙겨 출처는 앱 자체 분석으로 표시한다', (tester) async {
    await _pump(tester, messages: [
      LifestyleMessage(
        type: LifestyleMessageType.rainGearUseful,
        title: '우산을 챙기세요',
        parts: const [
          WeatherMessagePart(
            role: WeatherMessageRole.internalPossibility,
            text: '비가 내릴 수 있어요',
            source: '날씨챙겨 계산',
          ),
        ],
      ),
    ]);

    expect(find.text('앱 자체 분석'), findsOneWidget);
    expect(find.textContaining('날씨챙겨'), findsNothing);
    expect(find.textContaining('제공처'), findsNothing);
    final provider = tester.widget<Text>(
      find.byKey(const ValueKey('detail-provider-앱 자체 분석')),
    );
    expect(provider.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('유효일시는 항목 제목 아래에 두고 모든 앱 계산 출처를 통일한다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester,
        messages: [
          LifestyleMessage(
            type: LifestyleMessageType.rapidTemperatureDrop,
            title: '기온이 빠르게 낮아져요',
            parts: const [
              WeatherMessagePart(
                role: WeatherMessageRole.appSuggestion,
                text: '겉옷을 준비하세요',
                validFrom: '2026-09-18T03:00:00Z',
                validUntil: '2026-09-19T02:59:00Z',
              ),
              WeatherMessagePart(
                role: WeatherMessageRole.calculatedFact,
                text: '기온 차를 계산했어요',
                source: 'APP_RULE_ENGINE',
              ),
              WeatherMessagePart(
                role: WeatherMessageRole.officialFact,
                text: '자외선지수 예보예요',
                source: '기상청 생활기상지수',
              ),
            ],
          ),
          LifestyleMessage(
            type: LifestyleMessageType.outdoorCaution,
            title: '12시간 유효 예보',
            parts: const [
              WeatherMessagePart(
                role: WeatherMessageRole.appSuggestion,
                text: '예보를 확인하세요',
                validFrom: '2026-09-18T03:00:00Z',
                validUntil: '2026-09-18T14:59:00Z',
              ),
            ],
          ),
          LifestyleMessage(
            type: LifestyleMessageType.rainGearUseful,
            title: '3시간 유효 예보',
            parts: const [
              WeatherMessagePart(
                role: WeatherMessageRole.appSuggestion,
                text: '우산을 챙기세요',
                validFrom: '2026-09-18T03:00:00Z',
                validUntil: '2026-09-18T05:59:00Z',
              ),
            ],
          ),
        ],
        scale: 1.3);

    const validPeriod = '9월 18일 12시~9월 19일 11시 59분 유효 (24H)';
    expect(find.text(validPeriod), findsOneWidget);
    expect(
      find.text('9월 18일 12시~9월 18일 23시 59분 유효 (12H)'),
      findsOneWidget,
    );
    expect(
      find.text('9월 18일 12시~9월 18일 14시 59분 유효 (3H)'),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('기온 하강')).dy,
      lessThan(tester.getTopLeft(find.text(validPeriod)).dy),
    );
    expect(find.text('앱 자체 분석'), findsOneWidget);
    expect(find.text('앱 계산'), findsNothing);
    for (final source in ['앱 자체 분석', '기상청 생활기상지수']) {
      final provider = tester.widget<Text>(
        find.byKey(ValueKey('detail-provider-$source')),
      );
      expect(provider.style?.fontWeight, FontWeight.w800);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('첫 문장이 제목과 같으면 한 번만 표시하고 공식 역할은 유지한다', (tester) async {
    const title = '수원에는 강풍주의보가 발효 중이에요';
    await _pump(tester, messages: [
      LifestyleMessage(
        type: LifestyleMessageType.outdoorCaution,
        title: title,
        parts: const [
          WeatherMessagePart(
              role: WeatherMessageRole.officialFact, text: title),
          WeatherMessagePart(
              role: WeatherMessageRole.appSuggestion,
              text: '외출 전 강풍 정보를 확인하세요'),
        ],
      ),
    ]);
    expect(find.text(title), findsOneWidget);
    expect(find.text('사용한 자료'), findsOneWidget);
    expect(find.text('체크할 일'), findsOneWidget);
    expect(find.text('외출 전 강풍 정보를 확인하세요'), findsOneWidget);
  });

  testWidgets('알림 근거가 없어졌다고 다른 근거를 강조하거나 안전하다고 안내하지 않는다', (tester) async {
    await _pump(tester,
        messages: _messages(6), focusTopic: NotificationTopic.commute);
    expect(find.text('이 알림과 연결된 근거가 현재 자료에 없어요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-focused-evidence')), findsNothing);
    expect(find.textContaining('안전'), findsNothing);
    expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('detail-focus-unavailable')))
            .dy,
        inInclusiveRange(0, 600));

    await _pump(tester,
        messages: [
          ..._messages(6),
          LifestyleMessage(
              type: LifestyleMessageType.commuteRouteCaution,
              title: '출퇴근 경로 근거'),
        ],
        focusTopic: NotificationTopic.commute);
    expect(
        find.byKey(const ValueKey('detail-focus-unavailable')), findsNothing);
    expect(
        find.byKey(const ValueKey('detail-focused-evidence')), findsOneWidget);
    expect(find.text('출퇴근 경로 근거'), findsOneWidget);
  });

  testWidgets('사용자가 선택한 근거의 부재는 알림과 구분한다', (tester) async {
    await _pump(tester,
        focusType: LifestyleMessageType.petWalkWindow,
        focusSource: DetailFocusSource.selection);
    expect(find.text('선택한 항목의 근거가 현재 자료에 없어요.'), findsOneWidget);
    expect(find.text('이 알림과 연결된 근거가 현재 자료에 없어요.'), findsNothing);
    expect(find.text('현재 예보에서 안내할 체크 항목과 근거가 없어요.'), findsNothing);
  });

  testWidgets('360px·2배 글씨에서도 선택 근거로 바로 이동하고 전체 근거를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester,
        messages: [
          ..._messages(7),
          LifestyleMessage(
              type: LifestyleMessageType.petWalkWindow,
              title: '가능하다면 산책시간을 오후 8시로 옮기세요'),
        ],
        statuses: const [
          WeatherMessagePart(
              role: WeatherMessageRole.dataStatus,
              text: '자료를 받아오지 못해 현재 강수 상태를 확인하기 어려워요',
              itemTitle: '현재 강수'),
        ],
        focusType: LifestyleMessageType.petWalkWindow,
        focusSource: DetailFocusSource.selection,
        scale: 2);
    final focused = find.byKey(const ValueKey('detail-focused-evidence'));
    expect(focused, findsOneWidget);
    expect(tester.getTopLeft(focused).dy, inInclusiveRange(0, 600));
    expect(find.text('생활 근거 6'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('detail-data-status-현재 강수')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('자료나 지역이 바뀌어도 받은 근거 전체를 표시한다', (tester) async {
    await _pump(tester, messages: _messages(7));
    await _pump(tester, messages: _messages(8));
    expect(find.text('생활 근거 7'), findsOneWidget);
    await _pump(tester, messages: _messages(8), regionNx: 61);
    expect(find.text('생활 근거 7'), findsOneWidget);
  });

  testWidgets('직접 조회에서는 서버 근거를 빈 추천으로 오인하지 않는다', (tester) async {
    await _pump(tester,
        messages: _messages(7),
        serverAvailable: false,
        focusType: LifestyleMessageType.petWalkWindow);
    expect(find.text('근거와 자료'), findsOneWidget);
    expect(find.text('운영 서버 미연결로 미지원'), findsOneWidget);
    expect(find.text('생활 근거 0'), findsNothing);
    expect(
        find.byKey(const ValueKey('detail-focus-unavailable')), findsNothing);
    expect(find.byKey(const ValueKey('detail-evidence-toggle')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('전체 근거와 상태가 비어 있으면 빈 안내만 표시한다', (tester) async {
    await _pump(tester);
    expect(find.text('현재 예보에서 안내할 체크 항목과 근거가 없어요.'), findsOneWidget);
    expect(find.text('자료 상태'), findsNothing);
    expect(find.byKey(const ValueKey('detail-evidence-toggle')), findsNothing);
    expect(
        find.byKey(const ValueKey('detail-focus-unavailable')), findsNothing);
  });
}

List<LifestyleMessage> _messages(int count) => List.generate(
    count,
    (index) => LifestyleMessage(
          type: LifestyleMessageType.outerwearUseful,
          title: '생활 근거 $index',
        ));

Future<void> _pump(
  WidgetTester tester, {
  List<LifestyleMessage> messages = const [],
  List<WeatherMessagePart> statuses = const [],
  NotificationTopic? focusTopic,
  LifestyleMessageType? focusType,
  DetailFocusSource focusSource = DetailFocusSource.notification,
  bool serverAvailable = true,
  Future<void> Function()? onRetryData,
  int regionNx = 60,
  double scale = 1,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: DetailTab(
          today: TodayWeatherResponse(
            dataSource: 'test',
            region: WeatherRegion(nx: regionNx, ny: 121, name: '수원'),
            brief: '테스트',
            current: const CurrentWeather(temperature: null),
            recommendations: const [],
            lifestyleMessages: messages,
            dataStatusMessages: statuses,
            timeline: const [],
            hourly: const [],
          ),
          recommendations: const [],
          serverFeaturesAvailable: serverAvailable,
          focusTopic: focusTopic,
          focusLifestyleType: focusType,
          focusSource: focusSource,
          onRefresh: () async {},
          onRetryData: onRetryData,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}
