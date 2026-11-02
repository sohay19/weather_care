from pathlib import Path
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
for filename in ['build_design.py','build_pdf.py']:
    p=HERE/filename
    p.write_text(p.read_text(encoding='utf-8').replace('0.6','0.7'),encoding='utf-8')

doc=ROOT/'docs/워치앱_위젯_기획서_20261102.md'
s=doc.read_text(encoding='utf-8').replace('버전: 0.6','버전: 0.7')
start=s.index('## 6. 워치 위젯·타일 명세')
end=s.index('## 7. 컴플리케이션')
section='''## 6. 워치 위젯·타일 명세

### 공식 SDK 규격 기준 재설계

0.6까지의 소형/대형 시안은 전체 원형 화면에 요소를 흩어 놓아 실제 위젯 카드 경계를 벗어났다. 이를 폐기하고 Google Maven의 **wear-tooling-preview:1.0.0-alpha21** 소스의 WidgetPreviewParams.kt·WearWidgetPreview.kt와 wear-core의 WearWidgetParams.kt를 직접 확인했다. widthDp/heightDp는 콘텐츠 크기이며, 표시용 외곽 프리뷰 크기는 양쪽 호스트 패딩을 더한 값이다.

대표 시안은 작은 화면용 기본 Squircle 규격이다. 소형 콘텐츠166×60dp/외곽182×76dp, 대형 콘텐츠166×96dp/외곽182×112dp이며 각각 호스트 여백은가로/세로8dp다. **실제 연결 기기를 측정한 값은 아니며** 공식 표준 프리뷰의 값이다. SM-L340의 정확한 호스트 크기는 재연결 후 확인해야 한다. OEM이 다른 크기·모양을 전달하면 그 값을 사용한다.

| 표준 프로필 | 콘텐츠 W×H(dp) | 호스트 여백 가로/세로(dp) | 외곽 프리뷰 W×H(dp) |
| --- | --- | --- | --- |
'''
spec=json.loads((HERE/'widget-specs.json').read_text(encoding='utf-8'))
for p in spec['profiles']:
    section+=f'| {p["id"]} | {p["widthDp"]:g}×{p["heightDp"]:g} | {p["horizontalPaddingDp"]:g}/{p["verticalPaddingDp"]:g} | {p["outerWidthDp"]:g}×{p["outerHeightDp"]:g} |\n'
section+='''
10개 규격에 맞춰 콘텐츠 너비·높이 기준으로 정규화했다. 모든 텍스트·박스·준비물과 최저/최고의 실제 SVG 경계를 검사했다. 이는 **SDK 소스의 공식 수치에 따른 웹 시안 경계 검사**이며 Android Studio Native Preview 실행 또는 실기기 설치 검사가 아니다. sourceUrl과 소스 JAR SHA-256, 프로필 값은 widget-specs.json에 보존한다.

### 소형: 카드 안에 현재 날씨

위치/기준시각 → 날씨아이콘+기온 / 한 줄 체감 → 최저·최고 순이다. 준비물은 넣지 않는다. 기본 바탕은 검정이며 정보박스는 기존 전체 바탕색#253747이다. 아이콘은 왼쪽, 기온은 오른쪽으로 묶고 세로 중앙을 맞춘다. 체감 라벨은 작게 유지한다. 좁은 높이에서는 수치를 축소해 전체를 강제로 넣는 대신 콘텐츠 높이에 맞는 콤팩트 타이포그래피를 사용한다. 시안의 기온은 기본 소형22.4sp, 날씨22dp, 체감 라벨9.5sp/수치17sp다. 더 낮은 Round 소형54dp에서는 기온17.6sp/날씨20dp로 적응한다. 글자 확대·TalkBack의 Native 검증은 후속이다.

최저·최고는 **콘텐츠 안쪽 중앙 하단**이다. 대표166×60dp 콘텐츠에서 중앙x83, 기준선y57이며 호스트 바깥이나 원형 화면 맨 아래에는 그리지 않는다. 이 좌표는 문서의 대표 예시이고 실제 구현은 콘텐츠 너비/높이에서 계산한다. 카드 전체 탭은 현재 날씨로 이동한다.

### 대형: 같은 카드 안에 준비물 추가

위치/기준시각 → 날씨아이콘+기온 / 한 줄 체감 → 원형 배경의 준비물 아이콘3개 → 최저·최고 순이다. 검정 바탕과#253747 정보/준비물 배경은 소형과 같다. 준비물이3개 미만이면 있는 것만 표시한다. 대표166×96dp 콘텐츠에서 최저·최고 중앙x83/기준선y93이며 카드 안에 포함한다. 원형 화면 좌표y187은 사용하지 않는다.

### 크기와 모양의 표현

PDF4페이지와 웹의 소형·대형은 **위젯 카드 자체**를 같은 배율로 보여준다. 두 카드를 원형 전체 화면처럼 표현하지 않는다. 검정 카드 외곽은 호스트 포함 영역이며 안쪽 콘텐츠에만 정보를 배치한다. 둥근 정도는 대표 Squircle26dp와 Round/Rectangular 각 규격을 따른다. 실제 앱에서는 배경을 WearWidgetDocument의 background로 주고 root를 fillMaxSize로 채우며 WearWidgetParams에 적응한다. 검정 캔버스 안에 큰 가짜 카드 외곽을 별도로 강제하지 않는다.

### 이전 버전용 타일

타일은 전체 화면 방식이다. 제목 아래 지역·기준시각, 같은 행의 기온44sp/날씨44dp, 한 줄 브리핑, 하단 최저·최고를 유지한다. 주요 묶음은0.5보다8dp 위로 조정한0.6 배치를 유지한다. 전체 탭은 워치 앱의 현재 날씨를 연다. 카드형 소형·대형의 경계 규칙을 전체 화면 타일과 혼동하지 않는다.

### 플랫폼 계획

신규 앱은 단일 Wear 위젯 서비스와 공식 타일 호환부터 검증한다. 부족하면 TileService/WidgetService를 나눠 하나의 논리 항목으로 묶는다. SDK/렌더러·OEM 부분 높이 지원을 확인하고, 실제 표시 크기는 요청의 WearWidgetParams를 사용한다. 공식 소스 규격 확인과 실제 기기 지원 여부는 구분한다. 첫 지원 OS안과 alpha SDK 도입 위험은 기존 기획을 유지한다.

'''
s=s[:start]+section+s[end:]
s=s.replace('208dp 검토 기준: 기본 본문14sp', '워치 앱208dp 검토 기준: 기본 본문14sp')
s=s.replace('PDF에는 핵심 기획과 수정 시안을 넣었다.', 'PDF에는 핵심 기획과 수정 시안, 공식 SDK10규격 표와 검증 범위를 넣었다.')
s+='\n공식 프리뷰 수치 원본: [Google Maven sources.jar](https://dl.google.com/dl/android/maven2/androidx/glance/wear/wear-tooling-preview/1.0.0-alpha21/wear-tooling-preview-1.0.0-alpha21-sources.jar). SDK 소스의 기본값은 OEM이 덮어쓸 수 있으므로 전 기기의 고정 규격으로 확대하지 않는다.\n'
doc.write_text(s,encoding='utf-8')

readme=HERE/'README.md'
s=readme.read_text(encoding='utf-8')
s=s.replace('디자인 시안 0.6','디자인 시안 0.7').replace('등27개 점검','등28개 점검')
s='''> 최신0.7: 소형·대형은 전체 원형 배치를 폐기하고 공식 SDK 프리뷰 수치의 카드 안에 다시 배치했다. 이전 버전 기록의 원형화면 x104/y187은 현재 위젯 규격이 아니다. 대표 소형은 콘텐츠166×60dp/외곽182×76dp, 대형은166×96dp/182×112dp다. 실기기 호스트 측정·Native SDK 렌더링은 미실시다.

'''+s
s+='\nPDF는0.7/10페이지다. widget-specs.json에공식SDK수치·소스URL·SHA를보존했고 웹시안의공식10규격에서모든항목과최저최고가콘텐츠내부에포함됨을검사했다. load_widget_specs.py로고정버전소스를재조회할수있다.\n'
readme.write_text(s,encoding='utf-8')
print('공식 규격 기준0.7 기획·문서 갱신')
