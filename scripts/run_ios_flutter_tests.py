"""기존 Flutter 테스트를 파일별 격리를 유지하며 iOS 위젯 플랫폼으로 실행한다."""

import argparse
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter", default="flutter", help="사용할 Flutter 실행 파일")
    args = parser.parse_args()
    app = Path(__file__).resolve().parents[1] / "weather_care_app"
    output = app / "build" / "ios-parity-suite"
    output.mkdir(parents=True, exist_ok=True)
    binding = """
class IOSBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  Future<void> runTest(Future<void> Function() testBody, VoidCallback invariantTester,
      {String description = ''}) {
    return super.runTest(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try { await testBody(); } finally { debugDefaultTargetPlatformOverride = null; }
    }, invariantTester, description: description);
  }
}
void main() { IOSBinding(); suite.main(); }
"""
    for stale in output.glob("*_test.dart"):
        stale.unlink()
    for source in sorted((app / "test").glob("*_test.dart")):
        imports = "import 'package:flutter/foundation.dart';\n"
        imports += "import 'package:flutter_test/flutter_test.dart';\n"
        imports += f"import '../../test/{source.name}' as suite;\n"
        (output / source.name).write_text(imports + binding, encoding="utf-8")
    return subprocess.run([args.flutter, "test", str(output), "--concurrency=4",
        "--no-pub", "--reporter", "expanded"], cwd=app).returncode


if __name__ == "__main__":
    raise SystemExit(main())
