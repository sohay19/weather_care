import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    const fonts = {
      '나눔스퀘어 네오 (NanumSquareNeo)': 'nanum_square_neo',
      'SUITE': 'suite',
      '모나10 (Mona10)': 'mona',
      '조선가는고딕 · 조선굵은고딕 · 조선견고딕': 'chosun_gothic',
    };
    for (final MapEntry(:key, :value) in fonts.entries) {
      final notice = await rootBundle.loadString('assets/licenses/$value.txt');
      yield LicenseEntryWithLineBreaks([key], notice);
    }
  });
}
