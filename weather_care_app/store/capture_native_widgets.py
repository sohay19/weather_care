"""사용자가 지정한 촬영 대상에서 실제 Android Provider·AppWidgetHost 화면을 촬영한다.

--real-weather는 앱에 저장된 실자료를 사용한다. 종료 시 위젯 설정과 시스템 테마를 복원한다.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', required=True, help='사용자가 지정한 Android 촬영 대상 일련번호')
    parser.add_argument('--apk', type=Path, required=True, help='최신 소스로 빌드하고 디버그 키로 서명한 APK')
    parser.add_argument('--build-only', action='store_true', help='촬영 도구 APK만 빌드')
    parser.add_argument('--real-weather', action='store_true', help='예시 주입 없이 현재 앱의 실제 날씨로 촬영')
    parser.add_argument('--output', type=Path, help='원본 저장 폴더')
    parser.add_argument('--skip-app-install', action='store_true', help='최신 APK가 이미 설치된 기기에서 앱 재설치 생략')
    parser.add_argument('--package', default='com.codesoha.weathercare', help='별도 촬영용 앱의 패키지 이름')
    parser.add_argument('--capture-date', default='2026-10-28', help='촬영 기준일')
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')
    sdk = Path(os.environ['ANDROID_HOME'])
    build = ROOT.parent / 'build/widget-alignment-20261022/instrumentation'
    output = args.output or ROOT / 'screenshots/native-20261022'
    for folder in [build / 'classes', build / 'dex', output]:
        folder.mkdir(parents=True, exist_ok=True)
    android = sdk / 'platforms/android-35/android.jar'
    binaries = sdk / 'build-tools/36.0.0'
    java = Path(os.environ['JAVA_HOME']) / 'bin'
    adb = sdk / 'platform-tools/adb.exe'

    def run(command):
        completed = subprocess.run([str(item) for item in command], capture_output=True,
                                   encoding='utf-8', errors='replace')
        if completed.returncode:
            raise RuntimeError(completed.stdout + completed.stderr)
        return completed.stdout

    def device(*command):
        return run([adb, '-s', args.serial, *command])

    run([java / 'javac.exe', '-encoding', 'UTF-8', '--release', '17', '-cp', android,
         '-d', build / 'classes', ROOT / 'native_widget_capture/WidgetCapture.java'])
    run([binaries / 'd8.bat', '--min-api', '27', '--lib', android,
         '--output', build / 'dex', *sorted((build / 'classes').rglob('*.class'))])
    unsigned = build / 'capture-unsigned.apk'
    manifest = build / 'AndroidManifest.xml'
    manifest.write_text((ROOT / 'native_widget_capture/AndroidManifest.xml').read_text(encoding='utf-8')
                        .replace('android:targetPackage="com.codesoha.weathercare"',
                                 f'android:targetPackage="{args.package}"'), encoding='utf-8')
    run([binaries / 'aapt2.exe', 'link', '-I', android, '--manifest', manifest, '-o', unsigned])
    with zipfile.ZipFile(unsigned, 'a', zipfile.ZIP_DEFLATED) as archive:
        archive.write(build / 'dex/classes.dex', 'classes.dex')
    keystore = Path(os.environ['ANDROID_USER_HOME']) / 'debug.keystore'
    signed = build / 'capture.apk'
    run([binaries / 'apksigner.bat', 'sign', '--ks', keystore, '--ks-key-alias',
         'androiddebugkey', '--ks-pass', 'pass:android', '--key-pass', 'pass:android',
         '--out', signed, unsigned])
    if args.build_only:
        print(f'네이티브 촬영 도구 빌드 완료: {signed}')
        return
    if not args.skip_app_install:
        device('install', '-r', str(args.apk.resolve()))
    device('install', '-r', str(signed))
    original_mode = device('shell', 'cmd', 'uimode', 'night').split(':')[-1].strip()
    if original_mode not in ['auto', 'no', 'yes', 'custom']:
        raise RuntimeError(f'기존 시스템 테마를 확인할 수 없습니다: {original_mode}')
    try:
        for theme, night in [('light', 'no'), ('dark', 'yes')]:
            device('shell', 'cmd', 'uimode', 'night', night)
            device('shell', 'am', 'force-stop', args.package)
            log = device('shell', 'am', 'instrument', '-w', '-r', '-e', 'theme', theme,
                         '-e', 'realWeather', str(args.real_weather).lower(),
                         'com.codesoha.weathercare.capture/.WidgetCapture')
            (build / f'{theme}.log').write_text(log, encoding='utf-8')
            if 'INSTRUMENTATION_CODE: -1' not in log:
                raise RuntimeError(log)
            print(f'{theme}: 실제 AppWidgetHost 촬영·정렬 검증 통과', flush=True)
    finally:
        device('shell', 'cmd', 'uimode', 'night', original_mode)
    raw = build / 'raw'
    raw.mkdir(exist_ok=True)
    device('pull', f'/sdcard/Android/data/{args.package}/files/store-native-widget/.', str(raw))
    for theme in ['light', 'dark']:
        for family in ['small', 'medium', 'large']:
            name = f'{theme}-{family}.png'
            shutil.copy2(raw / name, output / name)
    from PIL import Image
    records = []
    for path in sorted(output.glob('*.png')):
        with Image.open(path) as image:
            image.load()
            records.append({'path': path.name, 'size': list(image.size),
                            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                            **json.loads((raw / path.with_suffix('.json').name).read_text(encoding='utf-8'))})
    sources = [ROOT.parent / 'android/app/src/main/java/com/weathercare/weather_care' / name
               for name in ['WeatherCareWidgetProvider.java', 'WidgetTextRenderer.java', 'WidgetIconRenderer.java']]
    sources += sorted((ROOT.parent / 'android/app/src/main/res/layout').glob('weather_widget_*.xml'))
    sources += sorted((ROOT.parent / 'android/app/src/main/res/drawable').glob('*widget_refresh*.xml'))
    report = {'제작일': args.capture_date, '패키지': args.package, '방식': '실제 Android Provider를 AppWidgetHost에 바인딩한 네이티브 화면',
              '데이터': '현재 앱의 운영 서버 실제 날씨' if args.real_weather else '촬영용 예시 날씨, 실제 현재 관측 아님',
              '모델': device('shell', 'getprop', 'ro.product.model').strip(),
              'Android_API': device('shell', 'getprop', 'ro.build.version.sdk').strip(),
              '표시_밀도': device('shell', 'wm', 'density').strip(),
              'APK_SHA256': hashlib.sha256(args.apk.read_bytes()).hexdigest(),
              '소스_SHA256': {p.relative_to(ROOT.parent).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                             for p in sources}, 'files': records}
    (output / 'capture-manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'네이티브 촬영 원본 {len(records)}개: {output}')


if __name__ == '__main__':
    main()
