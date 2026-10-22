"""실행 중인 촬영 XCTest에 명령을 전달하고 접근성 트리·원본 PNG를 읽는다."""
import argparse
import json
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--command', help='촬영 명령 JSON')
    parser.add_argument('--output', type=Path, help='현재 상태 파일을 보관할 폴더')
    args = parser.parse_args()
    container = subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.device,
        'com.codesoha.weathercare.capture.capturetests.xctrunner', 'data'], text=True).strip()
    folder = Path(container) / 'Documents/widget-capture'
    if args.command:
        ready_deadline = time.time() + 45
        while not (folder / 'ready').exists():
            if time.time() > ready_deadline:
                raise TimeoutError('촬영 XCTest 초기 화면이 아직 준비되지 않았습니다.')
            time.sleep(.25)
        command = json.loads(args.command)
        command['id'] = time.time_ns() // 1000000
        target = folder / 'command.json'
        temporary = target.with_suffix('.tmp')
        temporary.write_text(json.dumps(command, ensure_ascii=False), encoding='utf-8')
        temporary.replace(target)
        deadline = time.time() + 45
        while time.time() < deadline:
            if command['action'] == 'finish':
                break
            done = folder / 'done'
            if done.exists() and done.read_text() == str(command['id']):
                break
            time.sleep(.25)
        else:
            raise TimeoutError('XCTest 명령 응답이 오지 않았습니다.')
        error = folder / 'error.txt'
        if error.exists() and error.stat().st_mtime * 1000 >= command['id']:
            raise RuntimeError(error.read_text(encoding='utf-8'))
        if command.get('name') and (folder / 'state.txt').exists():
            (folder / f'{command["name"]}.txt').write_text(
                (folder / 'state.txt').read_text(encoding='utf-8'), encoding='utf-8')
        with (folder / 'commands.jsonl').open('a', encoding='utf-8') as log:
            log.write(json.dumps(command, ensure_ascii=False) + '\n')
    if args.output:
        import shutil
        args.output.mkdir(parents=True, exist_ok=True)
        for source in folder.iterdir():
            if source.is_file() and source.suffix in ['.png', '.txt', '.json']:
                shutil.copy2(source, args.output / source.name)
    print(folder)
    if (folder / 'state.txt').exists():
        print((folder / 'state.txt').read_text(encoding='utf-8'))


if __name__ == '__main__':
    main()
