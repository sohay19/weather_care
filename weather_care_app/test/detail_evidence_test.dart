import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/detail_tab.dart';
import 'package:weather_care/models/lifestyle_message.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/notification_destination.dart';

void main() {
  testWidgets('5개 뒤의 근거는 더 보기로 확인하고 자료 상태는 접지 않는다', (tester) async {
    final statuses = List.generate(
        7,
        (index) => WeatherMessagePart(
              role: WeatherMessageRole.dataStatus,
              text: '자료 상태 원문 $index',
            ));
    await _pump(tester, messages: _messages(8), statuses: statuses);
    expect(find.text('생활 근거 4'), findsOneWidget);
    expect(find.text('생활 근거 5'), findsNothing);
    expect(find.text('근거 3개 더 보기'), findsOneWidget);
    for (final status in statuses) {
      expect(find.text(status.text), findsOneWidget);
    }

    await _toggle(tester);
    for (var index = 0; index < 8; index++) {
      expect(find.text('생활 근거 $index'), findsOneWidget);
    }
    expect(find.text('기본 5개만 보기'), findsOneWidget);
    expect(tester.getTopLeft(find.text('생활 근거 7')).dy,
        greaterThan(tester.getTopLeft(find.text('생활 근거 6')).dy));
    await _toggle(tester);
    expect(find.text('생활 근거 5'), findsNothing);
    expect(find.text('자료 상태 원문 6'), findsOneWidget);
    expect(tester.getTopLeft(find.text('근거와 자료')).dy, inInclusiveRange(0, 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('5개 이하에는 더 보기나 불필요한 자료 상태 영역이 없다', (tester) async {
    await _pump(tester, messages: _messages(5));
    expect(find.text('생활 근거 4'), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-evidence-toggle')), findsNothing);
    expect(find.byKey(const ValueKey('detail-data-status')), findsNothing);
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
    expect(find.text('현재 자료에 표시할 생활 안내 근거가 없어요.'), findsOneWidget);
    expect(find.text('현재 조건에서는 별도 준비물 추천이 없어요.'), findsNothing);
    expect(find.textContaining('정상'), findsNothing);
    for (final text in texts) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.text(' '), findsNothing);
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
    expect(find.text('공식 정보 · 수원에는 강풍주의보가 발효 중이에요'), findsOneWidget);
    expect(find.text('발생 가능성 · 강한 바람에 우산이 뒤집힐 수 있어요'), findsOneWidget);
    expect(find.text('앱 계산 · 예보 풍속으로 계산한 값이에요'), findsOneWidget);
    expect(find.text('자료 상태 · 이전 자료와 차이가 있어요'), findsOneWidget);
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
    expect(find.text('공식 정보'), findsOneWidget);
    expect(find.text('추천 행동 · 외출 전 강풍 정보를 확인하세요'), findsOneWidget);
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
    expect(find.text('현재 자료에 표시할 생활 안내 근거가 없어요.'), findsNothing);
  });

  testWidgets('360px·2배 글씨에서도 화면 밖 근거로 바로 이동하고 더 보기를 조작한다', (tester) async {
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
              text: '자료를 받아오지 못해 현재 강수 상태를 확인하기 어려워요'),
        ],
        focusType: LifestyleMessageType.petWalkWindow,
        focusSource: DetailFocusSource.selection,
        scale: 2);
    final focused = find.byKey(const ValueKey('detail-focused-evidence'));
    expect(focused, findsOneWidget);
    expect(tester.getTopLeft(focused).dy, inInclusiveRange(0, 600));
    await _toggle(tester);
    expect(find.text('생활 근거 6'), findsOneWidget);
    await _toggle(tester);
    expect(find.text('생활 근거 6'), findsNothing);
    expect(find.byKey(const ValueKey('detail-data-status')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('같은 지역의 새 자료에는 펼침을 유지하고 지역 변경 때 초기화한다', (tester) async {
    await _pump(tester, messages: _messages(7));
    await _toggle(tester);
    await _pump(tester, messages: _messages(8));
    expect(find.text('생활 근거 7'), findsOneWidget);
    await _pump(tester, messages: _messages(8), regionNx: 61);
    expect(find.text('생활 근거 5'), findsNothing);
    expect(find.text('근거 3개 더 보기'), findsOneWidget);
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
    expect(find.text('현재 자료에 표시할 생활 안내 근거가 없어요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-data-status')), findsNothing);
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

Future<void> _toggle(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('detail-evidence-toggle'));
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  List<LifestyleMessage> messages = const [],
  List<WeatherMessagePart> statuses = const [],
  NotificationTopic? focusTopic,
  LifestyleMessageType? focusType,
  DetailFocusSource focusSource = DetailFocusSource.notification,
  bool serverAvailable = true,
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
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}
