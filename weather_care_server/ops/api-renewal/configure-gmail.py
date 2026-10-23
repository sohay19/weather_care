#!/usr/bin/env python3
"""터미널에서 Gmail 앱 비밀번호를 비표시 입력하고 발송 설정을 검증한다."""
import getpass
import grp
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ENV_PATH = Path('/etc/weather-care/api-renewal.env')
NODE = '/usr/local/bin/node'
PROGRAM = '/opt/weather-care-api-renewal/reminder.cjs'


def node_check(option):
    return subprocess.run([
        '/usr/sbin/runuser', '-u', 'weather-care', '--', NODE,
        f'--env-file={ENV_PATH}', PROGRAM, option,
    ], check=False).returncode == 0


def main():
    if os.geteuid() != 0 or not sys.stdin.isatty():
        print('sudo로 대화형 SSH 터미널에서 실행해 주세요.')
        return 1
    print('발신·수신 계정: sy40222@gmail.com / Gmail SMTP 465(TLS)')
    print('Google 계정의 앱 비밀번호 16자리를 입력하세요. 입력값은 표시하지 않습니다.')
    password = getpass.getpass('Gmail 앱 비밀번호: ').replace(' ', '')
    if not re.fullmatch(r'[A-Za-z0-9]{16}', password):
        print('앱 비밀번호 형식을 확인해 주세요. 일반 Google 로그인 비밀번호를 입력하지 마세요.')
        return 1
    lines = [
        'API_RENEWAL_CONFIG_PATH=/etc/weather-care/api-renewals.json',
        'API_RENEWAL_STATE_PATH=/var/lib/weather-care-api-renewal/state.sqlite',
        'API_RENEWAL_SMTP_HOST=smtp.gmail.com', 'API_RENEWAL_SMTP_PORT=465',
        'API_RENEWAL_SMTP_USER=sy40222@gmail.com',
        'API_RENEWAL_SMTP_FROM=sy40222@gmail.com',
        f'API_RENEWAL_SMTP_PASSWORD={password}',
        'NODE_PATH=/opt/weather-care/weather_care_server/node_modules', '',
    ]
    previous = ENV_PATH.read_bytes() if ENV_PATH.exists() else None
    with tempfile.NamedTemporaryFile(dir=ENV_PATH.parent, mode='w', encoding='utf-8', delete=False) as file:
        temporary = Path(file.name)
        os.fchmod(file.fileno(), 0o640)
        os.fchown(file.fileno(), 0, grp.getgrnam('weather-care').gr_gid)
        file.write('\n'.join(lines))
    os.replace(temporary, ENV_PATH)
    if not node_check('--verify-smtp') or not node_check('--test-email'):
        if previous is not None:
            ENV_PATH.write_bytes(previous)
        else:
            ENV_PATH.unlink()
        print('인증 또는 설정 확인 메일 접수에 실패했습니다. 기존 설정을 복원했습니다. 오류 코드와 Google 계정 설정을 확인해 주세요.')
        return 1
    subprocess.run(['systemctl', 'start', 'weather-care-api-renewal.service'], check=True)
    subprocess.run(['systemctl', 'enable', '--now', 'weather-care-api-renewal.timer'], check=True)
    print('설정 확인 메일이 메일 서버에 접수됐고 매일 오전 9시(한국시간) 예약이 활성화됐습니다.')
    print('sy40222@gmail.com의 받은편지함·스팸함에서 확인해 주세요.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (KeyboardInterrupt, EOFError):
        print('\n설정을 중단했습니다.')
        raise SystemExit(1)
