import fs from 'node:fs/promises';
import { Workbook, SpreadsheetFile } from '@oai/artifact-tool';

const outputDir = 'D:/IdeaProjects/weather_care/output/grid_api_20261013';
const workbook = Workbook.create();
const main = workbook.worksheets.add('항목별 판단');
const calc = workbook.worksheets.add('API 호출 산정');
const evidence = workbook.worksheets.add('근거와 가정');
const navy = '#17365D';
const pale = '#EAF1F8';
const amber = '#FFF0C2';
const red = '#FBE4E5';
const gray = '#64748B';

for (const sheet of [main, calc, evidence]) {
  sheet.showGridLines = false;
  sheet.getRange('A1:T60').format.font = { name: 'Arial', size: 10, color: '#1F2937' };
  sheet.getRange('A1:T60').format.verticalAlignment = 'center';
}
main.tabColor = navy;
calc.tabColor = '#527CA5';

const groups = [
  ['조위관측', '국립해양조사원', 50, 24, 1, 10000, '관측소×시간별 갱신. 조위·수온 등 한 응답 공유. 지점 수는 가정.', 'S1'],
  ['해양부이관측', '국립해양조사원', 40, 24, 1, 10000, '부이×시간별 갱신. 수온·유향·유속 한 응답 공유. 지점 수는 가정.', 'S2'],
  ['고저조예보', '국립해양조사원', 50, 1, 1, 10000, '예보지점×요청일. 만조·간조 시각 이벤트. 지점 수는 가정.', 'S3'],
  ['조석시계열', '국립해양조사원', 50, 1, 1, 10000, '예보지점×요청일. 시간 간격을 요청. 지점 수는 가정.', 'S4'],
  ['ROMS예측', '국립해양조사원', 10, 24, 1, 10000, '해역 타일×미래 24개 시각 가정. 실제 허용 bbox·페이지·모델 발표주기 미검증.', 'S5'],
  ['이안류관측', '국립해양조사원', 10, 24, 1, 10000, '해수욕장×시간별 갱신. 운영 해수욕장 10곳 기준, 계절 운영.', 'S6'],
  ['하천관측', '한국수자원공사', 100, 24, 1, 10000, '수위관측소×시간별 갱신. 수위·유량 한 응답 공유. 지점 수는 가정.', 'S8'],
  ['댐운영', '한국수자원공사', 61, 24, 1, 10000, '댐·보 61지점×시간별 갱신. 수위·유입·방류 한 응답 공유.', 'S9'],
  ['낙뢰좌표', '기상청 APIHub', 1, 144, 1, 20000, '전국 좌표 원시자료 10분마다 1회. 시간 중복 제거 후 nx/ny에 배정. 응답 바이트 미측정.', 'S13'],
  ['해파리목록', '국립수산과학원', 1, 4, 1, null, '하루 4회 목록 확인 가정. 새 속보/주간보고 상세는 건별 추가. 시간별 격자 지수 아님.', 'S7'],
];

calc.getRange('A2').values = [['API 호출 산정']];
calc.getRange('A3').values = [['중앙 서버 공용 수집 예시. 모든 격자·사용자별 중복 호출은 하지 않는다. 지점·해역 분할 수와 재시도·추가 페이지는 실측 전 가정이다.']];
calc.getRange('A5:L5').values = [['수집 묶음', '제공처', '대상 수/타일 수', '호출 주기(회/일)', '페이지·재시도 배수', '예상 호출/일', '공개 한도/일', '호출 건수 판정', '산정 근거·제약', '가정 응답 KB/회', '예상 MB/일', '공개 용량 한도']];
const assumedKb = [10, 10, 10, 10, 1000, 10, 10, 10, 100, 10];
for (let i = 0; i < groups.length; i++) {
  const row = i + 6;
  const [name, provider, targets, interval, factor, quota, note] = groups[i];
  calc.getRange(`A${row}:E${row}`).values = [[name, provider, targets, interval, factor]];
  calc.getRange(`F${row}`).formulas = [[`=C${row}*D${row}*E${row}`]];
  if (quota !== null) calc.getRange(`G${row}`).values = [[quota]];
  calc.getRange(`H${row}`).formulas = [[quota === null ? '="계정 한도 미확인"' : `=IF(F${row}>G${row},"초과","건수상 여유")`]];
  calc.getRange(`I${row}`).values = [[note]];
  calc.getRange(`J${row}`).values = [[assumedKb[i]]];
  calc.getRange(`K${row}`).formulas = [[`=F${row}*J${row}/1000`]];
  calc.getRange(`L${row}`).values = [[provider === '기상청 APIHub' ? '일반회원 공식 5GB/일' : '공개 명세에서 확인 못함']];
}
calc.getRange('A18:C21').values = [['제공처별', '예상 중복 제거 호출/일', '가정 응답 용량 MB/일'], ['국립해양조사원', null, null], ['한국수자원공사', null, null], ['기상청 APIHub', null, null]];
calc.getRange('B19').formulas = [['=SUMIFS(F6:F15,B6:B15,A19)']];
calc.getRange('B20').formulas = [['=SUMIFS(F6:F15,B6:B15,A20)']];
calc.getRange('B21').formulas = [['=SUMIFS(F6:F15,B6:B15,A21)']];
for (let row=19;row<=21;row++) calc.getRange(`C${row}`).formulas = [[`=SUMIFS(K6:K15,B6:B15,A${row})`]];
calc.getRange('A23:B24').values = [['별도 참고', '국립수산과학원 해파리 목록은 시간별 격자 항목이 아니므로 위 세 기관 합계에서 제외'], ['한도 해석', '포털 1만 회는 각 API 개발계정 안내값이다. 실제 계정 승인량·동일 키 서비스 간 합산 정책을 확인해야 한다.']];
calc.getRange('A27:B27').values = [['APIHub 공식 5GB 용량 판정', '단위 MB(10진). 기존 필수 3,842MB + 재시도 최대 예약 400MB = 4,242MB. 서버 내부 보호선은 판정 기준에서 제외한다.']];
calc.getRange('A29:B35').values = [['공식 1일 용량 MB', 5000], ['공식 1일 호출 한도', 20000], ['기존 겨울 예산 MB', 4242], ['낙뢰 조회/일', null], ['공식 한도 허용 평균 MB/회', null], ['낙뢰 가정 응답 MB/일', null], ['가정 응답 반영 후 공식 잔여 MB', null]];
calc.getRange('B32').formulas = [['=F14']];
calc.getRange('B33').formulas = [['=(B29-B31)/B32']];
calc.getRange('B34').formulas = [['=K14']];
calc.getRange('B35').formulas = [['=B29-B31-B34']];
calc.getRange('A39:B43').values = [['하천 10분 운영안', '일일 호출'], ['개발계정 안내 한도', null], ['10분 수집 필요 호출', null], ['개발계정 부족분', null], ['운영계정 신청 최소', null]];
calc.getRange('B40').formulas = [['=G12']];
calc.getRange('B41').formulas = [['=C12*144']];
calc.getRange('B42').formulas = [['=B41-B40']];
calc.getRange('B43').formulas = [['=B41']];
calc.getRange('A44').values = [['운영계정 한도 상향 가능. 고정 횟수 미공개; 승인값 확인 필요.']];
calc.getRange('A46:B48').values = [['운영계정 공개 고정 한도', '숫자 미공개; 활용사례 등록 후 증량 신청'], ['실제 승인 일한도(사용자 입력)', null], ['승인량 기준 10분안 결과', null]];
calc.getRange('B48').formulas = [['=IF(B47="","승인량 미확인",IF(B47>=B41,"가능","부족"))']];
calc.getRange('D29:G33').values = [['낙뢰 응답 가정 MB/회', '하루 낙뢰 용량 MB', '기존 겨울 예산 합산 MB', '공식 5GB 판정'], [0.1, null, null, null], [1, null, null, null], [2, null, null, null], ['판정 기준', '상한 약 5.264MB/회', '실제 바이트·당일 사용량 미확인', '기존 계획값 기준']];
for (let row=30;row<=32;row++) {
  calc.getRange(`E${row}`).formulas = [[`=D${row}*$B$32`]];
  calc.getRange(`F${row}`).formulas = [[`=$B$31+E${row}`]];
  calc.getRange(`G${row}`).formulas = [[`=IF(F${row}<=$B$29,"가능","불가능")`]];
}

main.getRange('A2').values = [['격자 기반 날씨 항목 API 조사']];
main.getRange('A3').values = [['기준: 2026-10-14, 기상청 nx/ny 전국 원본판 149×253=37,697셀. 지점 자료는 해당 지점이 있는 격자 또는 명시한 주변 시설에만 연결한다.']];
main.getRange('A4').values = [['판정: 격자 전체에 실제 값을 줄 수 있는 항목은 제한적이다. 같은 API를 공유하는 항목의 호출 수는 행별로 반복 표기하지만 API 호출 산정 탭의 총합에서는 한 번만 센다.']];
main.getRange('A6:T6').values = [[
  '분류', '항목명', '추가 상태', 'API가 제공하는 구역', '우리격자구역(API 구역과 비교)', '구역 차이와 안내 범위', '현재·지난 시간대별 안내', '현재·지난 API 호출정보', '관측 호출/일',
  '미래 시간대별 안내', '미래 API 호출정보', '예보 호출/일', '둘 다 가능 시 합계/일', 'API한도', '한도 결과(가능/불가능 + 이유)', '운영계정 전환·증량 시', '제공처', '자료 범위·표시 주의', '추가 신청·확인', '근거'
]];

const rows = [
  ['바다','수온','검토','관측 지점 격자 한정; 예측 해역 격자 대응','가능: 지점 관측 시계열','해양부이 40곳×24회; 수온·유향·유속 공유',7,'가능: 모델값','ROMS 10해역×24미래시각 가정',10,'수온 실측과 모델 예측을 구분','KHOA 각 API 1만 회 기준 수치는 여유; bbox/용량 미검증','국립해양조사원','관측 없는 바다 격자에 관측값 생성 금지','부이 최신관측·ROMS 활용신청, 공간 범위 실측','S2,S5'],
  ['바다','만조/간조','검토','예보지점 연안 격자 한정','관측 극값의 시간별 API 미확인','관측 조위에서 극값 산출 시 별도 검증 필요',null,'부분 가능: 일별 고·저조 시각 이벤트','예보지점 50곳×요청일 1회',8,'매시간 연속 수치가 아니라 발생 시각','건수상 여유; 모든 해안 격자 보장 불가','국립해양조사원','실제 만·간조와 예측 이벤트를 혼동 금지','고·저조 예보 활용신청, 지점-격자 매핑','S3'],
  ['바다','조위','검토','관측소 격자 한정; 예보지점 격자 한정','가능: 지점 관측 시계열','조위관측소 50곳×24회; 수온 등 공유',6,'가능: 지점 조석 시계열 예측','예보지점 50곳×요청일 1회',9,'관측·예측 기준면 확인','각 API 건수상 여유; 지점 간 보간은 별도','국립해양조사원','관측 조위와 천문조석 예측값의 차이 존재','관측·시계열 예보 활용신청, 기준면 검증','S1,S4'],
  ['바다','유속','검토','부이 격자 한정; ROMS 해역 격자 대응','가능: 부이 관측 시계열','해양부이 40곳×24회; 수온·유향 공유',7,'가능: 표층 모델 예측','ROMS 10해역×24미래시각 가정',10,'관측 깊이와 모델 표층 비교 주의','건수상 여유; bbox/페이지·용량 미검증','국립해양조사원','조류예보 시계열은 약 200 지점의 별도 대안','부이·ROMS 신청, 깊이/단위 검증','S2,S5,S15'],
  ['바다','유향','검토','부이 격자 한정; ROMS 해역 격자 대응','가능: 부이 관측 시계열','해양부이 40곳×24회; 수온·유속 공유',7,'가능: 표층 모델 예측','ROMS 10해역×24미래시각 가정',10,'북기준·방향 정의 확인','건수상 여유; bbox/페이지·용량 미검증','국립해양조사원','풍향과 유향의 의미가 다름','부이·ROMS 신청, 방향 정의 검증','S2,S5,S15'],
  ['바다','이안류 위험지수','검토','지정 해수욕장 격자만','가능: 해수욕장 관측 시각','10개 해수욕장×24회 가정',11,'공식 미래 시간별 지수 미확인','추정 예보로 표시하지 않음',null,'','건수상 여유; 계절·대상 제한','국립해양조사원','4단계 지수; 해수욕장 밖 같은 격자로 확장 금지','이안류 API 신청, 운영기간 확인','S6'],
  ['바다','해파리 정보','검토','광역 해역 보고; 격자 단위 부재','시간별 수치 안내 불가','목록 4회/일 가정+신규 문서 상세. 시간별 호출에서 제외',null,'시간별 예보 불가','주간보고의 금후전망은 정량 시간 예보 아님',null,'','호출 한도 공개값 미확인; 세부 건수 가변','국립수산과학원','속보·주간보고를 지도 설명으로 제공 가능','NIFS API 신청, 해역 경계 해석','S7'],
  ['강','하천 수위','검토','수위관측소가 있는 하천 구간·격자 한정','가능: 관측소별 시계열','100관측소×24회 가정; 유량 공유',12,'전국 격자 시간별 공식 예보 미확인','홍수예보 일부 지점과 별도',null,'','1만 회 기준 2,400회; 10분 갱신 시 14,400회로 초과','한국수자원공사','격자 안 모든 하천의 수위가 같지 않음','우량수위 API 신청, 지점목록 확정','S8'],
  ['강','하천 유량','검토','유량 관측소가 있는 하천 구간·격자 한정','가능: 관측소별 시계열','100관측소×24회 가정; 수위 공유',12,'전국 격자 시간별 공식 예보 미확인','홍수예보 일부 지점과 별도',null,'','1만 회 기준 2,400회; 10분 갱신 시 14,400회로 초과','한국수자원공사','유량은 하천 단면의 값; 면적 전체값 아님','우량수위 API 신청, 관측소 좌표/하천 연결','S8'],
  ['강','댐 수위','검토','댐 시설 격자 또는 저수지 위치 한정','가능: 댐별 시계열','61댐·보×24회; 유입·방류 공유',13,'공식 전국 시간별 예보 미확인','운영계획은 실제 수위 예보와 구분',null,'','1만 회 기준 1,464회; 10분 갱신은 8,784회','한국수자원공사','61개 댐·보 범위; 모든 댐 아님','수문 운영 API 신청, 시설 좌표 매핑','S9'],
  ['강','댐 방류량','검토','댐 시설·하류 영향 구간 별도','가능: 댐별 시계열','61댐·보×24회; 수위·유입 공유',13,'확정 방류계획의 시간별 API 미확인','예정 방류와 실제 방류를 구분',null,'','1만 회 기준 1,464회; 10분 갱신은 8,784회','한국수자원공사','댐 위치 격자만으로 하류 영향 판정 불가','수문 운영 API 신청, 방류 공지 별도 조사','S9'],
  ['강','댐 유입량','검토','댐 시설 격자 한정','가능: 댐별 시계열','61댐·보×24회; 수위·방류 공유',13,'공식 전국 시간별 예보 미확인','모델 추정치 임의 사용 금지',null,'','1만 회 기준 1,464회; 10분 갱신은 8,784회','한국수자원공사','유입량은 운영 자료의 계산값','수문 운영 API 신청, 단위 확인','S9'],
  ['산','고도별 풍향·풍속','제외 확정','KIM 모델 격자는 앱 지상 nx/ny와 좌표 변환 필요','윈드프로파일러는 10분 지점 관측; 전 격자 시간별 아님','제외 결정으로 추가 호출 0',null,'KIM 3차원 모델 후보이나 제외','제외 결정으로 추가 호출 0',null,'','APIHub 용량 부담으로 도입 제외','기상청 APIHub','레윈존데 정기 관측은 하루 2회; 산의 임의 고도 실측 아님','현재 신청 대상 아님','S10,S11'],
  ['산','구름 높이','제외 확정','ASOS 최저운고는 관측소 지점값','지점 관측 가능; 전 산악 격자 시간별 아님','제외 결정으로 추가 호출 0',null,'같은 의미의 격자 미래 API 검증 안 됨','제외 결정으로 추가 호출 0',null,'','APIHub 용량 부담으로 도입 제외','기상청 APIHub','레이더 에코상단 고도는 최저운고가 아님','현재 신청 대상 아님','S12'],
  ['산','운량 수치','제외 확정','ASOS 전운량은 관측소 지점값','지점 관측 가능; 전 산악 격자 시간별 아님','제외 결정으로 추가 호출 0',null,'KIM 전운량 모델 후보이나 제외','제외 결정으로 추가 호출 0',null,'','APIHub 용량 부담으로 도입 제외','기상청 APIHub','기존 SKY는 맑음·구름많음·흐림 범주','현재 신청 대상 아님','S11,S12'],
  ['그외','낙뢰','검토','전국 낙뢰 좌표를 발생 위치 nx/ny에 배정','가능: 관측 좌표·시각','전국 원시자료 10분마다 1회; 지역별 호출 안 함',14,'공식 격자별 시간대 예보 미확인','발생 위치 관측을 미래 발생 예보로 표시 금지',null,'','호출 144회는 여유; 응답 바이트·실제 잔여 4.5GB 확인 필요','기상청 APIHub','이전 행정구역 횟수 API 24회/일 산정은 격자 요구에 부적합','낙뢰관측 활용신청, 용량 실측·결측 점검','S13,S14'],
];
const apiZones = [
  '해양관측부이 지점 좌표; ROMS 해상 예측 bbox',
  '연안 조석 예보 지점',
  '조위관측소 지점; 조석 예보 지점',
  '해양관측부이 지점; ROMS 해상 예측 bbox',
  '해양관측부이 지점; ROMS 해상 예측 bbox',
  '지정 이안류 감시 해수욕장',
  '속보·주간보고의 광역 해역',
  '하천 수위관측소 지점',
  '하천 유량관측소 지점',
  'K-water 댐·보 시설 지점',
  'K-water 댐·보 시설 지점',
  'K-water 댐·보 시설 지점',
  '윈드프로파일러 지점; KIM 모델 자체 격자',
  'ASOS 관측소 지점',
  'ASOS 관측소 지점; KIM 모델 자체 격자',
  '전국 낙뢰 발생 좌표',
];
const ourZones = [
  '부이 격자만 실측; ROMS는 해상 nx/ny에 재매핑',
  '예보 지점이 속한 연안 격자만 연결',
  '관측·예보 지점이 속한 격자만 연결',
  '부이 격자만 실측; ROMS 해상 격자 변환',
  '부이 격자만 실측; ROMS 해상 격자 변환',
  '해수욕장 위치 격자만 연결',
  '광역 해역을 5km 격자값으로 환산 불가',
  '관측소가 위치한 하천 격자만 연결',
  '관측소가 위치한 하천 격자만 연결',
  '댐 시설 위치 격자만 연결',
  '댐 시설 격자와 하류 영향구역은 별개',
  '댐 시설 위치 격자만 연결',
  '지점·모델 격자와 nx/ny 불일치; 도입 제외',
  '관측소 격자만 실측; 도입 제외',
  '지점·모델 격자와 nx/ny 불일치; 도입 제외',
  '낙뢰 좌표를 발생 위치 nx/ny로 변환',
];
const zoneDifferences = [
  '관측은 부이 한 점뿐이라 같은 5km 격자 전체 수온이 아니다. ROMS는 해상 모델 격자를 우리 격자에 변환해야 하며 공간 해상도·해안 경계가 다르다.',
  'API는 일부 연안 예보 지점의 만·간조 시각만 준다. 지점이 없는 해안 격자에는 해당 시각을 확정 안내할 수 없다.',
  '관측소·예보 지점은 점 자료지만 우리 격자는 5km 면이다. 한 격자 안의 다른 항만·연안까지 같은 조위를 적용할 수 없다.',
  '부이 유속은 특정 위치·깊이의 관측이다. ROMS 표층 모델값을 재격자화해도 관측 없는 5km 격자의 실측 유속은 아니다.',
  '부이 유향은 특정 위치·깊이의 관측이다. ROMS 표층 모델 방향을 재격자화할 때 방향 기준과 해안 경계도 맞춰야 한다.',
  'API는 지정 해수욕장별 지수다. 우리 격자 하나에 해수욕장이 여러 곳이거나 바다만 있어도 격자 전체 위험도를 뜻하지 않는다.',
  '속보는 넓은 해역·발견 지점을 설명한다. 이를 5km 격자마다 동일한 해파리 출현·위험 수치로 나눌 근거가 없다.',
  '수위는 하천 관측 단면의 높이이며 5km 면값이 아니다. 같은 격자의 다른 지류·지점에는 값이 달라진다.',
  '유량은 관측 단면을 통과하는 양이다. 같은 5km 격자 속 다른 하천이나 상·하류 전체 유량으로 쓸 수 없다.',
  '댐 수위는 시설·저수지의 값이다. 시설이 속한 격자와 저수지가 걸친 여러 격자의 지형 높이를 동일하게 나타내지 않는다.',
  '방류량은 댐 출구의 값이다. 하류 여러 격자의 유속·수위를 뜻하지 않으며 영향 범위에는 하천 연결과 이동시간 계산이 필요하다.',
  '유입량은 댐으로 모이는 집계값이다. 상류 5km 격자별 유량으로 쪼개거나 댐 주변 면적값으로 사용할 수 없다.',
  '고층관측은 소수 지점의 수직 높이값, KIM은 별도 3차원 모델 격자다. 우리 2차원 nx/ny만으로 임의 산 고도별 실측 바람이 되지 않는다.',
  'ASOS 최저운고는 관측소 상공 값이다. 주변 산 능선·계곡이 있는 5km 격자 전체 구름 밑면 높이와 다를 수 있다.',
  'ASOS 전운량은 관측소 하늘 비율, KIM은 별도 모델 격자값이다. 우리 격자 전체의 실측 운량으로 바로 변환할 수 없다.',
  'API는 개별 발생 좌표를 주므로 우리 격자별 발생 이력은 집계 가능하다. 다만 격자 전체 낙뢰 위험도나 미래 발생 예보를 뜻하지 않는다.',
];
const operatingAccountResults = [
  '현재 호출안은 개발계정 1만 회 미만. 운영계정은 심의승인·활용사례 등록 후 증량 신청 가능하지만 현재는 불필요하며 공간 범위는 동일.',
  '현재 호출안은 개발계정 1만 회 미만. 운영계정 증량은 가능성만 안내되며 지점 부족은 해결하지 못함.',
  '현재 호출안은 각 개발계정 API 한도 내. 운영계정 증량 가능성은 있으나 지점 관측·예보의 공간 차이는 그대로.',
  '현재 호출안은 각 개발계정 API 한도 내. ROMS bbox·페이지 제약은 운영계정 전환만으로 해결 보장 안 됨.',
  '현재 호출안은 각 개발계정 API 한도 내. ROMS bbox·페이지 제약은 운영계정 전환만으로 해결 보장 안 됨.',
  '현재 호출안은 개발계정 한도 내. 운영계정 증량으로 지정 해수욕장 수나 운영기간은 늘지 않음.',
  '운영계정 구분·증량 가능 여부 공개 확인 불가. 계정 변경만으로 시간별 5km 격자 자료는 생기지 않음.',
  '운영계정으로 한도 상향 신청 가능. 이 API의 운영계정 고정 횟수는 공개되지 않음. 14,400회/일+페이지·재시도분 이상 승인되면 10분 수집 가능.',
  '운영계정으로 한도 상향 신청 가능. 이 API의 운영계정 고정 횟수는 공개되지 않음. 14,400회/일+페이지·재시도분 이상 승인되면 10분 수집 가능.',
  '시간별 1,464회, 10분별 8,784회로 개발계정 1만 회 이내. 운영계정 전환은 필수 아님; 재시도 증가 시 증량 검토.',
  '시간별 1,464회, 10분별 8,784회로 개발계정 1만 회 이내. 운영계정 전환은 필수 아님; 재시도 증가 시 증량 검토.',
  '시간별 1,464회, 10분별 8,784회로 개발계정 1만 회 이내. 운영계정 전환은 필수 아님; 재시도 증가 시 증량 검토.',
  '도입 제외. 공공데이터포털 운영계정과 APIHub 회원 구분은 별개이며 계정 변경을 검토할 대상 아님.',
  '도입 제외. 공공데이터포털 운영계정과 APIHub 회원 구분은 별개이며 계정 변경을 검토할 대상 아님.',
  '도입 제외. 공공데이터포털 운영계정과 APIHub 회원 구분은 별개이며 계정 변경을 검토할 대상 아님.',
  '공공데이터포털 운영계정 전환 불필요. 2MB/회 가정의 4.53GB/일은 APIHub 일반회원 공식 5GB/일 이내. 실제 바이트 확인 후 공식 한도와 비교; 기관회원 신청은 현재 계산상 불필요.',
];
const quotaResults = [
  '가능(계획): 부이 960·ROMS 240회/일, 각각 1만 회 미만. 용량 한도·bbox 분할 미검증.',
  '가능(계획): 고저조 50회/일로 1만 회 미만. 예보 지점만 제공.',
  '가능(계획): 관측 1,200·예보 50회/일, 각 API 1만 회 미만. 용량 한도 미공개.',
  '가능(계획): 부이 960·ROMS 240회/일, 각각 1만 회 미만. 용량 한도·bbox 분할 미검증.',
  '가능(계획): 부이 960·ROMS 240회/일, 각각 1만 회 미만. 용량 한도·bbox 분할 미검증.',
  '가능(계획): 240회/일로 1만 회 미만. 감시 해수욕장·계절에 한정.',
  '판정 불가: 공식 호출·용량 한도 미확인. 시간별 격자 제공도 불가.',
  '가능(시간별): 개발 2,400회/일<1만 회. 10분안은 개발 1만 회 초과지만 운영계정 승인 한도 14,400회+재시도분이면 가능.',
  '가능(시간별): 개발 2,400회/일<1만 회. 10분안은 개발 1만 회 초과지만 운영계정 승인 한도 14,400회+재시도분이면 가능.',
  '가능(시간별): 1,464회/일<1만 회. 10분별 61곳은 8,784회로 재시도 여유 작음.',
  '가능(시간별): 1,464회/일<1만 회. 10분별 61곳은 8,784회로 재시도 여유 작음.',
  '가능(시간별): 1,464회/일<1만 회. 10분별 61곳은 8,784회로 재시도 여유 작음.',
  '도입 제외: 추가 호출·용량 0. 후보 API의 용량은 산정 대상 아님.',
  '도입 제외: 추가 호출·용량 0. 후보 API의 용량은 산정 대상 아님.',
  '도입 제외: 추가 호출·용량 0. 후보 API의 용량은 산정 대상 아님.',
  '가능(공식 한도): 2MB/회 가정도 겨울 합산 4.53GB<APIHub 5GB. 144회/일 호출도 2만 회 내. 실제 평균 약 5.264MB/회 초과 시 용량 초과.',
];
for (let i=0;i<rows.length;i++) {
  const r=i+7, row=rows[i];
  const quota = row[12] === '기상청 APIHub' ? 'APIHub 일반회원 공식 20,000회·5GB/일' : row[12] === '국립수산과학원' ? '호출·용량 한도 공개값 미확인' : '해당 API 개발계정 10,000회/일; 운영계정 증량 가능(고정 숫자 미공개); 용량 한도 미공개';
  main.getRange(`A${r}:H${r}`).values=[[row[0],row[1],row[2],apiZones[i],ourZones[i],zoneDifferences[i],row[4],row[5]]];
  if (row[6]) main.getRange(`I${r}`).formulas=[[`='API 호출 산정'!F${row[6]}`]];
  main.getRange(`J${r}:K${r}`).values=[[row[7],row[8]]];
  if (row[9]) main.getRange(`L${r}`).formulas=[[`='API 호출 산정'!F${row[9]}`]];
  if (row[6] && row[9]) main.getRange(`M${r}`).formulas=[[`=I${r}+L${r}`]];
  main.getRange(`N${r}:T${r}`).values=[[quota,quotaResults[i],operatingAccountResults[i],row[12],row[13],row[14],i === 15 ? 'S13,S14,S18' : row[15]]];
}
main.getRange('A25').values = [['항목별 호출/일은 해당 항목만 단독 구현할 때의 수치다. 여러 항목을 함께 제공할 때는 API 호출 산정 탭의 중복 제거 합계를 사용한다.']];
main.getRange('A26').values = [['한도 판정은 제공처 공식 한도와 저장소의 겨울 계획 예산을 사용하며 서버 내부 보호선은 제외한다. 운영계정 고정 한도와 실제 승인량, 응답 KB는 미확인이다.']];

evidence.getRange('A2').values = [['근거와 계산 가정']];
evidence.getRange('A4:B4').values = [['항목', '내용']];
evidence.getRange('A5:B13').values = [
  ['격자 기준', '기상청 단기예보 원본판 149×253=37,697셀. 바다·산·하천 API의 공간 격자는 해상도와 좌표계가 다를 수 있다.'],
  ['표시 원칙', '좌표 또는 시설 위치가 속한 nx/ny에 연결하되, 같은 격자 전체가 동일한 실측값이라는 뜻으로 표시하지 않는다. 해역/하천 경계와 거리 제한을 추가해야 한다.'],
  ['관측 호출', '현재값을 1시간마다 갱신하는 예시: 지점 수×24회/일. API가 과거 하루 시계열을 한 번에 제공해도 최신값 갱신은 반복 호출한다.'],
  ['예보 호출', '고저조·조석 시계열은 지점×하루 1회 가정. ROMS는 bbox 타일 10개×미래 24개 시각 조회 가정. 실제 요청당 시간범위·페이지 제한은 명세/응답 검증 필요.'],
  ['예시 대상', '조위관측소 50, 해양부이 40, 조석예보 50, ROMS 타일 10, 하천 100은 설계 가정. 댐·보 61과 이안류 해수욕장 10은 공식 공개 범위 기준.'],
  ['한도', '공공데이터포털 해당 API 개발계정은 10,000회/일. 운영계정은 활용사례 등록 후 트래픽 증가 신청 가능하나 고정 적용 수치가 공개되지 않았다. APIHub 일반회원 공식 한도는 20,000회·5GB/일이며 내부 보호선은 이번 판정에서 제외한다.'],
  ['낙뢰', 'lgt_pnt 전국 조회에는 lon/lat을 생략할 수 있다. 10분마다 이전 10분 창을 조회하는 산정은 API 요청 범위·응답 상한 검증 전 계획값이다. 5분 신속 갱신은 288회/일.'],
  ['공유 호출', '부이 수온/유속/유향, 하천 수위/유량, 댐 수위/유입/방류는 각 묶음의 응답을 공동 사용한다. 항목별 숫자를 더하면 중복 계상된다.'],
  ['제외 범위', '사용자가 제외한 고도별 풍향·풍속, 구름 높이, 운량 수치의 추가 호출은 0으로 표기했다. 후보 API 제공 가능성과 구현 결정은 별개다.'],
];
evidence.getRange('A14:B15').values = [
  ['APIHub 공식 용량 여유', '기존 저장소 겨울 계획치 3,842MB+재시도 예약 400MB=4,242MB. 공식 5,000MB까지 758MB 남음. 낙뢰 144회면 허용 평균 758/144=5.264MB/회. 2MB/회 가정 시 합산 4,530MB로 공식 한도 내. 실제 바이트·당일 사용량은 미측정.'],
  ['응답 용량 시나리오', 'API 호출 산정 J열은 실측값이 아닌 편집 가능한 가정: 지점·목록 10KB/회, ROMS 1,000KB/회, 낙뢰 100KB/회. 포털 API는 명세에 바이트 한도가 없어 예상 네트워크량만 계산.'],
];
evidence.getRange('A35:B37').values = [
  ['구역 차이', 'API 지점·해수욕장·시설·광역 해역·해양모델 bbox는 기상청 nx/ny 5km 셀과 범위·해상도가 다르다. 위치를 셀에 연결하는 것은 셀 전체의 동일 실측값을 뜻하지 않는다.'],
  ['운영계정', 'K-water 해당 API는 운영단계 자동승인과 활용사례 등록 후 트래픽 증가 신청을 안내하지만 운영계정의 고정 일일 횟수는 공개하지 않는다. 실제 승인된 숫자를 입력해 판정해야 한다. 포털 운영계정과 APIHub 회원 등급은 별개다.'],
  ['한도 초과 대안', '하천 100곳 10분 수집은 14,400회/일로 개발 10,000회 초과. 운영계정에서 최소 14,400회+페이지·재시도 여유를 승인받으면 가능. APIHub 낙뢰 2MB/회 가정은 공식 5GB 한도 내라 포털 운영계정 변경이 필요 없다.'],
];
evidence.getRange('A16:D16').values = [['코드', '공식 출처', '확인 내용', 'URL']];
const sources = [
  ['S1','국립해양조사원 조위관측소 최신 관측데이터','지점·날짜·간격 조회, 조위·수온·유속·유향 등. 개발계정 1만 회.','https://www.data.go.kr/data/15155508/openapi.do'],
  ['S2','국립해양조사원 해양관측부이 최신 관측데이터','지점·날짜·간격 조회, 수온·유향·유속 등.','https://www.data.go.kr/data/15155516/openapi.do'],
  ['S3','국립해양조사원 조석예보(고, 저조)','예보지점·요청일별 고저조 시각과 조위. 개발계정 1만 회.','https://www.data.go.kr/data/15156018/openapi.do'],
  ['S4','국립해양조사원 조석예보(시계열)','예보지점·요청일·시간간격별 예측 조위. 개발계정 1만 회.','https://www.data.go.kr/data/15156022/openapi.do'],
  ['S5','국립해양조사원 ROMS 수치예측모델','검색 bbox, 예측일시·위경도·표층 수온·유향·유속. 개발계정 1만 회.','https://www.data.go.kr/data/15142227/openapi.do'],
  ['S6','국립해양조사원 이안류 지수 조회','해수욕장 코드·일자별 관측시각·4단계 지수. 개발계정 1만 회.','https://www.data.go.kr/data/15156028/openapi.do'],
  ['S7','국립수산과학원 OPENAPI 목록','해파리 목록과 속보·주간보고 상세. 생성주기 수시.','https://www.nifs.go.kr/openApi/actionOpenapiInfoList.do'],
  ['S8','한국수자원공사 우량수위 관측소 운영 정보','관측소별 수위·유량, 10분/30분/시간. 개발 1만 회; 운영 증량 신청 가능, 고정 수치 미공개.','https://www.data.go.kr/data/15099115/openapi.do'],
  ['S9','한국수자원공사 수문 운영 정보','61개 댐·보 수위·유입량·방류량. 개발 1만 회; 운영 증량 신청 가능, 고정 수치 미공개.','https://www.data.go.kr/data/15099110/openapi.do'],
  ['S10','기상청 APIHub 고층관측','레윈존데 정기 하루 2회, 윈드프로파일러 10분 간격 지점 관측.','https://apihub.kma.go.kr/apiList.do?seqApi=4'],
  ['S11','기상청 APIHub 수치모델','KIM 예측 파일·변수 후보. 격자·용량 별도 검증 필요.','https://apihub.kma.go.kr/apiList.do?seqApi=9'],
  ['S12','기상청 APIHub 지상관측','ASOS CA_TOT 전운량·CH_MIN 최저운고는 지점 관측.','https://apihub.kma.go.kr/apiList.do'],
  ['S13','기상청 APIHub 낙뢰관측','lgt_pnt 시간범위·선택적 lon/lat/range, TM/LON/LAT 출력.','https://apihub.kma.go.kr/apiList.do?apiMov=%EB%82%99%EB%A2%B0+%EC%9B%90%EC%8B%9C%EC%9E%90%EB%A3%8C+%EC%A1%B0%ED%9A%8C&seqApi=5&seqApiSub=264'],
  ['S14','기상청 APIHub 이용안내','일반회원 하루 20,000회·5GB.','https://apihub.kma.go.kr/apiInfo.do'],
  ['S15','국립해양조사원 조류예보(시계열)','약 200개 예보 지점의 유향·유속 시계열. 연 1회 갱신.','https://www.data.go.kr/data/15156024/openapi.do'],
  ['S16','해양수산부 이안류 감시 보도자료','주요 10개 해수욕장·개장기간 운영.','https://www.mof.go.kr/doc/ko/selectDoc.do?bbsSeq=10&docSeq=57128&menuSeq=971&pWiseMain=N2&pwise=mMain'],
  ['S17','기상청 동네예보 격자영역 정보','동서 149×남북 253의 5km 격자, Lambert 투영 및 변환 기준.','https://apihub.kma.go.kr/getAttachFile.do?fileName=%2820240305%29%EB%8F%99%EB%84%A4%EC%98%88%EB%B3%B4+%EA%B2%A9%EC%9E%90%EC%98%81%EC%97%AD+%EC%A0%95%EB%B3%B4.pdf'],
  ['S18','저장소 제공처별 예상 예산','현재 경로의 겨울 APIHub 필수 3.842GB, 재시도 예약 0.400GB를 공식 5GB와 비교.','docs/전체_수정사항_및_반영상태_20261010.md'],
];
evidence.getRange(`A17:D${16+sources.length}`).values=sources;

for (const [sheet, titleRange, headerRange, maxCol] of [
  [main,'A2','A6:T6','T'], [calc,'A2','A5:L5','L'], [evidence,'A2','A16:D16','D']
]) {
  sheet.getRange(titleRange).format.font = { name:'Arial', size:15, bold:true, color:navy };
  sheet.getRange(headerRange).format.fill=navy;
  sheet.getRange(headerRange).format.font={name:'Arial',size:10,bold:true,color:'#FFFFFF'};
  sheet.getRange(headerRange).format.rowHeight=36;
  sheet.getRange(headerRange).format.wrapText=true;
  sheet.getRange(`A1:${maxCol}1`).format.rowHeight=13;
}
main.getRange('A6:T6').format.horizontalAlignment='center';
calc.getRange('A5:L5').format.horizontalAlignment='center';
evidence.getRange('A16:D16').format.horizontalAlignment='center';
main.getRange('A7:T22').format.rowHeight=93;
main.getRange('A7:T22').format.wrapText=true;
calc.getRange('A6:L15').format.rowHeight=52;
calc.getRange('A6:L15').format.wrapText=true;
evidence.getRange('A17:D34').format.rowHeight=42;
evidence.getRange('A17:D34').format.wrapText=true;
main.getRange('C19:C21').format.fill=amber;
main.getRange('O7:O22').format.fill=pale;
main.getRange('O14:O15').format.fill=red;
main.getRange('O22').format.fill=amber;
calc.getRange('C6:E15').format.fill=amber;
calc.getRange('J6:J15').format.fill=amber;
calc.getRange('B47').format.fill=amber;
calc.getRange('C6:G15').setNumberFormat('#,##0');
calc.getRange('J6:K15').setNumberFormat('#,##0.0');
calc.getRange('B33:B35').setNumberFormat('#,##0.000');
main.getRange('I7:M22').setNumberFormat('#,##0');
calc.getRange('C6:H15').format.horizontalAlignment='center';
main.getRange('I7:M22').format.horizontalAlignment='center';
main.getRange('A:A').format.columnWidth=10;
main.getRange('B:B').format.columnWidth=18;
main.getRange('C:C').format.columnWidth=13;
main.getRange('D:D').format.columnWidth=34;
main.getRange('E:E').format.columnWidth=36;
main.getRange('F:F').format.columnWidth=67;
main.getRange('G:G').format.columnWidth=29;
main.getRange('H:H').format.columnWidth=34;
main.getRange('I:I').format.columnWidth=15;
main.getRange('J:J').format.columnWidth=29;
main.getRange('K:K').format.columnWidth=34;
main.getRange('L:M').format.columnWidth=16;
main.getRange('N:N').format.columnWidth=40;
main.getRange('O:O').format.columnWidth=53;
main.getRange('P:P').format.columnWidth=72;
main.getRange('Q:Q').format.columnWidth=18;
main.getRange('R:R').format.columnWidth=40;
main.getRange('S:S').format.columnWidth=37;
main.getRange('T:T').format.columnWidth=13;
calc.getRange('A:A').format.columnWidth=21;
calc.getRange('B:B').format.columnWidth=19;
calc.getRange('C:H').format.columnWidth=17;
calc.getRange('I:I').format.columnWidth=72;
calc.getRange('J:K').format.columnWidth=20;
calc.getRange('L:L').format.columnWidth=34;
calc.getRange('D:D').format.columnWidth=25;
calc.getRange('E:E').format.columnWidth=24;
calc.getRange('F:F').format.columnWidth=26;
calc.getRange('G:G').format.columnWidth=22;
calc.getRange('D29:G33').format.wrapText=true;
calc.getRange('D29:G33').format.rowHeight=38;
evidence.getRange('A:A').format.columnWidth=18;
evidence.getRange('B:B').format.columnWidth=43;
evidence.getRange('C:C').format.columnWidth=68;
evidence.getRange('D:D').format.columnWidth=90;
evidence.getRange('A5:B15').format.rowHeight=55;
evidence.getRange('A5:B15').format.wrapText=true;
evidence.getRange('A35:B37').format.rowHeight=64;
evidence.getRange('A35:B37').format.wrapText=true;
main.freezePanes.freezeRows(6);
calc.freezePanes.freezeRows(5);
evidence.freezePanes.freezeRows(16);

workbook.recalculate();
for (const [sheetName,range,name] of [
  ['항목별 판단','A2:J12','main_left.png'],
  ['항목별 판단','K6:T12','main_right.png'],
  ['API 호출 산정','A2:L15','calc.png'],
  ['API 호출 산정','A27:G35','capacity.png'],
  ['API 호출 산정','A39:D48','operations.png'],
  ['근거와 가정','A2:D15','notes.png'],
  ['근거와 가정','A16:D24','sources.png'],
]) {
  const preview=await workbook.render({sheetName,range,scale:1.25,format:'png'});
  await fs.mkdir(outputDir,{recursive:true});
  await fs.writeFile(`${outputDir}/${name}`,new Uint8Array(await preview.arrayBuffer()));
}
const errors=await workbook.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#NUM!|#NULL!',options:{useRegex:true,maxResults:100},summary:'오류 검사'});
console.log(errors.ndjson);
const check=await workbook.inspect({kind:'table',range:'API 호출 산정!A18:B21',include:'values,formulas',tableMaxRows:4,tableMaxCols:2});
console.log(check.ndjson);
const file=await SpreadsheetFile.exportXlsx(workbook);
await file.save(`${outputDir}/격자기반_바다강산낙뢰_API_조사.xlsx`);
console.log(`${outputDir}/격자기반_바다강산낙뢰_API_조사.xlsx`);
