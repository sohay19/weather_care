import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/settings_guide.dart';
import 'package:weather_care/features/settings/settings_guide_screen.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/theme/weather_theme.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first, maxScrolls: 90);
  await tester.pumpAndSettle();
}

Widget guideApp(SettingsGuide guide,
        {Future<bool> Function(Uri)? openLink, bool largeText = false}) =>
    MaterialApp(
      theme: WeatherCareTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
        child: child!,
      ),
      home: SettingsGuideScreen(guide: guide, openLink: openLink),
    );

void main() {
  testWidgets('360px·2배 글씨의 설정 하단에서 모든 안내 항목을 누를 수 있다', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: WeatherCareTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: const SettingsScreen(),
    ));
    for (final guide in SettingsGuide.values) {
      final entry = find.byKey(ValueKey('guide-entry-${guide.name}'));
      await reveal(tester, entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(
          find.byKey(ValueKey('settings-guide-${guide.name}')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  for (final guide in SettingsGuide.values) {
    testWidgets('${guide.title}: 알림을 꺼도 안내를 열고 설정으로 돌아온다', (tester) async {
      var sideEffects = 0;
      Future<void> track() async => sideEffects++;
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          initialSettings: AppSettings.fallback('test')
              .copyWith(notificationEnabled: false, locationMode: 'MANUAL'),
          onSettingsChanged: (_) => track(),
          onLocate: track,
          onRequestNotificationPermission: track,
          onOpenNotificationSettings: track,
          onOpenLocationSettings: track,
        ),
      ));
      final entry = find.byKey(ValueKey('guide-entry-${guide.name}'));
      await reveal(tester, entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(
          find.byKey(ValueKey('settings-guide-${guide.name}')), findsOneWidget);
      expect(find.text(guide.sections.first.title), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsGuideScreen), findsNothing);
      expect(
          tester
              .widget<SettingsScreen>(find.byType(SettingsScreen))
              .initialSettings!
              .notificationEnabled,
          isFalse);
      expect(sideEffects, 0);
    });

    testWidgets('${guide.title}: 360px·2배 글씨로 모든 본문과 링크를 읽는다', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(guideApp(guide, largeText: true));
      for (final section in guide.sections) {
        await reveal(tester, find.text(section.title));
        for (final paragraph in section.paragraphs) {
          await reveal(tester, find.text(paragraph));
          expect(tester.takeException(), isNull);
        }
        for (final link in section.links) {
          await reveal(tester, find.text('${link.label} · 외부 브라우저'));
          expect(tester.takeException(), isNull);
        }
      }
    });
  }

  for (final entry in {
    'location-guide': SettingsGuide.location,
    'notification-guide': SettingsGuide.notifications,
  }.entries) {
    testWidgets('${entry.key}: 권한 제어 옆에서 설명만 연다', (tester) async {
      var requested = false;
      await tester.pumpWidget(MaterialApp(
          home: SettingsScreen(
        onLocate: () async => requested = true,
        onRequestNotificationPermission: () async => requested = true,
      )));
      final button = find.byKey(ValueKey(entry.key));
      await reveal(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('settings-guide-${entry.value.name}')),
          findsOneWidget);
      expect(requested, isFalse);
    });
  }

  test('출처 안내가 모든 운영 자료 종류와 내부 판단의 한계를 포함한다', () {
    final sources = SettingsGuide.sources.sections
        .expand((section) => [section.title, ...section.paragraphs])
        .join('\n');
    for (final term in [
      '기상청',
      '예상기온은 예보값',
      '관측분석',
      '레이더',
      '에어코리아',
      '오존',
      '도로 결빙',
      '블랙아이스(도로살얼음)',
      'ITS',
      '도로통제',
      '앱의 판단',
      '모든 환경자료의 전국 지원',
      '기상청 직접 조회',
    ]) {
      expect(sources, contains(term));
    }
    final data = SettingsGuide.dataUse.sections
        .expand((section) => section.paragraphs)
        .join('\n');
    for (final term in [
      '식별자',
      '위도·경도',
      '토큰',
      '알림 상태와 이력',
      '삭제 기능이 아니에요',
      'Firebase Analytics',
      'Google Mobile Ads',
      '개인정보처리방침을 대신하지 않아요',
      '사용 시점부터 1년',
      '발송 시점부터 1년',
      '10분마다',
      '2월 28일',
      '백업·운영 로그와 Firebase·광고 서비스의 보유기간을 뜻하지는 않아요',
    ]) {
      expect(data, contains(term));
    }
  });

  test('외부 링크는 공식 HTTPS 주소이며 사용자 정보나 API 키를 포함하지 않는다', () {
    const hosts = {
      'www.weather.go.kr',
      'apihub.kma.go.kr',
      'www.airkorea.or.kr',
      'www.its.go.kr',
      'firebase.google.com',
      'support.google.com',
      'policies.google.com',
      'weather-care-privacy.pages.dev',
    };
    final links = SettingsGuide.values
        .expand((guide) => guide.sections)
        .expand((section) => section.links);
    expect(links.length, 9);
    for (final link in links) {
      final uri = Uri.parse(link.url);
      expect(uri.scheme, 'https');
      expect(hosts, contains(uri.host));
      expect(uri.userInfo, isEmpty);
      expect(uri.queryParameters.keys.every((key) => key == 'hl'), isTrue);
      expect(uri.fragment, isEmpty);
    }
  });

  testWidgets('출처 버튼은 지정된 공식 주소만 열고 대기 중 중복 실행을 막는다', (tester) async {
    final calls = <Uri>[];
    final pending = Completer<bool>();
    await tester.pumpWidget(guideApp(SettingsGuide.sources, openLink: (uri) {
      calls.add(uri);
      return pending.future;
    }));
    final button = find.text('기상청 날씨누리 · 외부 브라우저');
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    expect(calls.map((uri) => uri.toString()),
        ['https://www.weather.go.kr/w/index.do']);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final throwsError in [false, true]) {
    testWidgets('브라우저 ${throwsError ? '예외' : '실패'}면 주소 확인·복사로 복구한다',
        (tester) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester
          .pumpWidget(guideApp(SettingsGuide.sources, openLink: (_) async {
        if (throwsError) throw StateError('private error');
        return false;
      }));
      final button = find.text('기상청 날씨누리 · 외부 브라우저');
      await reveal(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('링크를 열지 못했어요'), findsOneWidget);
      expect(find.textContaining('private error'), findsNothing);
      expect(find.text('https://www.weather.go.kr/w/index.do'), findsOneWidget);
      await tester.tap(find.text('주소 복사'));
      await tester.pumpAndSettle();
      expect(copied, 'https://www.weather.go.kr/w/index.do');
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('외부 링크를 여는 중 화면을 닫아도 뒤늦은 실패를 표시하지 않는다', (tester) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
        guideApp(SettingsGuide.sources, openLink: (_) => pending.future));
    final button = find.text('기상청 날씨누리 · 외부 브라우저');
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('주소 복사 실패를 성공으로 표시하지 않고 주소를 남긴다', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard_unavailable');
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
        guideApp(SettingsGuide.sources, openLink: (_) async => false));
    final button = find.text('기상청 날씨누리 · 외부 브라우저');
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('주소 복사'));
    await tester.pumpAndSettle();
    expect(find.textContaining('주소를 복사하지 못했어요'), findsOneWidget);
    expect(find.text('주소를 복사했어요.'), findsNothing);
    expect(find.text('https://www.weather.go.kr/w/index.do'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
