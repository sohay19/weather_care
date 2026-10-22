"""iOS XCTest용 로컬 응답 서버. 실제 서버·FCM·기상 API를 호출하지 않는다."""

import json
import os
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


class Handler(BaseHTTPRequestHandler):
    status = 200
    delay = 0
    requests = []
    simulation = {}

    def log_message(self, *_):
        pass

    def reply(self, status, body):
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        path = urlsplit(self.path)
        if path.path == "/control":
            values = parse_qs(path.query)
            Handler.status = int(values.get("status", [200])[0])
            Handler.delay = float(values.get("delay", [0])[0])
            Handler.requests = []
            return self.reply(200, {})
        if path.path == "/state":
            return self.reply(200, {"requests": Handler.requests, "simulation": Handler.simulation})
        if path.path == "/prepare-simulation":
            simulator = os.environ.get("WEATHER_CARE_IOS_SIMULATOR")
            if not simulator:
                return self.reply(409, {"error": "전용 시뮬레이터 환경 변수 설정 필요"})
            result = subprocess.run(["xcrun", "simctl", "location", simulator,
                "set", "37.5665,126.978"], capture_output=True, timeout=15)
            Handler.simulation = {"prepared": result.returncode == 0, "origin": "서울"}
            return self.reply(200 if result.returncode == 0 else 500, Handler.simulation)
        if path.path == "/simulate":
            simulator = os.environ.get("WEATHER_CARE_IOS_SIMULATOR")
            if not simulator:
                return self.reply(409, {"error": "전용 시뮬레이터 환경 변수 설정 필요"})
            # 이 작업에서 만든 전용 시뮬레이터에만 합성 위치를 주입한다.
            def move():
                result = subprocess.run(["xcrun", "simctl", "location", simulator,
                    "start", "--speed=1000", "--interval=5",
                    "37.5665,126.978", "35.1796,129.0756"],
                    capture_output=True, timeout=15)
                Handler.simulation["routeStarted"] = result.returncode == 0
                Handler.simulation["startedAt"] = time.time()
            threading.Timer(1, move).start()
            return self.reply(200, {})
        if path.path == "/api/v1/weather/widget":
            values = parse_qs(path.query)
            grid = f"{values.get('nx', ['60'])[0]}:{values.get('ny', ['127'])[0]}"
            Handler.requests.append({"method": "GET", "path": self.path})
            return self.reply(200, {"schemaVersion": 3, "region": "검증 지역",
                "locationKey": grid, "refreshTime": "시험 자료", "currentTemperature": "19°",
                "condition": "clear", "minimumTemperature": "13°", "maximumTemperature": "22°",
                "apparentTemperature": "18°"})
        self.reply(404, {})

    def do_PUT(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))))
        Handler.requests.append({"method": "PUT", "path": self.path, "body": body, "receivedAt": time.time(),
            "authorized": self.headers.get("Authorization") == "Bearer " + "a" * 64,
            "testKeyAbsent": self.headers.get("X-Weather-Care-Test-Key") is None,
            "contentType": self.headers.get("Content-Type")})
        status, delay = Handler.status, Handler.delay
        time.sleep(delay)
        self.reply(status, {})


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 18787), Handler).serve_forever()
