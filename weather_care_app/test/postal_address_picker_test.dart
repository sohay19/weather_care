import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/postal_address_picker_screen.dart';
import 'package:weather_care/models/postal_address.dart';

void main() {
  test('도로명·지번 중 어느 쪽을 골라도 제공된 두 주소를 보존한다', () {
    for (final type in ['R', 'J']) {
      final address = PostalAddress.fromJson({
        'roadAddress': '경기 시흥시 은계로 114',
        'jibunAddress': '경기 시흥시 은행동 669-1',
        'userSelectedType': type,
      });
      expect(address.roadAddress, '경기 시흥시 은계로 114');
      expect(address.jibunAddress, '경기 시흥시 은행동 669-1');
      expect(address.locationQuery, '경기 시흥시 은계로 114');
      expect(address.roadEstimated, isFalse);
      expect(address.jibunEstimated, isFalse);
    }
  });

  test('자동 연결된 주소는 예상으로 구분하고 확정 주소만 좌표 조회에 사용한다', () {
    final address = PostalAddress.fromJson({
      'jibunAddress': '경기 시흥시 은행동 669-1',
      'autoRoadAddress': '경기 시흥시 은계로 114',
    });
    expect(address.roadEstimated, isTrue);
    expect(address.locationQuery, address.jibunAddress);
    final missing = PostalAddress.fromJson({'roadAddress': '도로명주소 1'});
    expect(missing.jibunAddress, isEmpty);
    expect(missing.jibunEstimated, isFalse);
    expect(() => PostalAddress.fromJson({'autoRoadAddress': '예상 주소'}),
        throwsFormatException);
    expect(() => PostalAddress.fromJson({'roadAddress': 123}),
        throwsFormatException);
  });

  test('검색어를 HTML이나 실행 코드로 삽입하지 않는다', () {
    final html = postalSearchHtml('</script><script>잘못된 코드</script>');
    expect(html, isNot(contains('</script><script>잘못된 코드')));
    expect(html, contains(r'\u003c/script>'));
    expect(
        html,
        contains(
            'https://t1.kakaocdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js'));
  });

  testWidgets('주소 검색에서 받은 두 주소를 반환하고 잘못된 메시지는 거부한다', (tester) async {
    PostalAddress? selected;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        selected = await Navigator.of(context)
                            .push<PostalAddress>(MaterialPageRoute(
                          builder: (_) => PostalAddressPickerScreen(
                            query: '은계로 114',
                            searchBuilder: (_, onMessage) => Column(children: [
                              TextButton(
                                  onPressed: () => onMessage(jsonEncode({
                                        'type': 'postal-address-selection',
                                        'data': {'roadAddress': 123},
                                      })),
                                  child: const Text('잘못된 주소')),
                              TextButton(
                                  onPressed: () => onMessage(jsonEncode({
                                        'type': 'postal-address-selection',
                                        'data': {
                                          'roadAddress': '경기 시흥시 은계로 114',
                                          'jibunAddress': '경기 시흥시 은행동 669-1',
                                        },
                                      })),
                                  child: const Text('주소 선택')),
                            ]),
                          ),
                        ));
                      },
                      child: const Text('검색 열기')),
                ))));
    await tester.tap(find.text('검색 열기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('잘못된 주소'));
    await tester.pump();
    expect(selected, isNull);
    expect(find.textContaining('선택한 주소를 확인하지 못했어요'), findsOneWidget);
    await tester.tap(find.text('주소 선택'));
    await tester.pumpAndSettle();
    expect(selected?.roadAddress, '경기 시흥시 은계로 114');
    expect(selected?.jibunAddress, '경기 시흥시 은행동 669-1');
  });
}
