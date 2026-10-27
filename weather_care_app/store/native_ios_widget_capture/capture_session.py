"""촬영 XCTest가 준비된 시뮬레이터에서 세 크기·두 모드의 실제 홈 위젯을 촬영한다."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--kind', choices=['phone', 'tablet'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--legacy', action='store_true', help='iOS 17에서 크기별로 홈 위젯을 추가·촬영')
    parser.add_argument('--families', default='small,medium,large')
    parser.add_argument('--real-app', action='store_true', help='제품 앱의 실제 저장 자료로 홈 위젯 촬영')
    parser.add_argument('--keep-session', action='store_true', help='촬영 후 앱 조작 세션 유지')
    parser.add_argument('--theme-matrix', action='store_true', help='촬영 호스트의 기기 2모드 × 앱 3모드와 시스템 전환 검증')
    args = parser.parse_args()
    if args.theme_matrix and args.real_app:
        parser.error('--theme-matrix는 예시 촬영 호스트에서만 사용합니다.')
    if args.theme_matrix and not args.legacy:
        parser.error('--theme-matrix는 --legacy와 함께 사용합니다.')
    control = (Path(__file__).parent.parent / 'native_ios_app_capture/control.py'
               if args.real_app else Path(__file__).with_name('control.py'))
    widget_name = '날씨챙겨' if args.real_app else '날씨챙겨 촬영'
    tree = ''

    def command(action, name, **kwargs):
        nonlocal tree
        payload = dict(action=action, name=name, **kwargs)
        if args.real_app:
            payload['system'] = True
        result = subprocess.run([sys.executable, str(control), '--device', args.device,
            '--command', json.dumps(payload, ensure_ascii=False)], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stderr)
        tree = result.stdout
        print(name, flush=True)

    def tap(*labels, name):
        actual = re.findall(r"label: '([^']*)'", tree)
        label = next((label for label in labels if label in actual), None)
        if label is None:
            raise RuntimeError(f'현재 접근성 트리에 필요한 버튼이 없습니다: {labels}')
        command('tap', name, label=label, wait=2)

    def appearance(mode):
        subprocess.run(['xcrun', 'simctl', 'ui', args.device, 'appearance', mode], check=True)

    def capture_themes(family):
        if args.theme_matrix:
            for system in ['light', 'dark']:
                appearance(system)
                for mode in ['dark', 'light', 'system']:
                    command('theme', f'{args.kind}-{system}-{mode}-{family}-home', mode=mode, wait=3)
            # 앱을 다시 열거나 타임라인을 갱신하지 않고 시스템 설정만 전환한다.
            appearance('light')
            command('dump', f'{args.kind}-system-transition-light-{family}-home', wait=3)
            appearance('dark')
            command('dump', f'{args.kind}-system-transition-dark-{family}-home', wait=3)
        else:
            appearance('light')
            command('dump', f'{args.kind}-light-{family}-home', wait=2)
            appearance('dark')
            command('dump', f'{args.kind}-dark-{family}-home', wait=2)

    def press_widget(name):
        widget_tree = tree.split(f"label: '{widget_name}', value: 위젯", 1)[-1]
        match = re.search(r'ScrollView, .*?\{\{([\d.]+), ([\d.]+)\}, \{([\d.]+), ([\d.]+)\}\}', widget_tree)
        screen = re.search(r'Window, .*?\{\{0.0, 0.0\}, \{([\d.]+), ([\d.]+)\}\}', tree)
        assert match and screen, '실제 홈 위젯 프레임을 확인하지 못했습니다.'
        x, y, w, h = map(float, match.groups())
        sw, sh = map(float, screen.groups())
        command('press', name, label=widget_name, duration=1.2)

    def add_widget(family='small'):
        command('press', 'edit-ready', x=.5, y=.7)
        if "label: '홈 화면 편집'" in tree:
            tap('홈 화면 편집', name='edit-home')
        if "label: '편집'" in tree or "label: 'Edit'" in tree:
            tap('편집', 'Edit', name='edit-menu')
        tap('위젯 추가', 'Add Widget', name='gallery')
        if "label: '위젯 검색'" in tree or "label: 'Search Widgets'" in tree:
            label = '위젯 검색' if "label: '위젯 검색'" in tree else 'Search Widgets'
            command('type', 'search-widget', label=label, text='날씨')
        tap(widget_name, name='widget-preview')
        for index in range(['small', 'medium', 'large'].index(family)):
            indicators = re.findall(r'PageIndicator, .*?\{\{([\d.]+), ([\d.]+)\}, \{([\d.]+), ([\d.]+)\}\}.*?value: (\d+)페이지', tree)
            screen = re.search(r'Window, .*?\{\{0.0, 0.0\}, \{([\d.]+), ([\d.]+)\}\}', tree)
            assert indicators and screen, '갤러리 크기 선택 페이지를 찾지 못했습니다.'
            px, py, pw, ph, page = map(float, indicators[-1])
            sw, sh = map(float, screen.groups())
            command('tap', f'{family}-preview-{index}', x=(px + pw / 2 + index * 18) / sw, y=(py + ph / 2) / sh, wait=2)
        tap(' 위젯 추가', '위젯 추가', 'Add Widget', name='widget-added')
        if "label: '완료'" in tree or "label: 'Done'" in tree:
            tap('완료', 'Done', name='home-ready')
        assert '날씨 새로고침' in tree, '홈 위젯이 정상 표시되지 않았습니다.'

    command('home', 'session-start')
    if args.legacy:
        families = args.families.split(',')
        for family in families:
            appearance('light')
            add_widget(family)
            capture_themes(family)
            if family != families[-1]:
                press_widget(f'{family}-remove-menu')
                tap('위젯 제거', 'Remove Widget', name='remove-widget')
                tap('제거', 'Remove', name='confirm-remove')
        subprocess.run([sys.executable, str(control), '--device', args.device,
            '--command', '{"action":"dump"}' if args.keep_session else '{"action":"finish"}', '--output', str(args.output)],
            check=True, stdout=subprocess.DEVNULL)
        appearance('light')
        print('요청한 크기·테마의 홈 위젯 촬영 완료', flush=True)
        return
    add_widget()
    appearance('light')
    command('dump', f'{args.kind}-light-small-home', wait=2)
    appearance('dark')
    command('dump', f'{args.kind}-dark-small-home', wait=2)
    press_widget('small-size-menu')
    tap('중간 크기 위젯', 'Medium Widget', name=f'{args.kind}-dark-medium-home')
    appearance('light')
    command('dump', f'{args.kind}-light-medium-home', wait=2)
    press_widget('medium-size-menu')
    tap('큰 위젯', 'Large Widget', name=f'{args.kind}-light-large-home')
    appearance('dark')
    command('dump', f'{args.kind}-dark-large-home', wait=2)
    if not args.real_app:
        assert '최저 12°' in tree and '우산' in tree and '겉옷' in tree
    subprocess.run([sys.executable, str(control), '--device', args.device,
        '--command', '{"action":"dump"}' if args.keep_session else '{"action":"finish"}', '--output', str(args.output)],
        check=True, stdout=subprocess.DEVNULL)
    appearance('light')
    print('홈 위젯 6개 촬영 완료', flush=True)


if __name__ == '__main__':
    main()
