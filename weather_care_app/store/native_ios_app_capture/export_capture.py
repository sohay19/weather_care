"""실제 앱 전체 캡처에서 시스템 바만 제외하고 원본 해시를 기록한다."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--raw', type=Path, required=True)
    parser.add_argument('--screens', help='쉼표로 구분한 촬영 이름. 생략하면 전체 내보내기')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / 'screenshots/source-ios-20261023/phone'
    output.mkdir(parents=True, exist_ok=True)
    manifest = output / 'capture-manifest.json'
    records = json.loads(manifest.read_text())['files'] if manifest.exists() else []
    names = args.screens.split(',') if args.screens else [
        'main', 'timeline', 'dark-main', 'advanced-values', 'week', 'notification-settings']
    for name in names:
        source = args.raw / f'{"week-detail" if name == "week" else name}.png'
        with Image.open(source) as image:
            image.load()
            assert image.size == (1290, 2796), source
            # 실제 상태바 59pt·홈 표시 영역 34pt. 앱 탭 메뉴를 보존한다.
            box = (0, 59 * 3, image.width, image.height - 34 * 3)
            crop = image.crop(box)
            target = output / f'{name}.png'
            crop.save(target, optimize=True)
            with Image.open(target) as saved:
                assert saved.tobytes() == crop.tobytes()
            records = [record for record in records if record['name'] != name]
            records.append({'name': name, 'device': args.device, 'source': source.name,
                'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'source_size': list(image.size), 'crop': list(box),
                'path': str(target.relative_to(root)), 'size': list(crop.size),
                'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    manifest.write_text(json.dumps({
        '기준일': '2026-10-23', '방식': '실제 iPhone 앱 전체 화면·시스템 바만 제외·iPad 규격에도 같은 원본 사용',
        'files': records}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'실제 앱 전체 촬영 {len(records)}개 내보내기 완료')


if __name__ == '__main__':
    main()
