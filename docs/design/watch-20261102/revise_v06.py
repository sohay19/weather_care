from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
for filename in ['build_design.py', 'build_pdf.py', 'README.md']:
    p = HERE / filename
    p.write_text(p.read_text(encoding='utf-8').replace('0.5', '0.6'), encoding='utf-8')

p = HERE / 'build_pdf.py'
s = p.read_text(encoding='utf-8').replace('검정 바탕·기존 바탕색의 개별 박스·아이콘/기온 순서와 타일 세로 중앙을 반영했습니다.', '소형·대형 최저/최고는 중앙 하단, 기존 타일의 주요 묶음은 직전 시안보다 위로 조정했습니다.')
s = s.replace('검정 바탕 / 아이콘→기온 / 한 줄 체감', '최저/최고 중앙 하단으로 이동')
s = s.replace('검정 바탕, 정보·준비물 배경색 통일', '최저/최고를 소형과 같은 중앙 하단에')
s = s.replace('기온·날씨~브리핑 묶음 하향·세로 중앙', '기온·날씨~브리핑을 직전보다8dp 위로')
p.write_text(s, encoding='utf-8')

p = ROOT / 'docs/워치앱_위젯_기획서_20261102.md'
s = p.read_text(encoding='utf-8').replace('버전: 0.5', '버전: 0.6')
s = s.replace('하단 중앙에는 최저·최고 기온을 표시한다.', '최저·최고 기온은 원형 화면의 중앙 하단에 같은 기준선(x104/y187, 시안208dp 기준)으로 표시한다.')
s = s.replace('하단 중앙은 최저·최고 기온 순으로 배치한다.', '최저·최고 기온은 소형과 같은 원형 화면 중앙 하단 기준선(x104/y187)에 배치한다.')
s = s.replace('기온+날씨 아이콘부터 브리핑까지 하나의 묶음으로21dp 내려 지역/기준시각 아래와 최저/최고 위 사이에 세로 중앙 배치한다.', '기온+날씨 아이콘부터 브리핑까지 하나의 묶음으로 유지하고0.5 시안보다8dp 위로 올린다. 지역/기준시각·하단최저최고는 유지한다.')
p.write_text(s, encoding='utf-8')

p = HERE / 'README.md'
s = p.read_text(encoding='utf-8') + '\n0.6: 소형/대형최저최고를같은원형화면중앙하단(x104/y187)에배치했다. 기존타일기온·날씨·브리핑묶음은0.5시안보다8dp상향했다.\n'
p.write_text(s, encoding='utf-8')
print('0.6 개정 내용 반영 완료')
