import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/features/home/tabs/today_tab.dart';
import 'package:weather_care/features/home/widgets/nearby_observation_preview.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/theme/weather_theme.dart';

Future<void> loadOriginalFonts() async {
  final manifest=jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for(final family in manifest) {
    final loader=FontLoader(family['family'] as String);
    for(final font in family['fonts'] as List) {loader.addFont(rootBundle.load(Uri.decodeFull(font['asset'] as String)));}
    await loader.load();
  }
}

TodayWeatherResponse sample(bool far) => TodayWeatherResponse.fromJson({
  'generatedAt':'2026-10-09T11:51:00+09:00',
  'region':{'nx':far?35:48,'ny':far?106:29,'name':far?'태안군 근흥면':'서귀포시 대정읍'},
  'brief':'구름이 많고 바람이 불어요.\n외출 전 예보를 확인해요.',
  'sunriseAt':'2026-10-09T06:35:00+09:00','sunsetAt':'2026-10-09T18:09:00+09:00',
  'current':{'temperature':21.4,'apparentTemperature':21.1,'apparentTemperatureSource':'APP_STEADMAN_FROM_OBSERVATION','dataRole':'OBSERVATION','provider':'KMA_APIHUB_GRID_OBSERVATION','observedAt':'2026-10-09T11:40:00+09:00','humidity':60,'windSpeed':3.1,'windDirection':45,'skyCondition':'구름많음','uvIndex':4,'pm10':24,'pm25':10,'visibilityMeters':15000},
  'nextForecast':{'temperature':22.0,'apparentTemperature':21.8,'forecastAt':'2026-10-09T12:00:00+09:00','dataRole':'FORECAST','skyCondition':'구름많음','humidity':58,'windSpeed':3.0,'windDirection':45,'uvIndex':4,'pm25ForecastGrade':'좋음'},
  'recommendations':[{'type':'OUTERWEAR','recommended':true,'priority':2,'description':'바람이 불어 얇은 겉옷을 준비해요.'},{'type':'SUNSCREEN','recommended':true,'priority':1,'description':'낮에는 자외선 차단에 신경 써요.'}],
  'hourly':[for(int h=12;h<=18;h++){'time':'2026-10-09T${h}:00:00+09:00','temperature':h<16?22:20,'apparentTemperature':21,'precipitationProbability':20,'humidity':60,'windSpeed':3.1,'windDirection':45,'skyCondition':'구름많음','uvIndex':4,'precipitationAmount':0}],
},receivedAt:DateTime.now());

Widget previewScreen({required bool far,required bool todayTab,required GlobalKey capture}) {
  final response=sample(far);
  return RepaintBoundary(key:capture,child:MaterialApp(
    debugShowCheckedModeBanner:false,theme:WeatherCareTheme.light(),builder:WeatherCareTheme.textScaleBuilder,
    home:Scaffold(
      body:SafeArea(bottom:false,child:todayTab
        ? TodayTab(today:response,onRefresh:()async{})
        : MainTab(today:response,dateLabel:'10월 9일 금요일',mood:'cloudy',serverFeaturesAvailable:true,onRefresh:()async{},onDetail:(_){})),
      bottomNavigationBar:NavigationBar(
        selectedIndex:todayTab?0:2,height:74,backgroundColor:Colors.white,surfaceTintColor:Colors.transparent,
        indicatorColor:WeatherCareTheme.primarySoft,labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
        destinations:const [
          NavigationDestination(icon:Icon(Icons.work_outline_rounded,color:WeatherCareTheme.textSecondary),selectedIcon:Icon(Icons.work_rounded,color:WeatherCareTheme.textSecondary),label:'Today'),
          NavigationDestination(icon:Icon(Icons.query_stats_outlined,color:WeatherCareTheme.textSecondary),label:'Detail'),
          NavigationDestination(icon:Icon(Icons.home_outlined,color:WeatherCareTheme.textSecondary),selectedIcon:Icon(Icons.home_rounded,color:WeatherCareTheme.textSecondary),label:'Main'),
          NavigationDestination(icon:Icon(Icons.calendar_month_outlined,color:WeatherCareTheme.textSecondary),label:'Week'),
          NavigationDestination(icon:Icon(Icons.tune_outlined,color:WeatherCareTheme.textSecondary),label:'Setting'),
        ],
      ),
    ),
  ));
}

void main() {
  final binding=TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('실제 앱 위젯으로 인근 실황 화면 캡처',(tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize=const Size(390,1000);tester.view.devicePixelRatio=1;
    await tester.runAsync(loadOriginalFonts);
    print('original fonts loaded');
    final out=Directory('../../output/visualizations/actual-app');await tester.runAsync(()=>out.create(recursive:true));
    for(final view in [(false,false,'main-near'),(true,false,'main-far'),(false,true,'today-near')]) {
      PreviewSource.distanceKm=view.$1?51.5:5.1;
      final capture=GlobalKey();
      await tester.pumpWidget(previewScreen(far:view.$1,todayTab:view.$2,capture:capture));
      print('rendering ${view.$3}');
      await tester.pump(const Duration(milliseconds:500));
      await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:200)));
      await tester.pump(const Duration(milliseconds:500));
      final scrollView=find.byKey(ValueKey(view.$2?'today-tab':'main-tab'));
      final scrollable=find.descendant(of:scrollView,matching:find.byType(Scrollable)).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      expect(find.textContaining('인근 실황 · 약'),findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.runAsync(()async{
        final boundary=capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image=await boundary.toImage(pixelRatio:2);
        final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
        await File('${out.path}/${view.$3}.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();
      });
      if(view.$3=='main-near') {
        await tester.tap(find.textContaining('인근 실황 · 약'));await tester.pumpAndSettle();
        expect(find.text('인근 실황 안내'),findsOneWidget);
        await tester.runAsync(()async{
          final image=await (capture.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio:2);
          final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
          await File('${out.path}/main-source-details.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
    }
    tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
  });
}
