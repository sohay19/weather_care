"""원본 홈 화면에서 실제 위젯 영역만 잘라 보관한다. UI 픽셀은 재색칠하지 않는다."""
import argparse
import hashlib
import json
from pathlib import Path
import re

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kind', choices=['phone', 'tablet'], required=True)
    parser.add_argument('--raw', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--widget-name', default='날씨챙겨 촬영')
    args = parser.parse_args()
    app = Path(__file__).resolve().parents[2]
    output = args.output or app / 'store/screenshots/native-ios-20261022' / args.kind
    output.mkdir(parents=True, exist_ok=True)
    records = []
    scale = 3 if args.kind == 'phone' else 2
    for theme in ['light', 'dark']:
        for family in ['small', 'medium', 'large']:
            name = f'{args.kind}-{theme}-{family}-home'
            source = args.raw / f'{name}.png'
            tree = args.raw / f'{name}.txt'
            if tree.exists():
                text = tree.read_text(encoding='utf-8')
                widget_tree = text.split(f"label: '{args.widget_name}', value: 위젯", 1)[-1]
                match = re.search(r'ScrollView, .*?\{\{([\d.]+), ([\d.]+)\}, \{([\d.]+), ([\d.]+)\}\}', widget_tree)
                assert match, name
                x, y, w, h = map(float, match.groups())
            else:
                # 첫 iPad 촬영 당시 읽은 XCTest의 실제 프레임.
                assert args.kind == 'tablet'
                x, y = 142, 54
                w, h = {'small': (160, 160), 'medium': (356, 160), 'large': (356, 356)}[family]
            if family == 'small':
                assert w < 220 and abs(w - h) < 2, (name, w, h)
            elif family == 'medium':
                assert w > 300 and w / h > 1.8, (name, w, h)
            else:
                assert w > 300 and .85 < w / h < 1.15, (name, w, h)
            box = [round(x * scale), round(y * scale), round((x + w) * scale), round((y + h) * scale)]
            with Image.open(source) as full:
                full.load()
                bitmap = full.crop(box).convert('RGBA')
            original = bitmap.copy()
            # 실제 위젯 바탕색이 시작하는 각 행의 경계 밖 홈 배경만 제거한다.
            surface = (37, 55, 71) if theme == 'dark' else (234, 240, 245)
            pixels = bitmap.load()
            for y in range(bitmap.height):
                matching = [x for x in range(bitmap.width)
                    if sum(abs(a - b) for a, b in zip(pixels[x, y][:3], surface)) <= 6]
                assert matching, (name, y)
                left, right = matching[0], matching[-1]
                for x in range(left):
                    pixels[x, y] = (0, 0, 0, 0)
                for x in range(right + 1, bitmap.width):
                    pixels[x, y] = (0, 0, 0, 0)
            assert bitmap.getpixel((bitmap.width // 2, bitmap.height // 2))[3] == 255
            assert bitmap.getchannel('A').histogram()[255] / (bitmap.width * bitmap.height) > .90
            before_bytes, after_bytes = original.tobytes(), bitmap.tobytes()
            for index in range(0, len(after_bytes), 4):
                assert after_bytes[index + 3] == 0 or before_bytes[index:index + 4] == after_bytes[index:index + 4]
            destination = output / f'{theme}-{family}.png'
            bitmap.save(destination, optimize=True)
            records.append({'device': args.kind, 'theme': theme, 'family': family,
                'source': source.name, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'crop': box, 'logical_size': [w, h], 'scale': scale,
                'path': f'{args.kind}/{destination.name}', 'size': list(bitmap.size),
                'sha256': hashlib.sha256(destination.read_bytes()).hexdigest()})
    (output / 'capture-manifest.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{args.kind}: 실제 위젯 원본 6개 내보내기·내부 픽셀 보존 검사 완료')


if __name__ == '__main__':
    main()
