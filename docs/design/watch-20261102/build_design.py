"""날씨챙겨 워치 기획 시안. 실제 기기/서버에 쓰지 않는 독립 자료 생성기."""
from pathlib import Path
import base64
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ASSETS = ROOT / 'weather_care_app/assets'

def data(path, mime):
    return 'data:' + mime + ';base64,' + base64.b64encode(path.read_bytes()).decode()

font = data(ASSETS / 'fonts/SUITE-Regular.ttf', 'font/ttf')
bold = data(ASSETS / 'fonts/SUITE-Bold.ttf', 'font/ttf')
icons = {name: data(ASSETS / ('icons/prep_' + name + '.png'), 'image/png')
         for name in ['umbrella', 'outerwear', 'water', 'sunscreen']}
lip_icon = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="16" y="5" width="16" height="21" rx="4" fill="#B7D0E5"/><rect x="13" y="21" width="22" height="23" rx="4" fill="#5D7F9E"/><path d="M18 29h12M18 34h12" stroke="#EDF2F6" stroke-width="2"/></svg>'
icons['lip'] = 'data:image/svg+xml;base64,' + base64.b64encode(lip_icon.encode()).decode()
weather_icons = {name: data(ROOT / f'docs/icon-previews/weather-color/{name}.png', 'image/png')
                 for name in ['clear', 'rain', 'partly_cloudy']}
widget_specs = json.loads((HERE / 'widget-specs.json').read_text(encoding='utf-8'))

def t(x, y, text, size=13, color='#EDF2F6', weight=400, anchor='middle'):
    return f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-size="{size}" fill="{color}" font-weight="{weight}">{text}</text>'

def box(x, y, w, h, color='#1D2731', r=17):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{color}"/>'

def img(name, x, y, w=28):
    return f'<image href="{icons[name]}" x="{x}" y="{y}" width="{w}" height="{w}" style="filter:brightness(0) saturate(100%) invert(86%) sepia(12%) saturate(640%) hue-rotate(165deg)"/>'

def cloud(x, y, scale=1, rain=True):
    return weather('rain' if rain else 'partly_cloudy', x, y, 44*scale)

def sun(x, y, scale=1):
    return weather('clear', x, y, 44*scale)

def weather(condition, x, y, size=28):
    return f'<image data-weather="{condition}" href="{weather_icons[condition]}" x="{x}" y="{y}" width="{size}" height="{size}"/>'

def weather_pair(y):
    left = '<g data-panel="temperature-weather">' + box(31, y, 90, 45, '#253747', 13)
    left += weather('rain', 42, y+12, 22)
    left += f'<text data-temperature="current" x="91" y="{y+22.5}" text-anchor="middle" dominant-baseline="central" font-size="27" fill="#EDF2F6" font-weight="700">11°</text></g>'
    right = '<g data-panel="apparent">' + box(127, y, 50, 45, '#253747', 13)
    right += f'<text data-apparent-line="true" x="152" y="{y+22.5}" text-anchor="middle" dominant-baseline="central" fill="#EDF2F6"><tspan font-size="9.5" fill="#B7D0E5">체감 </tspan><tspan font-size="19" font-weight="700">9°</tspan></text></g>'
    return left + right

def action(content, target, label):
    return f'<g role="button" tabindex="0" data-screen="{target}" aria-label="{label}">{content}</g>'

def checkmark(key, y, checked=False):
    shape = f'<rect x="156" y="{y + 16}" width="16" height="16" rx="3" fill="{"#9DBDD8" if checked else "none"}" stroke="#9DBDD8" stroke-width="1.6"/>'
    if checked:
        shape += f'<path d="M159 {y+24}l4 4 7-8" fill="none" stroke="#172736" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
    hit = f'<rect x="140" y="{y}" width="48" height="48" fill="transparent"/>'
    return f'<g role="checkbox" tabindex="0" aria-label="{key} 챙김" aria-checked="{str(checked).lower()}" data-check="{key}">{hit}{shape}</g>'

metrics = [
    ('체감온도', '9°', '바람과 습도를 반영한 체감', '기온·습도·바람을 반영한 값이에요.'),
    ('습도', '72%', '현재 상대습도', '공기가 머금을 수 있는 수증기에 대한 비율이에요.'),
    ('자외선', '3 보통', '낮 시간 자외선 지수', '한낮 야외 활동 시 자외선에 대비해요.'),
    ('바람', '2.4m/s', '현재 풍속 · 북서풍', '바람이 불면 실제보다 쌀쌀하게 느낄 수 있어요.'),
    ('대기질', '좋음', '미세먼지 18㎍/㎥', '미세먼지와 초미세먼지 자료를 함께 확인해요.'),
    ('대기정체', '보통', '오늘의 예측 단계', '대기 순환 예측 단계로, 미세먼지 농도와 달라요.'),
    ('가시거리', '12km', '현재 수평 가시거리', '관측한 가시거리이며 미래 예보로 대신하지 않아요.'),
    ('꽃가루', '낮음', '제공 기간의 예측 단계', '제공 기간 밖이면 기간 외 안내로 구분해요.'),
    ('강수량', '0mm', '최근 1시간 관측', '관측 강수량이며 앞으로의 강수확률과 달라요.'),
    ('적설량', '0cm', '현재 관측 적설', '자료가 없으면 0으로 대신하지 않아요.'),
]

def frame(content, label, clock=True):
    return '<svg class="screen-svg" viewBox="0 0 208 208" role="img" aria-label="' + label + '"><defs><clipPath id="round"><circle cx="104" cy="104" r="104"/></clipPath></defs><g clip-path="url(#round)"><circle cx="104" cy="104" r="104" fill="#000"/>' + (t(104, 19, '09:41', 10, '#AAB7C3') if clock else '') + content + '</g></svg>'

def screen(name, scenario='rain'):
    dry = scenario == 'dry'
    stale = scenario == 'stale'
    temp = '15°' if dry else '11°'
    prep = '립밤' if dry else '우산'
    if name == 'home':
        body = t(104, 40, '서울 중구', 13, '#9DBDD8')
        body += '<g data-home-weather-row="center">' + weather('clear' if dry else 'rain', 45, 63.3, 37.4)
        body += f'<text data-home-temperature="true" x="124" y="82" text-anchor="middle" dominant-baseline="central" font-size="47" fill="#EDF2F6" font-weight="700">{temp}</text></g>'
        body += t(104, 117, '체감 14° · 최저 9° / 최고 18°' if dry else '체감 9° · 최저 8° / 최고 14°', 10.7, '#AAB7C3')
        comparison = '어제보다 1° 높아요' if dry else '어제보다 2° 낮아요'
        body += box(33, 130, 142, 35, '#253747', 12) + t(104, 145, '비교 자료 없음' if stale else comparison, 10.7, '#B7D0E5')
        body += t(104, 159, '체감 비교 자료 없음' if stale else ('체감 상 어제보다 1° 높아요' if dry else '체감 상 어제보다 3° 낮아요'), 9, '#AAB7C3')
        body += t(104, 187, '07:00 자료 · 오래됨' if stale else '09:35 기준', 10, '#E6B879' if stale else '#AAB7C3')
        return frame(body, '현재 날씨')
    if name in ['prepare', 'prepare-checked', 'prepare-more']:
        body = t(104, 41, '챙겨요', 17, weight=700)
        if name == 'prepare-more':
            body += box(24, 61, 160, 48) + img('sunscreen', 32, 71, 27) + t(65, 83, '선크림', 13, anchor='start') + t(65, 100, '낮 자외선 대비', 9.5, '#AAB7C3', anchor='start') + checkmark('선크림', 61)
            body += action(box(38, 119, 132, 48, '#253747') + t(104, 149, '처음 항목으로', 13), 'prepare', '준비물 처음으로')
        else:
            body += action(box(24, 58, 160, 48) + img('lip' if dry else 'umbrella', 32, 68, 27) + t(65, 80, prep, 14, weight=700, anchor='start') + t(65, 97, '오후 비 대비' if not dry else '건조한 공기', 9.5, '#AAB7C3', anchor='start'), 'detail', prep + ' 상세')
            body += checkmark(prep, 58, name == 'prepare-checked')
            body += action(box(24, 112, 160, 48) + img('outerwear', 32, 122, 27) + t(65, 134, '겉옷', 14, weight=700, anchor='start') + t(65, 151, '쌀쌀한 시간', 9.5, '#AAB7C3', anchor='start'), 'outerwear', '겉옷 상세')
            body += checkmark('겉옷', 112)
        body += t(104, 185, '총 3개 · 아래로', 10, '#AAB7C3')
        return frame(body, '준비물 목록')
    if name in ['detail', 'outerwear']:
        outer = name == 'outerwear'
        body = img('outerwear' if outer else ('lip' if dry else 'umbrella'), 85, 34, 38)
        body += t(104, 92, '겉옷' if outer else prep, 21, weight=700)
        body += t(104, 116, '아침저녁 기온이 낮아요' if outer else ('입술이 건조해지기 쉬워요' if dry else '오후에 비가 내릴 수 있어요'), 11.5)
        body += t(104, 134, '서울 중구 · 오늘 15~18시', 10.7, '#AAB7C3')
        body += action(box(40, 146, 128, 48, '#253747') + t(104, 175, '목록으로', 13), 'prepare', '준비물 목록으로')
        return frame(body, '준비물 상세')
    if name == 'hourly':
        body = t(104, 41, '타임라인', 17, weight=700)
        hours = [('10시', '15°', '0%'), ('11시', '16°', '0%'), ('12시', '17°', '0%')] if dry else [('10시', '11°', '20%'), ('11시', '12°', '30%'), ('12시', '13°', '60%')]
        for i, (hour, val, chance) in enumerate(hours):
            y = 62 + i * 37
            body += box(29, y - 9, 150, 32, '#1D2731', 12) + t(48, y + 11, hour, 12)
            body += (sun(67, y - 3, .45) if dry else cloud(67, y - 3, .45, i == 2)) + t(116, y + 12, val, 16, weight=700) + t(151, y + 11, chance, 10, '#9DBDD8')
        body += t(104, 184, '오늘 · 강수확률', 10, '#AAB7C3')
        return frame(body, '다음 세 시간 예보')
    if name in ['alerts', 'alerts-more', 'alerts-last']:
        body = t(104, 41, '기상/생활', 16, weight=700)
        offset = {'alerts': 0, 'alerts-more': 4, 'alerts-last': 8}[name]
        for index, (label, value, _, _) in enumerate(metrics[offset:offset+4]):
            x = 25 + index % 2 * 82
            y = 55 + index // 2 * 56
            cell = box(x, y, 76, 50, '#1D2731', 14) + t(x+38, y+18, label, 10.7, '#AAB7C3') + t(x+38, y+39, value, 15, '#EDF2F6', 700)
            body += action(cell, 'metric-' + str(offset+index), label + ' 상세 데이터')
        body += t(104, 183, f'총 {len(metrics)}개 · 아래로', 9.5, '#AAB7C3')
        return frame(body, '기상생활 상세 지표 2열 목록')
    if name.startswith('metric-'):
        label, value, basis, desc = metrics[int(name.split('-')[1])]
        body = t(104, 42, label, 16, weight=700) + t(104, 83, value, 30, '#9DBDD8', 700)
        body += t(104, 106, basis, 10.7) + t(104, 128, '서울 중구 · 09:35 기준', 10, '#AAB7C3')
        for i, line in enumerate([desc[j:j+17] for j in range(0, len(desc), 17)]):
            body += t(104, 148+i*16, line, 10, '#AAB7C3')
        body += t(104, 189, '예시 자료 · 뒤로 이동', 9.5, '#AAB7C3')
        return frame(body, label + ' 상세 데이터, ' + desc)
    if name == 'setup':
        body = box(79, 37, 50, 50, '#253747', 19) + t(104, 72, '↔', 27, '#9DBDD8')
        body += t(104, 110, '휴대전화와 연결', 16, weight=700) + t(104, 131, '날씨와 지역을 가져와요', 11, '#AAB7C3')
        body += action(box(39, 146, 130, 48, '#9DBDD8') + t(104, 176, '연결 확인', 14, '#172736', 700), 'prepare', '연결 완료 시안 보기')
        return frame(body, '최초 연결')
    if name == 'settings':
        body = t(104, 41, '연결·자료', 16, weight=700) + t(104, 72, '지역  ·  폰 따라가기', 12) + t(104, 96, '마지막 자료 09:35', 12, '#AAB7C3')
        body += action(box(32, 117, 144, 48, '#253747') + t(104, 146, '다시 확인', 14), 'home', '갱신 완료 시안 보기') + t(104, 185, '알림 설정은 휴대전화에서', 10, '#AAB7C3')
        return frame(body, '연결과 자료 확인')
    body = t(104, 42, '연결 확인', 16, weight=700) + t(104, 90, '마지막 자료 07:00', 13, '#E6B879') + t(104, 112, '최신 날씨를 가져오지', 12) + t(104, 130, '못했어요', 12)
    body += action(box(39, 144, 130, 48, '#253747') + t(104, 174, '다시 확인', 14), 'home', '연결 복구 시안 보기')
    return frame(body, '오래된 자료와 연결 끊김')

def wearable(content):
    return '<div class="watch"><div class="bezel">' + content + '</div></div>'

def widget_card(profile):
    """공식 WearWidgetParams의 콘텐츠와 호스트 패딩을 별도 좌표계로 그린다."""
    w, h = profile['widthDp'], profile['heightDp']
    ow, oh = profile['outerWidthDp'], profile['outerHeightDp']
    px, py = profile['horizontalPaddingDp'], profile['verticalPaddingDp']
    kind = profile['kind']
    row_left = (w-120)/2
    y, row_h = 16, (h-32 if kind=='small' else 32)
    cy = y+row_h/2
    number_size = min(24, row_h*.80)
    icon_size = min(22, row_h-2)*2/3
    body = t(1, 11, '서울 중구', 9.5, '#B7D0E5', anchor='start') + t(w-1, 11, '09:35 기준', 9, '#AAB7C3', anchor='end')
    body += '<g data-panel="weather-summary">' + box(0,y,w,row_h,'#253747',10)
    body += f'<text data-temperature="current" x="{row_left+20}" y="{cy}" text-anchor="middle" dominant-baseline="central" font-size="{number_size}" fill="#EDF2F6" font-weight="700">11°</text>'
    body += weather('rain', row_left+49-icon_size/2, cy-icon_size/2, icon_size)
    body += f'<text data-weather-separator="true" x="{row_left+69}" y="{cy}" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#B7D0E5">·</text>'
    body += f'<text data-apparent-line="true" x="{row_left+100}" y="{cy}" text-anchor="middle" dominant-baseline="central" fill="#EDF2F6"><tspan font-size="9.5" fill="#B7D0E5">체감 </tspan><tspan font-size="{min(17,row_h*.72)}" font-weight="700">9°</tspan></text></g>'
    if kind=='large':
        prep_y = h-32
        for cx, item in [(w/2-39,'umbrella'),(w/2,'outerwear'),(w/2+39,'sunscreen')]:
            body += f'<g data-preparation="{item}"><circle cx="{cx}" cy="{prep_y}" r="13" fill="#253747"/>' + img(item,cx-10,prep_y-10,20) + '</g>'
    body += '<g data-minmax="inside">' + t(w/2,h-3,'최저 8°  ·  최고 14°',11,'#B7D0E5') + '</g>'
    pid = profile['id']
    radius = min(profile['cornerRadiusDp'],ow/2,oh/2)
    return f'<svg class="screen-svg widget-card-svg" viewBox="0 0 {ow} {oh}" role="img" aria-label="공식 {kind} 프리뷰 규격" data-profile="{pid}" data-kind="{kind}" data-device-measured="false"><defs><clipPath id="{pid}-mask"><rect width="{ow}" height="{oh}" rx="{radius}"/></clipPath></defs><g clip-path="url(#{pid}-mask)"><rect data-widget-background="black" width="{ow}" height="{oh}" rx="{radius}" fill="#000000"/><g data-widget-content="true" data-width="{w}" data-height="{h}" transform="translate({px} {py})">{body}</g></g></svg>'

def widget(kind):
    if kind in ['small','large']:
        return widget_card(next(p for p in widget_specs['profiles'] if p['id']==f'squircle-{kind}-1'))
    if kind == 'tile':
        body = t(104, 36, '날씨챙겨', 13, '#9DBDD8')
        body += t(104, 54, '서울 중구 · 09:35 기준', 10, '#AAB7C3')
        body += '<g data-tile-main="center" transform="translate(0 13)"><g data-tile-weather-row="44">' + weather('rain', 44, 62, 44) + t(139, 100, '11°', 44, weight=700) + '</g>'
        body += box(28, 108, 152, 35, '#253747') + t(104, 130, '오후 비, 우산 챙겨요', 12) + '</g>'
        body += t(104, 187, '최저 8°  ·  최고 14°', 11, '#B7D0E5')
        body = action('<circle cx="104" cy="104" r="104" fill="transparent"/>' + body, 'home', '타일을 눌러 현재 날씨 앱 화면 열기')
        return frame(body, '이전 버전 타일')
    body = t(104, 49, '11월 2일 월요일', 11, '#AAB7C3') + t(104, 104, '09:41', 42, weight=700)
    body += box(32, 120, 64, 48, '#1D2731', 21) + t(64, 151, '11°', 23, weight=700)
    body += box(111, 120, 64, 48, '#253747', 21) + cloud(128, 128, .7)
    body += t(104, 189, '페이스 정보 칸 · 배치 예시', 9.5, '#AAB7C3')
    return frame(body, '컴플리케이션 배치 예시, 실제 외형은 워치페이스가 결정', False)

labels = {'prepare': ('챙겨요', '오른쪽 체크박스로 챙긴 물건을 표시해요.'), 'home': ('현재 날씨', '작은 비교 영역에서 어제와의 차이를 확인해요.'), 'hourly': ('타임라인', '시각·상태·기온·강수확률 형식은 유지해요.'), 'alerts': ('기상/생활', 'Today처럼 2열로 살펴보고 항목을 눌러요.'), 'offline': ('자료 만료', '오래된 정보를 최신처럼 보여주지 않아요.'), 'setup': ('첫 연결', '작은 화면에서 복잡한 설정은 줄여요.'), 'detail': ('준비물 상세', '선정 이유와 적용 시간을 함께 확인해요.'), 'outerwear': ('겉옷 상세', '준비물별 이유를 따로 확인해요.'), 'settings': ('연결·자료', '지역 원본과 마지막 자료를 확인해요.'), 'prepare-more': ('준비물 더 보기', '목록을 스크롤하는 다음 구간 예시예요.'), 'prepare-checked': ('챙겨요 · 체크 예시', '우산은 챙김, 겉옷은 아직 챙기지 않은 상태예요.'), 'alerts-more': ('기상/생활 · 아래 구간', '대기질·대기정체·가시거리·꽃가루를 확인해요.'), 'alerts-last': ('기상/생활 · 마지막 구간', '강수량·적설량까지 같은 2열 목록에 이어져요.')}
labels.update({'metric-'+str(i): (label+' 상세', '값·기준 시각·자료 의미를 확인해요.') for i,(label,*_) in enumerate(metrics)})
screens = {state: {scene: screen(state, scene) for scene in ['rain', 'dry', 'stale']} for state in labels}

css = '''
@font-face{font-family:Suite;src:url(FONT)}@font-face{font-family:Suite;src:url(BOLD);font-weight:700}
*{box-sizing:border-box}body{margin:0;background:#F6F7F8;color:#29343D;font-family:Suite,sans-serif}button{font:inherit;cursor:pointer}button:focus-visible,[role=button]:focus-visible{outline:3px solid #5D7F9E;outline-offset:4px}button:disabled{cursor:default}header{padding:48px 60px 25px}header .eyebrow{font-size:12px;color:#5D7F9E;letter-spacing:2.4px;font-weight:700}h1{font-size:38px;letter-spacing:-1.2px;margin:14px 0 10px}p{margin:0;color:#63707A;line-height:1.65}.badge{display:inline-block;padding:7px 12px;border:1px solid #CEDAE4;border-radius:30px;color:#3E5F7C;font-size:12px;margin-right:5px}.toplinks{position:absolute;right:60px;top:56px;display:flex;gap:20px}.toplinks a{color:#3E5F7C;font-size:13px;text-decoration:none}.layout{max-width:1420px;margin:12px auto 50px;display:grid;grid-template-columns:220px 1fr 270px;gap:38px;padding:0 40px}.nav{display:flex;flex-direction:column;gap:8px;padding-top:25px}.nav button{border:0;border-radius:16px;text-align:left;background:transparent;color:#63707A;padding:17px 20px;font-size:15px}.nav button.active{background:#EAF0F5;color:#3E5F7C;font-weight:700}.stage{padding:24px;text-align:center;background:#EBEFF2;border-radius:36px;min-height:580px;display:flex;align-items:center;flex-direction:column;justify-content:center}.watch{width:376px;height:376px;padding:12px;border-radius:50%;background:linear-gradient(135deg,#535E65,#172027 35%,#424E57 62%,#10171D);box-shadow:0 22px 44px #26323E20;position:relative;margin:16px auto}.watch:after{content:'';position:absolute;right:-5px;top:135px;height:47px;width:6px;border-radius:5px;background:#4E5A64;z-index:-1}.bezel{border-radius:50%;padding:3px;background:#050708;height:100%}.screen-svg{display:block;width:100%;height:100%;font-family:Suite,sans-serif}.screen-svg [role=button]{cursor:pointer}.scenario{display:flex;gap:6px;justify-content:center;flex-wrap:wrap;margin:15px 0 0}.scenario button{font-size:12px;padding:9px 12px;background:white;border:1px solid #DDE4E9;border-radius:30px;color:#63707A}.scenario button.active{background:#3E5F7C;color:white;border-color:#3E5F7C}.caption{margin-top:16px;font-size:12px;color:#63707A}.notes{padding-top:55px}.notes h2{font-size:23px;margin:0 0 16px}.notes .line{height:1px;background:#CEDAE4;margin:26px 0}.notes .small{font-size:12px}.notes button{width:100%;border-radius:18px;border:1px solid #CEDAE4;background:#fff;color:#3E5F7C;padding:15px;margin-top:16px}.notes .tag{font-size:11px;letter-spacing:1.3px;color:#5D7F9E;font-weight:700}.note-status{font-size:12px;color:#63707A;margin-top:20px;min-height:45px}.boards{padding:38px 60px 45px;max-width:1600px;margin:auto}.board-header{display:flex;justify-content:space-between;align-items:flex-end;border-top:1px solid #CEDAE4;padding-top:22px;margin-bottom:30px}.board-header h2{font-size:24px;margin:0}.board-header p{font-size:12px}.gallery{display:grid;grid-template-columns:repeat(3,1fr);gap:32px 24px}.figure{text-align:center}.figure .watch{width:310px;height:310px;padding:10px;box-shadow:0 12px 26px #26323E12}.figure h3{font-size:17px;margin:18px 0 7px}.figure p{font-size:12px}.gallery.widgets{grid-template-columns:repeat(4,1fr)}.gallery.widgets .watch{width:280px;height:280px;padding:9px}.gallery.widgets .figure p{max-width:260px;margin:auto}.footer{font-size:11px;margin-top:38px;border-top:1px solid #CEDAE4;padding-top:18px;color:#63707A;display:flex;justify-content:space-between}.board-brand{margin:0 0 38px;font-size:13px;color:#3E5F7C;letter-spacing:2px}.board-title{font-size:36px;margin:0 0 14px}.board-intro{margin-bottom:36px}#overview-board{background:#F6F7F8}#widgets-board{background:#F6F7F8}.palette{display:flex;gap:10px;margin-top:15px}.palette span{border-radius:50%;width:23px;height:23px;display:block}.mobile{display:none}@media(max-width:1050px){header{padding:30px}.toplinks{position:static;margin-top:20px}.layout{grid-template-columns:180px 1fr;gap:15px;padding:0 25px}.notes{grid-column:1/-1;padding-top:0}.gallery.widgets{grid-template-columns:repeat(2,1fr)}.gallery{grid-template-columns:repeat(2,1fr)}.boards{padding:30px}.watch{width:340px;height:340px}}@media(max-width:650px){h1{font-size:29px}.layout{display:flex;flex-direction:column;padding:0 15px}.nav{flex-direction:row;overflow:auto;white-space:nowrap;padding:0}.nav button{padding:12px}.stage{min-height:500px;padding:10px}.watch{width:min(330px,86vw);height:min(330px,86vw)}.gallery,.gallery.widgets{grid-template-columns:1fr}.figure .watch{width:290px;height:290px}.boards{padding:25px}.board-header{display:block}.board-title{font-size:29px}.footer{display:block;line-height:1.7}.notes{padding:15px}.board-header p{margin-top:10px}}
'''
css += '''
.card-stage{width:280px;height:310px;margin:16px auto;display:flex;align-items:center;justify-content:center}
.card-stage .widget-card-svg{display:block;width:280px;height:auto;flex:none}
.spec-label{font-size:11px;color:#3E5F7C;margin:10px 0 0;line-height:1.6}
.spec-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px;background:#EAF0F5;padding:24px;border-radius:24px}
.spec-item{display:flex;flex-direction:column;align-items:center;justify-content:center;padding:14px;background:#F6F7F8;border-radius:16px;min-height:230px}
.spec-item .widget-card-svg{width:320px;height:auto;max-width:100%}
@media(max-width:650px){.spec-grid{grid-template-columns:1fr}.card-stage{width:280px}}
'''
css = css.replace('FONT', font).replace('BOLD', bold)

nav = ''.join(f'<button data-screen="{name}" class="{"active" if name == "prepare" else ""}">{i+1:02d}　{labels[name][0]}</button>' for i, name in enumerate(['prepare', 'home', 'hourly', 'alerts', 'settings', 'setup']))
app_gallery = ''.join('<article class="figure">' + wearable(screen(name)) + f'<h3>{i+1:02d}　{labels[name][0]}</h3><p>{labels[name][1]}</p></article>' for i, name in enumerate(['prepare', 'home', 'hourly', 'alerts', 'prepare-checked', 'metric-1']))
widget_info = [('small', '소형 위젯', '콘텐츠 166×60dp / 호스트 포함 182×76dp'), ('large', '대형 위젯', '콘텐츠 166×96dp / 호스트 포함 182×112dp'), ('tile', '기존 타일', '기온과 날씨 아이콘, 짧은 브리핑.'), ('complication', '워치페이스 정보', '좌측은 기온, 우측은 날씨 아이콘.')]
widget_gallery = ''.join('<article class="figure">' + ('<div class="card-stage">'+widget(kind)+'</div>' if kind in ['small','large'] else wearable(widget(kind))) + f'<h3>{title}</h3><p>{desc}</p></article>' for kind, title, desc in widget_info)
spec_gallery = ''.join('<article class="spec-item">'+widget_card(p)+f'<p class="spec-label">{p["id"]} · 콘텐츠 {p["widthDp"]:g}×{p["heightDp"]:g}dp<br/>외곽 {p["outerWidthDp"]:g}×{p["outerHeightDp"]:g}dp · 가로/세로 여백 {p["horizontalPaddingDp"]:g}/{p["verticalPaddingDp"]:g}dp</p></article>' for p in widget_specs['profiles'])
footer = '<div class="footer"><span>날씨챙겨 · 손목에서, 챙길 것까지.</span><span>개발 전 시안 / 합성 예보 / 2026.11.02</span></div>'
html = '''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>날씨챙겨 워치 · 디자인 시안</title><style>CSS</style></head><body>
<header><div class="eyebrow">WEATHER CARE / WATCH CONCEPT 01</div><h1>손목에서, 챙길 것까지.</h1><p>한눈에 보는 날씨와 외출 준비. 작게 담고, 분명하게 보여줘요.</p><div style="margin-top:18px"><span class="badge">SM-L340 · 438×438</span><span class="badge">앱 · 위젯 · 컴플리케이션</span><span class="badge">합성 예시 / 설치 화면 아님</span></div><div class="toplinks"><a href="#overview-board">앱 화면 모아보기 ↗</a><a href="#widgets-board">위젯 모아보기 ↗</a></div></header>
<main class="layout"><nav class="nav" aria-label="시안 화면">NAV</nav><section class="stage" aria-label="워치 시안 미리보기"><div id="preview">PREVIEW</div><div class="scenario" aria-label="예시 상황"><button data-scene="rain" class="active">오후 비</button><button data-scene="dry">건조한 날</button><button data-scene="stale">자료 만료</button></div><div class="caption">체크박스를 누르거나 지표를 선택해 상세를 확인하세요.</div></section><aside class="notes"><div class="tag">화면의 역할</div><h2 id="screen-title">챙겨요</h2><p id="screen-description">오른쪽 체크박스로 챙긴 물건을 표시해요.</p><div class="line"></div><p class="small">준비물 우측은 챙김 체크, 품목명은 이유 확인이에요. 기상/생활은 2열 목록을 이어 보고 항목을 눌러 상세를 확인해요.</p><button id="back">이전 화면</button><button id="more">목록 아래로 보기</button><p class="note-status" id="status" aria-live="polite">09:35 합성 자료 · 실제 기기/서버 연결 없음</p><div class="palette" aria-label="기존 앱의 파란색과 어두운 표면"><span style="background:#9DBDD8"></span><span style="background:#253747"></span><span style="background:#1D2731"></span><span style="background:#E6B879"></span></div></aside></main>
<section class="boards" id="overview-board"><div class="board-brand">날씨챙겨 / WATCH APP · 0.8</div><h2 class="board-title">챙기고, 비교하고, 자세히 확인해요.</h2><p class="board-intro">챙겨요 → 현재 날씨 → 타임라인 → 기상/생활. 체크와 상세 화면까지.</p><div class="gallery">APPGALLERY</div>FOOTER</section>
<section class="boards" id="widgets-board"><div class="board-brand">날씨챙겨 / GLANCEABLE SURFACES · 0.8</div><h2 class="board-title">실제 콘텐츠 영역 안으로.</h2><p class="board-intro">공식 SDK의 작은 화면용 기본 프리뷰 규격. 소형과 대형을 같은 배율로 비교했어요.</p><div class="gallery widgets">WIDGETGALLERY</div><div class="board-header" style="margin-top:36px"><h2>최저·최고도 카드 안쪽 하단에</h2><p>공식 표준 프리뷰 기반 재구성 / 실제 기기 호스트 측정·Native 렌더링은 미실시</p></div><p>검정 카드 바깥은 위젯 영역이 아니에요. 콘텐츠 크기에 호스트 여백을 더한 외곽 안에 모두 배치했어요.</p>FOOTER</section>
<section class="boards" id="spec-board"><div class="board-header"><h2>공식 프리뷰 10개 규격 확인</h2><p>wear-tooling-preview 1.0.0-alpha21 / Squircle·Round·Rectangular</p></div><div class="spec-grid">SPECGALLERY</div>FOOTER</section>
<script>
const screens=SCREENS;const names=LABELS;const history=[];const ready={};let current='prepare',scene='rain';
function paintCheck(node,checked){node.setAttribute('aria-checked',String(checked));const rect=node.querySelector('rect[stroke]');rect.setAttribute('fill',checked?'#9DBDD8':'none');node.querySelector('path')?.remove();if(checked){const tick=document.createElementNS('http://www.w3.org/2000/svg','path');const y=Number(rect.getAttribute('y'))+8;Object.entries({d:`M159 ${y}l4 4 7-8`,fill:'none',stroke:'#172736','stroke-width':2,'stroke-linecap':'round','stroke-linejoin':'round'}).forEach(([k,v])=>tick.setAttribute(k,v));node.append(tick)}}
function toggleCheck(node){const checked=node.getAttribute('aria-checked')!=='true';ready[node.dataset.check]=checked;paintCheck(node,checked)}
function show(name,remember=true){if(!screens[name])return;if(remember&&name!==current)history.push(current);current=name;document.getElementById('preview').innerHTML='<div class="watch"><div class="bezel">'+screens[name][scene]+'</div></div>';document.querySelectorAll('#preview [data-check]').forEach(node=>paintCheck(node,ready[node.dataset.check]??node.getAttribute('aria-checked')==='true'));document.getElementById('screen-title').textContent=names[name][0];document.getElementById('screen-description').textContent=names[name][1];document.querySelectorAll('.nav button').forEach(b=>b.classList.toggle('active',b.dataset.screen===name));document.getElementById('more').hidden=!['prepare','prepare-more','prepare-checked','alerts','alerts-more','alerts-last'].includes(name);document.getElementById('status').textContent=scene==='stale'?'07:00 합성 자료 · 오래된 자료 상태':'09:35 합성 자료 · 실제 기기/서버 연결 없음'}
document.addEventListener('click',e=>{const cb=e.target.closest('[data-check]');if(cb){toggleCheck(cb);return}const target=e.target.closest('[data-screen]');if(target)show(target.dataset.screen);const s=e.target.closest('[data-scene]');if(s){scene=s.dataset.scene;document.querySelectorAll('[data-scene]').forEach(b=>b.classList.toggle('active',b===s));show(scene==='stale'?'offline':current,false)}});
document.addEventListener('keydown',e=>{if(!['Enter',' '].includes(e.key))return;const cb=e.target.closest('g[data-check]');if(cb){e.preventDefault();toggleCheck(cb);return}const g=e.target.closest('g[data-screen]');if(g){e.preventDefault();show(g.dataset.screen)}});
document.getElementById('back').onclick=()=>show(history.pop()||'prepare',false);document.getElementById('more').onclick=()=>show(({prepare:'prepare-more','prepare-checked':'prepare-more','prepare-more':'prepare',alerts:'alerts-more','alerts-more':'alerts-last','alerts-last':'alerts'})[current]||'prepare');show('prepare',false);
</script></body></html>
'''
for key, value in [('CSS', css), ('NAV', nav), ('PREVIEW', wearable(screen('prepare'))), ('APPGALLERY', app_gallery), ('WIDGETGALLERY', widget_gallery), ('SPECGALLERY',spec_gallery), ('FOOTER', footer), ('SCREENS', json.dumps(screens, ensure_ascii=False)), ('LABELS', json.dumps(labels, ensure_ascii=False))]:
    html = html.replace(key, value)
(HERE / 'index.html').write_text(html, encoding='utf-8')
(HERE / 'device-summary.json').write_text(json.dumps({'확인일': '2026-11-02', '모델': 'SM-L340', '제품명': '갤럭시 워치9 블루투스 40mm (삼성 공식 지원 기준)', 'android': '17', 'api': 37, '해상도': [438, 438], 'densityDpi': 340, 'rendererVersion': '1.6.1.87.907578152', '동작': 'ADB 읽기 조회만 수행, 설치/설정 변경 없음', '디자인': '합성 자료, 실제 앱 미구현'}, ensure_ascii=False, indent=2), encoding='utf-8')
print('한글 폰트·기존 준비물 자산을 포함한 독립 시안 생성 완료')
