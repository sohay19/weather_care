import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/background_location_service.dart';

class BackgroundLocationControl extends StatelessWidget {
  final BackgroundLocationService service;
  final bool enabled;
  final bool available;
  final Future<void> Function(bool) onChanged;
  final Future<void> Function() onPermission;

  const BackgroundLocationControl(
      {super.key,
      required this.service,
      required this.enabled,
      required this.available,
      required this.onChanged,
      required this.onPermission});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: service,
        builder: (context, _) => Card(
            child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile.adaptive(
              key: const ValueKey('background-location-switch'),
              title: const Text('백그라운드 위치 갱신'),
              subtitle: const Text(
                  '앱을 사용하지 않을 때도 이동을 감지하면 현재 위치·날씨 알림 지역·홈 위젯 날씨를 갱신해요.'),
              value: enabled,
              onChanged: available || enabled
                  ? (value) async {
                      if (value) {
                        final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: const Text('백그라운드 위치 사용 안내'),
                                  content: const SingleChildScrollView(
                                      child: Text(
                                          '앱을 사용하지 않을 때도 이동을 감지해 새 지역의 날씨·낙뢰 알림과 홈 위젯 위치·날씨를 갱신하도록 위치를 서버에 보내요. '
                                          '최신 위치만 사용하며 이동 경로는 저장하지 않아요.\n\n'
                                          '기기 위치 권한을 ‘항상 허용’으로 설정해주세요. Android는 앱 설정의 위치 권한에서 변경할 수 있어요. 감시 중에는 실행 알림이 표시되고 GPS 사용으로 배터리를 더 사용할 수 있어요.\n\n'
                                          'GPS 모드와 전체 알림이 켜져 있을 때 동작해요. 기능을 끄거나 직접 지역을 선택하면 감시를 중지해요. '
                                          '기기의 절전 상태와 강제 종료에 따라 갱신이 지연되거나 멈출 수 있어요.')),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('취소')),
                                    FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('동의하고 설정')),
                                  ],
                                ));
                        if (confirmed != true) return;
                      }
                      await onChanged(value);
                      if (value) await onPermission();
                    }
                  : null,
            ),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  !available
                      ? 'GPS 모드와 전체 알림, 서버 데이터 사용을 켜면 사용할 수 있어요.'
                      : !enabled
                          ? '현재 꺼져 있어요.'
                          : switch (service.status) {
                              'active' => '이동 감지 중 · 기기 상황에 따라 갱신이 늦어질 수 있어요.',
                              'permissionRequired' =>
                                '위치 권한을 ‘항상 허용’으로 설정해주세요.',
                              'locationDisabled' => '기기의 위치 기능을 켜주세요.',
                              'unsupported' => '이 기기에서는 백그라운드 이동 감지를 지원하지 않아요.',
                              'error' =>
                                '이동 감지를 시작하지 못했어요. 연결과 권한을 확인하고 다시 시도해주세요.',
                              _ => '이동 감지 설정을 확인하고 있어요.',
                            },
                )),
            if (enabled && available)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton(
                    onPressed: onPermission,
                    child: const Text('위치 권한 설정·다시 확인')),
              ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              ListTile(
                key:
                    const ValueKey('background-location-notification-settings'),
                title: const Text('실행 알림 표시 설정'),
                subtitle: const Text(
                    '시스템 설정에서 이 알림만 숨길 수 있어요. 백그라운드 위치 갱신과 날씨 알림은 유지돼요.'),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () async {
                  final opened = await service.openNotificationSettings();
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('실행 알림 설정을 열지 못했어요. 기기의 앱 알림 설정에서 변경해주세요.')));
                  }
                },
              ),
          ]),
        )),
      );
}
