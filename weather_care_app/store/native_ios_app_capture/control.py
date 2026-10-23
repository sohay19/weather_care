"""독립 XCTest에 실제 앱 촬영 명령을 전달한다."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--command', required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    container = subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.device,
        'com.codesoha.weathercare.appcapture.appcapturetests.xctrunner', 'data'], text=True).strip()
    folder = Path(container) / 'Documents/app-capture'
    deadline = time.time() + 55
    while not (folder / 'ready').exists():
        if time.time() > deadline:
            raise TimeoutError('촬영 XCTest 초기 화면이 준비되지 않았습니다.')
        time.sleep(.25)
    command = json.loads(args.command)
    command['id'] = time.time_ns() // 1_000_000
    target = folder / 'command.json'
    temporary = target.with_suffix('.tmp')
    temporary.write_text(json.dumps(command, ensure_ascii=False), encoding='utf-8')
    temporary.replace(target)
    deadline = time.time() + 55
    while command['action'] != 'finish':
        done = folder / 'done'
        if done.exists() and done.read_text() == str(command['id']):
            break
        if time.time() > deadline:
            raise TimeoutError('촬영 명령 응답이 없습니다.')
        time.sleep(.25)
    error = folder / 'error.txt'
    if error.exists() and error.stat().st_mtime * 1000 >= command['id']:
        raise RuntimeError(error.read_text(encoding='utf-8'))
    if command.get('name'):
        shutil.copy2(folder / 'state.txt', folder / f'{command["name"]}.txt')
    with (folder / 'commands.jsonl').open('a', encoding='utf-8') as log:
        log.write(json.dumps(command, ensure_ascii=False) + '\n')
    if args.output:
        args.output.mkdir(parents=True, exist_ok=True)
        for source in folder.iterdir():
            if source.is_file() and source.suffix in ['.png', '.txt', '.jsonl']:
                shutil.copy2(source, args.output / source.name)
    print(folder)
    state = (folder / 'state.txt').read_text(encoding='utf-8')
    print(state.split('\nSYSTEM\n')[1 if command.get('system') else 0])


if __name__ == '__main__':
    main()
