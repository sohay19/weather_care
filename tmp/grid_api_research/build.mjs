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
  sheet.getRange('A1:Q60').format.font = { name: 'Arial', size: 10, color: '#1F2937' };
  sheet.getRange('A1:Q60').format.verticalAlignment = 'center';
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
  ['낙뢰좌표', '기상청 APIHub', 1, 144, 1, 18000, '전국 좌표 원시자료 10분마다 1회. 시간 중복 제거 후 nx/ny에 배정. 응답 바이트 미측정.', 'S13'],
  ['해파리목록', '국립수산과학원', 1, 4, 1, null, '하루 4회 목록 확인 가정. 새 속보/주간보고 상세는 건별 추가. 시간별 격자 지수 아님.', 'S7'],
];

calc.getRange('A2').values = [['API 호출 산정']];
calc.getRange('A3').values = [['중앙 서버 공용 수집 예시. 모든 격자·사용자별 중복 호출은 하지 않는다. 지점·해역 분할 수와 재시도·추가 페이지는 실측 전 가정이다.']];
calc.getRange('A5:I5').values = [['수집 묶음', '제공처', '대상 수/타일 수', '호출 주기(회/일)', '페이지·재시도 배수', '예상 호출/일', '공개 한도/일', '호출 건수 판정', '산정 근거·제약']];
for (let i = 0; i < groups.length; i++) {
  const row = i + 6;
  const [name, provider, targets, interval, factor, quota, note] = groups[i];
  calc.getRange(`A${row}:E${row}`).values = [[name, provider, targets, interval, factor]];
  calc.getRange(`F${row}`).formulas = [[`=C${row}*D${row}*E${row}`]];
  if (quota !== null) calc.getRange(`G${row}`).values = [[quota]];
  calc.getRange(`H${row}`).formulas = [[quota === null ? '="계정 한도 미확인"' : `=IF(F${row}>G${row},"초과","건수상 여유")`]];
  calc.getRange(`I${row}`).values = [[note]];
}
calc.getRange('A18:B21').values = [['제공처별', '예상 중복 제거 호출/일'], ['국립해양조사원', null], ['한국수자원공사', null], ['기상청 APIHub', null]];
calc.getRange('B19').formulas = [['=SUMIFS(F6:F15,B6:B15,A19)']];
calc.getRange('B20').formulas = [['=SUMIFS(F6:F15,B6:B15,A20)']];
calc.getRange('B21').formulas = [['=SUMIFS(F6:F15,B6:B15,A21)']];
calc.getRange('A23:B24').values = [['별도 참고', '국립수산과학원 해파리 목록은 시간별 격자 항목이 아니므로 위 세 기관 합계에서 제외'], ['한도 해석', '포털 1만 회는 각 API 개발계정 안내값이다. 실제 계정 승인량·동일 키 서비스 간 합산 정책을 확인해야 한다.']];

main.getRange('A2').values = [['격자 기반 날씨 항목 API 조사']];
main.getRange('A3').values = [['기준: 2026-10-13, 기상청 nx/ny 전국 원본판 149×253=37,697셀. 지점 자료는 해당 지점이 있는 격자 또는 명시한 주변 시설에만 연결한다.']];
main.getRange('A4').values = [['판정: 격자 전체에 실제 값을 줄 수 있는 항목은 제한적이다. 같은 API를 공유하는 항목의 호출 수는 행별로 반복 표기하지만 API 호출 산정 탭의 총합에서는 한 번만 센다.']];
main.getRange('A6:P6').values = [[
  '분류', '항목명', '추가 상태', '격자 적용 방식', '현재·지난 시간대별 안내', '현재·지난 API 호출정보', '관측 호출/일',
  '미래 시간대별 안내', '미래 API 호출정보', '예보 호출/일', '둘 다 가능 시 합계/일', '한도 문제', '제공처', '자료 범위·표시 주의', '추가 신청·확인', '근거'
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
for (let i=0;i<rows.length;i++) {
  const r=i+7, row=rows[i];
  main.getRange(`A${r}:F${r}`).values=[[...row.slice(0,6)]];
  if (row[6]) main.getRange(`G${r}`).formulas=[[`='API 호출 산정'!F${row[6]}`]];
  main.getRange(`H${r}:I${r}`).values=[[row[7],row[8]]];
  if (row[9]) main.getRange(`J${r}`).formulas=[[`='API 호출 산정'!F${row[9]}`]];
  if (row[6] && row[9]) main.getRange(`K${r}`).formulas=[[`=G${r}+J${r}`]];
  main.getRange(`L${r}:P${r}`).values=[[...row.slice(11,16)]];
}
main.getRange('A25').values = [['항목별 호출/일은 해당 항목만 단독 구현할 때의 수치다. 여러 항목을 함께 제공할 때는 API 호출 산정 탭의 중복 제거 합계를 사용한다.']];
main.getRange('A26').values = [['한도 판정은 호출 건수 기준 예시다. 별도 승인 상태, 실제 응답 크기, API 페이지 수, 재시도, 현행 다른 기능 사용량은 미확인이다.']];

evidence.getRange('A2').values = [['근거와 계산 가정']];
evidence.getRange('A4:B4').values = [['항목', '내용']];
evidence.getRange('A5:B13').values = [
  ['격자 기준', '기상청 단기예보 원본판 149×253=37,697셀. 바다·산·하천 API의 공간 격자는 해상도와 좌표계가 다를 수 있다.'],
  ['표시 원칙', '좌표 또는 시설 위치가 속한 nx/ny에 연결하되, 같은 격자 전체가 동일한 실측값이라는 뜻으로 표시하지 않는다. 해역/하천 경계와 거리 제한을 추가해야 한다.'],
  ['관측 호출', '현재값을 1시간마다 갱신하는 예시: 지점 수×24회/일. API가 과거 하루 시계열을 한 번에 제공해도 최신값 갱신은 반복 호출한다.'],
  ['예보 호출', '고저조·조석 시계열은 지점×하루 1회 가정. ROMS는 bbox 타일 10개×미래 24개 시각 조회 가정. 실제 요청당 시간범위·페이지 제한은 명세/응답 검증 필요.'],
  ['예시 대상', '조위관측소 50, 해양부이 40, 조석예보 50, ROMS 타일 10, 하천 100은 설계 가정. 댐·보 61과 이안류 해수욕장 10은 공식 공개 범위 기준.'],
  ['한도', '공공데이터포털 각 명세의 개발계정 10,000회/일 안내를 사용. 운영계정 실제 할당량은 조회하지 못했다. APIHub 일반회원 20,000회·5GB, 서버 내부 18,000회·4.5GB.'],
  ['낙뢰', 'lgt_pnt 전국 조회에는 lon/lat을 생략할 수 있다. 10분마다 이전 10분 창을 조회하는 산정은 API 요청 범위·응답 상한 검증 전 계획값이다. 5분 신속 갱신은 288회/일.'],
  ['공유 호출', '부이 수온/유속/유향, 하천 수위/유량, 댐 수위/유입/방류는 각 묶음의 응답을 공동 사용한다. 항목별 숫자를 더하면 중복 계상된다.'],
  ['제외 범위', '사용자가 제외한 고도별 풍향·풍속, 구름 높이, 운량 수치의 추가 호출은 0으로 표기했다. 후보 API 제공 가능성과 구현 결정은 별개다.'],
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
  ['S8','한국수자원공사 우량수위 관측소 운영 정보','관측소별 수위·유량, 10분/30분/시간. 개발계정 1만 회.','https://www.data.go.kr/data/15099115/openapi.do'],
  ['S9','한국수자원공사 수문 운영 정보','61개 댐·보 수위·유입량·방류량. 개발계정 1만 회.','https://www.data.go.kr/data/15099110/openapi.do'],
  ['S10','기상청 APIHub 고층관측','레윈존데 정기 하루 2회, 윈드프로파일러 10분 간격 지점 관측.','https://apihub.kma.go.kr/apiList.do?seqApi=4'],
  ['S11','기상청 APIHub 수치모델','KIM 예측 파일·변수 후보. 격자·용량 별도 검증 필요.','https://apihub.kma.go.kr/apiList.do?seqApi=9'],
  ['S12','기상청 APIHub 지상관측','ASOS CA_TOT 전운량·CH_MIN 최저운고는 지점 관측.','https://apihub.kma.go.kr/apiList.do'],
  ['S13','기상청 APIHub 낙뢰관측','lgt_pnt 시간범위·선택적 lon/lat/range, TM/LON/LAT 출력.','https://apihub.kma.go.kr/apiList.do?apiMov=%EB%82%99%EB%A2%B0+%EC%9B%90%EC%8B%9C%EC%9E%90%EB%A3%8C+%EC%A1%B0%ED%9A%8C&seqApi=5&seqApiSub=264'],
  ['S14','기상청 APIHub 이용안내','일반회원 하루 20,000회·5GB.','https://apihub.kma.go.kr/apiInfo.do'],
  ['S15','국립해양조사원 조류예보(시계열)','약 200개 예보 지점의 유향·유속 시계열. 연 1회 갱신.','https://www.data.go.kr/data/15156024/openapi.do'],
  ['S16','해양수산부 이안류 감시 보도자료','주요 10개 해수욕장·개장기간 운영.','https://www.mof.go.kr/doc/ko/selectDoc.do?bbsSeq=10&docSeq=57128&menuSeq=971&pWiseMain=N2&pwise=mMain'],
  ['S17','기상청 동네예보 격자영역 정보','동서 149×남북 253의 5km 격자, Lambert 투영 및 변환 기준.','https://apihub.kma.go.kr/getAttachFile.do?fileName=%2820240305%29%EB%8F%99%EB%84%A4%EC%98%88%EB%B3%B4+%EA%B2%A9%EC%9E%90%EC%98%81%EC%97%AD+%EC%A0%95%EB%B3%B4.pdf'],
];
evidence.getRange(`A17:D${16+sources.length}`).values=sources;

for (const [sheet, titleRange, headerRange, maxCol] of [
  [main,'A2','A6:P6','P'], [calc,'A2','A5:I5','I'], [evidence,'A2','A16:D16','D']
]) {
  sheet.getRange(titleRange).format.font = { name:'Arial', size:15, bold:true, color:navy };
  sheet.getRange(headerRange).format.fill=navy;
  sheet.getRange(headerRange).format.font={name:'Arial',size:10,bold:true,color:'#FFFFFF'};
  sheet.getRange(headerRange).format.rowHeight=36;
  sheet.getRange(headerRange).format.wrapText=true;
  sheet.getRange(`A1:${maxCol}1`).format.rowHeight=13;
}
main.getRange('A6:P6').format.horizontalAlignment='center';
calc.getRange('A5:I5').format.horizontalAlignment='center';
evidence.getRange('A16:D16').format.horizontalAlignment='center';
main.getRange('A7:P22').format.rowHeight=55;
main.getRange('A7:P22').format.wrapText=true;
calc.getRange('A6:I15').format.rowHeight=52;
calc.getRange('A6:I15').format.wrapText=true;
evidence.getRange('A17:D33').format.rowHeight=42;
evidence.getRange('A17:D33').format.wrapText=true;
main.getRange('C19:C21').format.fill=amber;
main.getRange('L7:L22').format.fill=pale;
main.getRange('L14:L15').format.fill=red;
main.getRange('L22').format.fill=amber;
calc.getRange('C6:E15').format.fill=amber;
calc.getRange('C6:G15').setNumberFormat('#,##0');
main.getRange('G7:K22').setNumberFormat('#,##0');
calc.getRange('C6:H15').format.horizontalAlignment='center';
main.getRange('G7:K22').format.horizontalAlignment='center';
main.getRange('A:A').format.columnWidth=10;
main.getRange('B:B').format.columnWidth=18;
main.getRange('C:C').format.columnWidth=13;
main.getRange('D:D').format.columnWidth=30;
main.getRange('E:E').format.columnWidth=29;
main.getRange('F:F').format.columnWidth=34;
main.getRange('G:G').format.columnWidth=15;
main.getRange('H:H').format.columnWidth=29;
main.getRange('I:I').format.columnWidth=34;
main.getRange('J:K').format.columnWidth=16;
main.getRange('L:L').format.columnWidth=40;
main.getRange('M:M').format.columnWidth=18;
main.getRange('N:N').format.columnWidth=40;
main.getRange('O:O').format.columnWidth=37;
main.getRange('P:P').format.columnWidth=13;
calc.getRange('A:A').format.columnWidth=21;
calc.getRange('B:B').format.columnWidth=19;
calc.getRange('C:H').format.columnWidth=17;
calc.getRange('I:I').format.columnWidth=72;
evidence.getRange('A:A').format.columnWidth=18;
evidence.getRange('B:B').format.columnWidth=43;
evidence.getRange('C:C').format.columnWidth=68;
evidence.getRange('D:D').format.columnWidth=90;
evidence.getRange('A5:B13').format.rowHeight=49;
evidence.getRange('A5:B13').format.wrapText=true;
main.freezePanes.freezeRows(6);
calc.freezePanes.freezeRows(5);
evidence.freezePanes.freezeRows(16);

workbook.recalculate();
for (const [sheetName,range,name] of [
  ['항목별 판단','A2:H12','main_left.png'],
  ['항목별 판단','H6:P12','main_right.png'],
  ['API 호출 산정','A2:I15','calc.png'],
  ['근거와 가정','A2:D13','notes.png'],
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
