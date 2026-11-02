from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

for name in ['build_design.py', 'build_pdf.py', 'README.md']:
    p = HERE / name
    p.write_text(p.read_text(encoding='utf-8').replace('0.2', '0.3'), encoding='utf-8')

pdf = HERE / 'build_pdf.py'
s = pdf.read_text(encoding='utf-8')
s = s.replace("'시스템 컨테이너 예시와 워치페이스 데이터 배치를 구분했습니다.'", "'앱 위젯과 같은 날씨 아이콘, 정보 묶음 배경과 준비물별 원형 배경입니다.'")
s = s.replace("'준비물 제외, 기온·체감·최저최고'", "'좌:기온+날씨 / 우:체감, 각각 배경'")
s = s.replace("'중앙2에 준비물 아이콘3개'", "'날씨/체감 배경, 준비물별 원형 배경'")
s = s.replace("'기온+날씨 아이콘, 짧은 브리핑'", "'같은크기·같은행 기온+날씨, 중앙 브리핑'")
s = s.replace("('이전 OS', 'Wear OS4/API33 이상을 1차 제안. 단일 위젯 서비스의 공식 타일 호환부터 검증')", "('기존 타일 역할', '앱을 열기 전 빠른 날씨 확인 + 탭 시 워치앱 현재 날씨 진입. 이전 OS 타일 호환 제공')")
pdf.write_text(s, encoding='utf-8')

doc = ROOT / 'docs/워치앱_위젯_기획서_20261102.md'
s = doc.read_text(encoding='utf-8').replace('버전: 0.2', '버전: 0.3')
s = s.replace('중앙에는 기온 / 체감온도 / 작은 날씨 아이콘을 한 행에 배치하고,', '중앙은 왼쪽에 기온+작은 날씨 아이콘을 하나의 묶음으로, 오른쪽에 체감온도를 놓고 각각 별도 배경박스로 구분한다. 두 묶음을 같은 행에 배치하고,')
s = s.replace('중앙1은 기온 / 체감온도 / 작은 날씨 아이콘, 중앙2는 준비물 아이콘3개,', '중앙1은 왼쪽 기온+작은 날씨 아이콘 묶음 / 오른쪽 체감온도와 각각의 배경박스, 중앙2는 품목별 원형 배경에 담긴 준비물 아이콘3개,')
s = s.replace('전체 원형 화면에서 기온+날씨 아이콘과 짧은 브리핑만 보여준다.', '전체 원형 화면에서 같은 크기의 기온과 날씨 아이콘을 동일 행에 나란히 놓고, 짧은 브리핑 한 줄을 화면 중앙에 배치한다. 시안의 기온44sp / 아이콘44dp와 같은 행을 기준으로 광학 정렬을 보정한다.')
s = s.replace('타일 전체 탭으로 앱을 연다.', '타일 전체 탭으로 워치 앱의 현재 날씨 화면을 직접 연다. 단순 앱 실행 버튼이 아니라 앱을 열지 않고도 날씨를 확인하는 빠른 정보 화면이며, 이전 Wear OS/타일 호스트에서 같은 내용을 제공하는 호환 역할도 한다. 휴대전화 앱을 자동으로 여는 동작은 아니다.')
s = s.replace('기존 어두운 준비물 이미지는', '날씨 아이콘은 임의 구름/빗금 도형을 제거하고 앱 위젯의 동일한 컬러 아이콘 계열로 통일한다. 시안은 docs/icon-previews/weather-color의 기존PNG를 그대로 내장하며, WidgetIconRenderer의 맑음·구름·비 도형/색상과 tools/generate_icon_previews.py의 생성 기준을 대조했다. Android와 웹 래스터라이저의 픽셀 경계 차이는 있을 수 있지만 새 아이콘을 별도로 디자인하지 않는다.\n\n기존 어두운 준비물 이미지는')
doc.write_text(s, encoding='utf-8')

readme = HERE / 'README.md'
s = readme.read_text(encoding='utf-8').replace('등17개 점검', '등20개 점검')
s += '\n0.3: 앱 위젯 날씨 아이콘PNG를 그대로 내장했다. 소형·대형은 좌측기온+날씨/우측체감의 개별배경, 대형의 각 준비물은 원형배경이다. 기존타일은 같은크기·같은행 기온/날씨와 중앙한줄브리핑으로 수정했으며, 탭은워치앱현재날씨로 연결된다.\n'
readme.write_text(s, encoding='utf-8')
print('0.3 기획·PDF 문구 갱신 완료')
