from pathlib import Path
from xml.sax.saxutils import escape
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / 'output/pdf/watch-app-plan-20261102.pdf'
OUT.parent.mkdir(parents=True, exist_ok=True)
FONT = ROOT / 'weather_care_app/assets/fonts'
pdfmetrics.registerFont(TTFont('Suite', str(FONT / 'SUITE-Regular.ttf')))
pdfmetrics.registerFont(TTFont('SuiteBold', str(FONT / 'SUITE-Bold.ttf')))
pdfmetrics.registerFontFamily('Suite', normal='Suite', bold='SuiteBold')
C = canvas.Canvas(str(OUT), pagesize=(595.28, 841.89))
C.setTitle('날씨챙겨 워치 앱·위젯 기획 및 디자인 시안')
C.setAuthor('날씨챙겨')
INK = '#29343D'; BLUE = '#3E5F7C'; MUTED = '#63707A'; LIGHT = '#EAF0F5'
page = 0

def para(text, x, y, width=507, size=10.7, color=INK, bold=False, leading=None):
    style = ParagraphStyle('p', fontName='SuiteBold' if bold else 'Suite', fontSize=size,
        leading=leading or size * 1.55, textColor=HexColor(color), wordWrap='CJK', spaceAfter=0)
    p = Paragraph(text, style)
    _, h = p.wrap(width, 800)
    if y - h < 52:
        raise ValueError(f'{page}페이지 본문 넘침: {text[:35]}')
    p.drawOn(C, x, y - h)
    return y - h

def txt(text, x, y, size=11, color=INK, bold=False):
    C.setFillColor(HexColor(color)); C.setFont('SuiteBold' if bold else 'Suite', size); C.drawString(x, y, text)

def start(kicker, title, subtitle=''):
    global page
    page += 1
    C.setFillColor(HexColor('#F6F7F8')); C.rect(0, 0, 595.28, 841.89, fill=1, stroke=0)
    txt('날씨챙겨  /  WATCH CONCEPT 0.8', 44, 805, 9, BLUE, True)
    txt(kicker, 44, 756, 10, BLUE, True)
    y = para(title, 44, 733, size=27, bold=True, leading=34)
    if subtitle: para(subtitle, 44, y - 12, size=10.7, color=MUTED)
    C.setStrokeColor(HexColor('#CEDAE4')); C.line(44, 42, 551, 42)
    txt('개발 전 시안 · 합성 자료 · 2026.11.02', 44, 27, 8, MUTED)
    txt(f'{page:02d} / 10', 514, 27, 8, MUTED)

def end(): C.showPage()

def heading(text, y):
    return para(text, 44, y, size=14, color=BLUE, bold=True) - 10

def bullets(items, y):
    for item in items:
        y = para('• ' + item, 48, y, width=499, size=10.7) - 9
    return y

def table(rows, y, widths=(112, 395)):
    for i, (left, right) in enumerate(rows):
        style = ParagraphStyle('cell', fontName='Suite', fontSize=10, leading=15, wordWrap='CJK')
        a, b = Paragraph(escape(left).replace('\n','<br/>'), style), Paragraph(escape(right).replace('\n','<br/>'), style)
        ah = a.wrap(widths[0]-20, 700)[1]; bh = b.wrap(widths[1]-20, 700)[1]
        h = max(ah, bh) + 20
        if y - h < 54: raise ValueError('표 넘침')
        C.setFillColor(HexColor('#FFFFFF' if i % 2 == 0 else '#EEF2F5'))
        C.roundRect(44, y-h, sum(widths), h, 7, fill=1, stroke=0)
        a.drawOn(C, 54, y-10-ah); b.drawOn(C, 54+widths[0], y-10-bh)
        y -= h + 5
    return y

def screen(name, x, y, size=186):
    C.drawImage(ImageReader(str(HERE / 'screens' / (name+'.png'))), x, y, size, size, mask='auto')

start('01  제품 방향', '손목에서, 챙길 것까지.', '날씨챙겨 워치 앱·위젯 기획 및 디자인 시안 0.8')
para('챙겨요 → 현재 날씨 → 타임라인 → 기상/생활 순서로 확인합니다.<br/>챙긴 물건을 체크하고, 어제 날씨와 비교하고, 지표를 눌러 상세를 봅니다.', 44, 635, size=12, leading=20)
screen('prepare', 77, 338, 190); screen('home', 329, 338, 190)
txt('먼저, 챙겨요', 128, 315, 13, BLUE, True); txt('그리고, 현재 날씨', 362, 315, 13, BLUE, True)
y = heading('연결된 작은 화면에 맞춰 설계', 270)
y = para('SM-L340 · 갤럭시 워치9 블루투스 40mm<br/>기기 조회: Android17 / API37, 원형438×438px, density340dpi<br/>위젯 렌더러1.6.1.87.907578152: 공식 최소 버전 조건 충족', 44, y, size=11)
para('위 수치는 ADB 읽기 조회 결과입니다. 화면은 합성 예시이며 실제 앱 설치 화면이 아닙니다. 3초는 향후 사용성 검사 목표입니다.', 44, y-23, size=9.5, color=MUTED)
end()

start('02  경험과 범위', '챙겨요에서, 지표 상세까지.', '화면 순서: 챙겨요 → 현재 날씨 → 타임라인 → 기상/생활')
y = table([
    ('챙겨요', '품목 맨 오른쪽 빈 체크박스 / 챙기면 체크된 박스. 품목 영역 탭은 선정 이유'),
    ('현재 날씨', '기온·체감·최저최고. 기존 행동 브리핑 영역을 줄여 어제와 날씨 비교로 교체'),
    ('타임라인', '다음 시간에서 명칭만 변경. 시각·날씨 상태·기온·강수확률 형식 유지'),
    ('기상/생활', 'Today처럼 여러 항목을2열 배열로 세로 나열. 항목 탭 시 상세 데이터 확인'),
    ('빠른 화면', '소형: 날씨 / 대형: 날씨+준비물3개 / 타일: 기온+아이콘·브리핑 / 페이스: 좌 기온·우 날씨'),
], 620)
y = heading('처음 연결하고, 확인하고, 복구하기', y-20)
y = bullets([
    '첫 실행 → 폰 앱 연결 확인 → 지역·설정·자료 수신 → 챙겨요. 연결 실패 원인을 구분합니다.',
    '챙김 체크와 품목 설명 탭은 분리합니다. 체크가 추천/알림ON·OFF를 바꾸지 않습니다. 목록 하단은 총 n개 · 아래로입니다.',
    '세로 스크롤·회전 입력을 사용하고, 가장자리 뒤로 이동을 유지합니다.',
    '오프라인은 유효 캐시를 먼저 사용합니다. 만료 정보는 최신 권고처럼 표시하지 않습니다.',
], y)
para('첫 버전 제외: 자체 워치페이스, 전체 Week/레이더, 복잡한 설정 편집, 상시GPS, 독립 워치 FCM. 독립 실행은 기기 인증·동의를 갖춘 후속 단계로 제안합니다.', 44, y-5, size=10, color=MUTED)
end()

start('03  앱 디자인', '챙기고, 비교하고, 확인해요.', '요청 순서대로 배치한 앱4화면입니다. 아래 구간은 세로 스크롤합니다.')
for name, x, y, title, desc in [
    ('prepare', 68, 382, '챙겨요', '맨 우측 빈 체크박스 → 챙김 표시'),
    ('home', 326, 382, '현재 날씨', '아이콘·기온 중앙, 어제 기온/체감 비교'),
    ('hourly', 68, 101, '타임라인', '시각·상태·기온·강수확률 유지'),
    ('alerts', 326, 101, '기상/생활', '여러 지표를2열로, 누르면 상세'),
]:
    screen(name, x, y, 186)
    txt(title, x+48, y-21, 12, BLUE, True)
    para(desc, x+5, y-32, width=200, size=9.3, color=MUTED)
end()

start('04  위젯 디자인', '실제 콘텐츠 영역 안으로.', '공식 SDK의 작은 화면용 프리뷰 수치로 재배치했습니다. 두 카드는 같은 배율입니다.')
txt('소형 SMALL',64,598,13,BLUE,True)
txt('대형 LARGE',326,598,13,BLUE,True)
C.drawImage(ImageReader(str(HERE/'screens/small.png')),58,475,220,220*76/182,mask='auto')
C.drawImage(ImageReader(str(HERE/'screens/large.png')),318,475+220*76/182-220*112/182,220,220*112/182,mask='auto')
para('콘텐츠166×60dp<br/>외곽182×76dp / 호스트 여백8dp',58,407,width=220,size=10,color=MUTED)
para('콘텐츠166×96dp<br/>외곽182×112dp / 호스트 여백8dp',318,407,width=220,size=10,color=MUTED)
para('기온 + 2/3 크기 날씨 아이콘 · 체감온도를 한 배경박스에 넣었습니다.<br/>최저·최고는 각 위젯 안쪽 중앙 하단입니다.',44,354,size=10,color=BLUE)
for name, x, y, title, desc in [
    ('tile',68,101,'기존 타일','좌: 날씨 아이콘 / 우: 기온'),
    ('complication',326,101,'워치페이스 정보','좌: 기온 / 우: 날씨 아이콘'),
]:
    screen(name,x,y,186); txt(title,x+39,y-21,12,BLUE,True)
    para(desc,x+1,y-32,width=209,size=9.1,color=MUTED)
end()

start('05  위젯 규격과 검증', '공식 프리뷰10규격을 기준으로.', 'wear-tooling-preview 1.0.0-alpha21의 소스에서 크기·호스트 여백을 직접 확인했습니다.')
y=table([
    ('기본 작은 화면', '소형 콘텐츠166×60 → 외곽182×76dp\n대형 콘텐츠166×96 → 외곽182×112dp'),
    ('기본 큰 화면', '소형200×60 → 216×76dp\n대형200×108 → 216×124dp'),
    ('Round 작은 화면', '소형182×54 → 208×70dp\n대형150×120 → 208×152dp'),
    ('Round 큰 화면', '소형200×60 → 230×76dp\n대형160×136 → 230×168dp'),
    ('선택기 자산용', '소형192×60 → 224×84dp\n대형168×112 → 232×144dp'),
],620)
y=heading('카드 안에서의 배치와 한계',y-18)
y=bullets([
    'SDK의 widthDp/heightDp는 콘텐츠 크기입니다. 외곽은 양쪽 호스트 패딩을 더한 크기입니다.',
    '위치/기준시각 → 한 박스의 기온+날씨 아이콘 · 체감 → 대형만 준비물 → 최저/최고 순서입니다.',
    '최저/최고는 각 콘텐츠의 아래쪽 중앙입니다. 워치 원형 화면의 하단 좌표를 사용하지 않습니다.',
    '10개 표준 규격에서 모든 요소의 경계와 최저/최고의 카드 내부 포함을 웹 렌더링으로 확인했습니다.',
],y)
para('현재 워치 연결이 없어 SM-L340의 실제 호스트 크기는 미측정입니다. 이번 PDF는 공식 SDK 프리뷰 수치에 맞춘 설계이며, Native SDK 렌더링이나 실기기 설치 검증을 완료했다는 의미는 아닙니다. 실제 구현은 전달받은 WearWidgetParams에 적응해야 합니다.',44,y-3,size=9.8,color=MUTED)
end()

start('06  체크와 지표 상세', '작은 조작도, 분명하게.', '체크 전·후와2열 목록의 아래 구간, 항목 상세 화면을 함께 확인합니다.')
for name,x,y,title,desc in [
    ('prepare-checked',68,382,'챙긴 상태','우산 체크 / 겉옷 빈 체크박스'),
    ('alerts-more',326,382,'기상/생활 · 계속','대기질·대기정체·가시거리·꽃가루'),
    ('alerts-last',68,101,'기상/생활 · 끝','강수량·적설량까지2열로 이어짐'),
    ('metric-1',326,101,'습도 상세','수치·기준 시각·자료 의미 확인'),
]:
    screen(name,x,y,186);txt(title,x+32,y-21,12,BLUE,True)
    para(desc,x+1,y-32,width=213,size=9.1,color=MUTED)
end()

start('07  데이터와 갱신', '같은 자료를, 손목에도.', '휴대전화 연동형부터 시작하고 기존 날씨·준비물 판단을 재사용합니다.')
y = table([
    ('휴대전화', '기존 API/날씨 캐시·지역 모드·설정 → WearSyncAdapter에서 최소 스냅샷 변환'),
    ('동기화', '같은 패키지·서명의 Data Layer로 전달. 독립 저장소에 최신 revision만 반영'),
    ('워치 표시', '앱·위젯·타일·컴플리케이션이 같은 로컬 스냅샷을 읽고 함께 갱신'),
],620)
y = heading('재사용과 새 계약',y-18)
y = para('기존 지역·온도·준비물·브리핑·유효기간을 재사용합니다. 타임라인의 데이터 형식은 유지하고, YesterdayComparison과 Today 지표의 값·단위·기준시각·설명을 추가 정규화합니다. 기존 위젯 계약은 유지합니다.',44,y,size=10.7)-18
y = para('어제 비교는 같은 지역·같은 시각의 기온과 체감온도 차이입니다. 비교 자료가 없으면 없다고 표시합니다. 체크는 지역+오늘 날짜+품목별 워치 로컬 상태로 제안하며, 새 날씨 갱신 때 유지하고 다음 날 초기화합니다. 알림·추천 설정은 바꾸지 않습니다.',44,y,size=10)-18
y = heading('갱신 원칙',y)
y = bullets([
    '앱 진입 시 캐시 즉시 표시. 오래됐으면 폰에 새 자료를 요청합니다.',
    '폰의 백그라운드 위치·날씨·설정 변경을 동기화하고, 늦게 도착한 다른 지역 응답을 버립니다.',
    '브리핑 경계는 받은 timeline에서 처리합니다. 유효기간과 수신시각은 따로 관리합니다.',
    '30분 목표 보조 갱신과 수동 요청 중복60초 제한을 제안합니다. 실행 시각은 OS가 지연할 수 있습니다.',
    '상시GPS는 도입하지 않고 폰의 현재 지역을 따릅니다. 위치 이동이 저장 구역을 자동 추가하지 않습니다.',
],y)
para('직접 서버 통신은 후속입니다. 별도 워치 기기 인증·조회 권한·토큰 폐기·위치 동의를 먼저 설계하고, 폰의 설치 비밀키를 단순 복사하지 않습니다.',44,y-2,size=9.7,color=MUTED)
end()

start('08  플랫폼과 설정', '새 위젯과 기존 타일을 함께.', '최신 기능의 렌더러·호스트 조건을 실제 기기에서 먼저 검증합니다.')
y = table([
    ('우선 구현', '별도 Kotlin/Compose for Wear OS 모듈. 기존 Flutter 폰 앱은 유지'),
    ('새 Wear 위젯', 'API37, 렌더러1.6.1 이상. Glance/Remote Compose 계열, 현재 alpha SDK 위험 검토'),
    ('기존 타일 역할', '앱을 열기 전 빠른 날씨 확인 + 탭 시 워치앱 현재 날씨 진입. 이전 OS 타일 호환 제공'),
    ('OEM 차이', '부분 높이 지원 여부에 따라 위젯/타일 표현이 다름. 필요 시 이중 서비스로 분리'),
    ('외곽 처리', '호스트 배경·크기·safe inset에 적응. 고정438px나 중첩 카드 외곽을 강제하지 않음'),
],620)
y = heading('알림과 조회를 분리',y-18)
y = bullets([
    '알림 사용여부·챙겨요·Today·기상생활 전체/개별 선택과 기존 발송 시각을 그대로 따릅니다.',
    '그룹 알림OFF는 발송 제어입니다. 앱·위젯의 날씨 조회를 모두 숨기지 않습니다.',
    '기존 폰 알림 브리지 우선. 별도 워치FCM을 추가해 같은 사건을 두 번 진동시키지 않습니다.',
    '연동형은 워치 위치 권한 없이 시작합니다. 연결 안내와 자료 확인을 먼저 제공합니다.',
],y)
para('동일 앱 Data Layer 연동은 같은 패키지명과 서명이 필수입니다. 별도 QA 빌드도 폰·워치 서명 조합을 맞춰 검사해야 합니다.',44,y-4,size=10,color=MUTED)
end()

start('09  상태와 검증', '갱신보다 중요한 건, 신뢰.', '자료 없음·연결 끊김·자료 만료를 서로 다르게 다룹니다.')
y = table([
    ('유효한 캐시', '연결이 없어도 마지막 지역·자료 시각을 함께 표시'),
    ('자료 만료', '오래된 자료 표시, 만료된 준비물/위험을 현재 권고처럼 노출하지 않음'),
    ('자료 없음', '온도는 -- 또는 자료 없음. 0도·강수0%와 구별'),
    ('특보 만료', 'validUntil/해제 사건 기준 처리. 통신 실패를 해제로 해석하지 않음'),
],620)
y = heading('구현 완료 후 반드시 확인할 것',y-20)
y = bullets([
    '192/206/227dp, 기본·큰 글자, TalkBack, 회전 입력과 가장자리 뒤로 이동.',
    '지역·기온·기준 시각의 일치. 소형 준비물 없음, 대형3아이콘, 페이스 좌기온/우날씨.',
    '체크와 상세 탭 분리, 어제 비교의 지역·시각 일치,2열 전체 지표와 상세 진입.',
    '폰 앱 미진입 상태에서 연속3회 이상 위치 변경, 이전 응답 덮어쓰기 없음.',
    '오프라인·절전·재부팅·자정·타임존·유효기간 경계에서 올바른 상태 표시.',
    '모든 알림OFF 조합과 사건 중복 방지. 24시간 대조 사용으로 추가 배터리 소모 측정.',
],y)
para('UI 기준: 기존 SUITE/파란색 계열, 검은 배경, 주요 수치44~48sp 제안. 터치48dp 이상과 시스템 글자 크기를 반영하고, 큰 글자에서는 스크롤·정보량 조절로 잘림을 피합니다.',44,y-3,size=10,color=MUTED)
end()

start('10  개발 순서와 근거', '플랫폼 검증부터, 작은 범위로.', '이번 산출물은 기획·디자인이며 앱 구현이나 설치 완료를 의미하지 않습니다.')
y = bullets([
    '1단계: 연결 워치의 최소 앱·새 위젯·타일·컴플리케이션 선택기 검증.',
    '2단계: 스냅샷·캐시·Data Layer·지역/응답 순서 보호 구현.',
    '3단계: 핵심 앱 화면·두 위젯·오류 상태·접근성 구현.',
    '4단계: 백그라운드 이동·절전·알림·재연결 검사 후 배포 범위 확정.',
],620)
y = heading('공식 자료 · 2026-11-02 조회',y-6)
sources = [
    ('삼성 SM-L340 제품 지원','https://www.samsung.com/sec/support/model/SM-L340NZEAKOO/'),
    ('Wear Widgets / 크기와 역할','https://developer.android.com/training/wearables/widgets'),
    ('위젯 시작 / API·렌더러·프리뷰','https://developer.android.com/training/wearables/widgets/get_started'),
    ('위젯·타일 서비스 호환','https://developer.android.com/training/wearables/widgets/migration'),
    ('프리뷰 수치 원본 / 고정 SDK 소스','https://dl.google.com/dl/android/maven2/androidx/glance/wear/wear-tooling-preview/1.0.0-alpha21/wear-tooling-preview-1.0.0-alpha21-sources.jar'),
    ('컴플리케이션 역할','https://developer.android.com/training/wearables/complications'),
    ('Data Layer / 패키지·서명','https://developer.android.com/training/wearables/data/overview'),
    ('동기화와 영구 저장소','https://developer.android.com/training/wearables/data/sync'),
    ('접근성과 Wear 앱 품질','https://developer.android.com/training/wearables/accessibility'),
]
for label,url in sources:
    y = para(f'<b>{label}</b><br/><link href="{url}" color="#3E5F7C">{url}</link>',44,y,size=8.3,leading=12.5)-9
y -= 5
para('상세 명세: docs/워치앱_위젯_기획서_20261102.md<br/>클릭 시안: docs/design/watch-20261102/index.html<br/>전체 보드: 같은 폴더 overview.png·widgets.png<br/>한글 폰트 내장 / 합성 예시 / 현재 앱·서버 소스 변경 없음',44,y,size=9.2,color=MUTED)
end()
assert page == 10
C.save()
print(json.dumps({'완료':str(OUT),'페이지':page},ensure_ascii=False))
