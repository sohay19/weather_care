"""실제 SpringBoard 위젯 캡처의 테마 색상과 소·중·대 프레임을 검사한다."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

from PIL import Image


PALETTES = {
    'light': {'surface': 'EAF0F5', 'panel': 'FFFFFF', 'ink': '29343D',
              'secondary': '63707A', 'refresh': '3E5F7C', 'divider': 'CEDAE4'},
    'dark': {'surface': '253747', 'panel': '1D2731', 'ink': 'EDF2F6',
             'secondary': 'AAB7C3', 'refresh': '9DBDD8', 'divider': '40566A'},
}
REFRESH_INK = {'light': (255, 255, 255), 'dark': (23, 39, 54)}


def verify(raw, output):
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for family in ['small', 'medium', 'large']:
        cases = [(f'phone-{system}-{mode}-{family}-home',
                  system if mode == 'system' else mode)
                 for system in ['light', 'dark'] for mode in ['dark', 'light', 'system']]
        cases += [(f'phone-system-transition-{mode}-{family}-home', mode)
                  for mode in ['light', 'dark']]
        for name, mode in cases:
            source = raw / f'{name}.png'
            tree = (raw / f'{name}.txt').read_text(encoding='utf-8')
            widget_tree = tree.split("label: '날씨챙겨 촬영', value: 위젯", 1)
            assert len(widget_tree) == 2, f'{name}: 실제 홈 위젯 없음'
            frame = re.search(r'ScrollView, .*?\{\{([\d.]+), ([\d.]+)\}, '
                              r'\{([\d.]+), ([\d.]+)\}\}', widget_tree[1])
            assert frame, f'{name}: 위젯 프레임 없음'
            x, y, w, h = map(float, frame.groups())
            assert ((w < 220 and abs(w - h) < 2) if family == 'small' else
                    (w > 300 and w / h > 1.8) if family == 'medium' else
                    (w > 300 and .85 < w / h < 1.15)), (name, w, h)
            with Image.open(source) as full:
                screen = re.search(r'Window, .*?\{\{0.0, 0.0\}, '
                                   r'\{([\d.]+), ([\d.]+)\}\}', tree)
                assert screen
                scale = full.width / float(screen.group(1))
                box = tuple(round(v * scale) for v in (x, y, x + w, y + h))
                bitmap = full.crop(box).convert('RGB')
            colors = Counter(bitmap.getdata())
            counts = {}
            palette = PALETTES[mode]
            for token, hex_value in palette.items():
                if token == 'divider' and family == 'small':
                    continue
                rgb = tuple(bytes.fromhex(hex_value))
                # 색 관리·안티앨리어싱의 채널별 반올림 오차만 허용한다.
                count = sum(n for pixel, n in colors.items()
                            if max(abs(a - b) for a, b in zip(pixel, rgb)) <= 2)
                minimum = bitmap.width * bitmap.height * .1 if token == 'surface' else 15
                assert count >= minimum, f'{name}: {token} {hex_value} 픽셀 {count} 부족'
                counts[token] = count
            opposite = PALETTES['light' if mode == 'dark' else 'dark']
            wrong_surface = colors[tuple(bytes.fromhex(opposite['surface']))]
            assert wrong_surface < 10, f'{name}: 반대 모드 배경 {wrong_surface}픽셀 혼입'
            button = re.search(r'Button, .*?\{\{([\d.]+), ([\d.]+)\}, '
                               r'\{([\d.]+), ([\d.]+)\}\}, label: \'날씨 새로고침\'',
                               widget_tree[1])
            assert button, f'{name}: 새로고침 버튼 없음'
            bx, by, bw, bh = map(float, button.groups())
            button_image = bitmap.crop(tuple(round(v * scale) for v in
                                             (bx - x, by - y, bx - x + bw, by - y + bh)))
            refresh_ink = sum(1 for pixel in button_image.getdata()
                              if max(abs(a - b) for a, b in zip(pixel, REFRESH_INK[mode])) <= 2)
            assert refresh_ink >= 8, f'{name}: 새로고침 아이콘 색상 누락'
            counts['refresh_ink'] = refresh_ink
            bitmap.save(output / f'{name}.png')
            records.append({'name': name, 'mode': mode, 'frame': [x, y, w, h],
                            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                            'pixels': counts})
    (output / 'verification.json').write_text(
        json.dumps(records, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'실제 홈 위젯 {len(records)}개 색상·크기·시스템 전환 검사 통과')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--raw', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    verify(args.raw, args.output)
