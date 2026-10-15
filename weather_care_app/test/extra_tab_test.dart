import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/extra_tab.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/kma_grid.dart';

class _ExtraApi extends ApiClient {
  _ExtraApi() : super(baseUrl: 'https://example.invalid');

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async {
    if (path.endsWith('/catalog')) {
      return {'groups': [
        {'source': 'KMA_LIGHTNING', 'title': '낙뢰', 'scope': 'grid',
          'period': 'hourly', 'targets': [{'id': '60_121', 'name': '현재 격자'}]},
        {'source': 'KWATER_DAM', 'title': '댐·보 운영', 'scope': 'dam',
          'period': 'hourly', 'targets': [
            {'id': '2022510', 'name': '첫째댐'},
            {'id': '2022511', 'name': '둘째댐'},
          ]},
      ]};
    }
    if (query?['source'] == 'KMA_LIGHTNING') {
      return {'records': [{'time': '2026-10-14T10:00:00',
        'values': {'count': 2}}]};
    }
    return {'records': [{'time': '2026-10-14 11:00',
      'values': {'levelM': 20.5, 'inflowM3PerSec': 4.2}}]};
  }
}

void main() {
  testWidgets('처음부터 수집된 자료를 보여주고 격자 낙뢰도 선택할 수 있다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ExtraTab(
      client: _ExtraApi(), grid: const KmaGrid(nx: 60, ny: 121), active: true))));
    await tester.pumpAndSettle();
    expect(find.text('수위  20.5m'), findsOneWidget);
    await tester.tap(find.text('낙뢰').first);
    await tester.pumpAndSettle();
    expect(find.text('낙뢰 발생  2회'), findsOneWidget);
    await tester.tap(find.text('댐·보 운영').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('첫째댐 변경'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('둘째댐').last);
    await tester.pumpAndSettle();
    expect(find.text('수위  20.5m'), findsOneWidget);
    expect(find.text('유입량  4.2㎥/s'), findsOneWidget);
  });
}
