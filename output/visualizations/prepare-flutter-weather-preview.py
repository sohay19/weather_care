from pathlib import Path
import re
import shutil

root=Path(__file__).resolve().parents[2]
source=root/'weather_care_app'
target=root/'.git/weather-preview-app'
base=source/'lib'
queue=[base/'features/home/tabs/main_tab.dart',base/'features/home/tabs/today_tab.dart']
seen=set()
while queue:
    p=queue.pop().resolve()
    if p in seen: continue
    seen.add(p)
    for name in re.findall(r"(?:import|export)\s+'([^']+)'",p.read_text(encoding='utf-8')):
        if name.startswith('package:weather_care/'):
            queue.append(base/name[len('package:weather_care/'):])
        elif not name.startswith(('dart:','package:')):
            queue.append(p.parent/name)
for p in seen:
    dest=target/'lib'/p.relative_to(base.resolve())
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(p,dest)
shutil.copytree(source/'assets/fonts',target/'assets/fonts',dirs_exist_ok=True)
shutil.copytree(source/'assets/icons',target/'assets/icons',dirs_exist_ok=True)
fonts=source.joinpath('pubspec.yaml').read_text(encoding='utf-8').split('  fonts:',1)[1]
target.joinpath('pubspec.yaml').write_text('''name: weather_care
publish_to: none
environment:
  sdk: ">=3.5.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.5.5
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
  assets:
    - assets/icons/
  fonts:'''+fonts,encoding='utf-8')

main=target/'lib/features/home/tabs/main_tab.dart'
s=main.read_text(encoding='utf-8')
s=s.replace("import 'package:flutter/material.dart';","import 'package:flutter/material.dart';\nimport '../widgets/nearby_observation_preview.dart';",1)
anchor="""        const SizedBox(height: 13),
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 10),"""
assert s.count(anchor)==1
s=s.replace(anchor,"""        const SizedBox(height: 10),
        NearbyObservationPreview(distanceKm: PreviewSource.distanceKm),
"""+anchor,1)
main.write_text(s,encoding='utf-8')

card=target/'lib/features/home/widgets/weather_card.dart'
s=card.read_text(encoding='utf-8').replace("import 'package:flutter/material.dart';","import 'package:flutter/material.dart';\nimport 'nearby_observation_preview.dart';",1)
anchor="""          const SizedBox(height: 18),
          Container("""
assert s.count(anchor)==1
s=s.replace(anchor,"""          const SizedBox(height: 10),
          NearbyObservationPreview(distanceKm: PreviewSource.distanceKm),
"""+anchor,1)
card.write_text(s,encoding='utf-8')
print(f'Copied {len(seen)} original Dart files and original fonts/icons to isolated preview; production app unchanged.')
