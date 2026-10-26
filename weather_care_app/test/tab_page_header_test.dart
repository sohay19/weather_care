import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/widgets/tab_page_header.dart';
import 'package:weather_care/theme/weather_theme.dart';

void main() {
  const longTitle = '강원특별자치도 평창군 대관령면 횡계리 지역의 날씨';
  const subtitle = '예보 기준 구역 지도를 확인할 수 있어요';

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('좁은 화면·글자 $scale배에서 긴 지역명은 한 줄로 들어가고 메뉴는 세 행을 포함한다',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
        theme: WeatherCareTheme.light(),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Center(
              child: SizedBox(
                width: 300,
                child: TabPageHeader(
                  key: const ValueKey('header'),
                  eyebrow: '10월 26일 오후 12시 기준',
                  title: longTitle,
                  subtitle: subtitle,
                  showRegionMenu: true,
                  singleLineTitle: true,
                  onOpenRegionMenu: () => opened++,
                  subtitleTrailing: const SizedBox(
                    width: 28,
                    height: 28,
                    child: Icon(Icons.info_outline_rounded),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final header = find.byKey(const ValueKey('header'));
      final menu = find.byKey(const ValueKey('main-region-menu'));
      final title = find.text(longTitle);
      final paragraph = tester.renderObject<RenderParagraph>(title);
      final menuRect = tester.getRect(menu);
      final headerRect = tester.getRect(header);
      final titleBottom = tester.getBottomRight(title);
      final iconRect = tester.getRect(find.byIcon(Icons.menu_rounded));

      expect(menuRect.top, closeTo(headerRect.top, 0.01));
      expect(menuRect.bottom, closeTo(headerRect.bottom, 0.01));
      expect(iconRect.top, greaterThanOrEqualTo(menuRect.top));
      expect(iconRect.bottom, lessThanOrEqualTo(menuRect.bottom));
      expect(titleBottom.dx, lessThanOrEqualTo(headerRect.right + 0.01));
      expect(titleBottom.dy - tester.getTopLeft(title).dy,
          lessThan(paragraph.size.height));
      expect(
          paragraph.getBoxesForSelection(const TextSelection(
              baseOffset: 0, extentOffset: longTitle.length)),
          hasLength(1));

      await tester.tapAt(Offset(menuRect.center.dx, menuRect.top + 2));
      await tester.pumpAndSettle();
      await tester.tapAt(Offset(menuRect.center.dx, menuRect.bottom - 2));
      await tester.pumpAndSettle();
      expect(opened, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
