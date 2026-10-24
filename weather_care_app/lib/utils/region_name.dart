const regionNameLoading = '지역명 조회 중...';
const regionNameFailed = '지역명 조회 실패';

bool isRegionNamePlaceholder(String? value) =>
    value == null ||
    const {
      '',
      '현재 위치',
      '선택 지역',
      '선택한 지역',
      '지역을 설정해주세요',
      regionNameLoading,
      regionNameFailed,
    }.contains(value.trim());

String displayRegionName(String value) => _withoutOrdinal(
      value,
      RegExp(r'제(?=\d+(?:[.·ㆍ]\d+)*동(?![가-힣0-9]))'),
    );

String regionSearchName(String value) =>
    _withoutOrdinal(value, RegExp(r'제(?=\d)'));

String _withoutOrdinal(String value, RegExp pattern) => value.replaceAllMapped(
      pattern,
      (match) {
        final prefix = value.substring(0, match.start);
        return prefix.endsWith('거') || prefix.endsWith('홍') ? match[0]! : '';
      },
    );
