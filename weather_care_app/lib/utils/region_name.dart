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
