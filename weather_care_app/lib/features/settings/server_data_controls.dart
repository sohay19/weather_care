import 'package:flutter/material.dart';
import '../../services/server_data_access.dart';

class ServerDataControls extends StatelessWidget {
  final ServerDataAccess access;
  final Future<void> Function() onDelete;
  final Future<void> Function() onResume;
  const ServerDataControls(
      {super.key,
      required this.access,
      required this.onDelete,
      required this.onResume});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: access,
        builder: (context, _) =>
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('서버 내 나의 데이터 삭제',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              switch (access.mode) {
                ServerDataMode.active =>
                  '이 설치의 서버 등록정보·위치·알림 토큰·설정·발송 이력을 삭제할 수 있어요.',
                ServerDataMode.deleting => access.busy
                    ? '본인 확인과 삭제 결과를 확인하고 있어요. 앱을 열어 두세요.'
                    : '삭제 완료는 확인되지 않았어요. 자동 등록과 설정 전송은 중지했어요.',
                ServerDataMode.deleted =>
                  '이 설치의 서버 데이터 삭제를 완료했어요. 자동 등록과 서버 알림을 중지했어요.',
              },
              key: const ValueKey('server-data-status')),
          if (access.error != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(access.error!,
                    key: const ValueKey('server-data-error'))),
          const SizedBox(height: 8),
          if (access.busy)
            const LinearProgressIndicator()
          else if (access.mode == ServerDataMode.deleted)
            OutlinedButton(
                key: const ValueKey('server-data-resume'),
                onPressed: () => _confirmResume(context),
                child: const Text('서버 기능 다시 사용'))
          else
            OutlinedButton.icon(
                key: const ValueKey('server-data-delete'),
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline),
                label: Text(access.mode == ServerDataMode.deleting
                    ? '삭제 다시 시도'
                    : '서버 내 나의 데이터 삭제')),
        ]),
      );

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('서버 내 나의 데이터 삭제'),
              scrollable: true,
              content: const Text(
                  '이 설치의 서버 등록정보, 위치, 알림 토큰, 알림 설정과 발송 이력을 삭제해요. 다른 기기의 정보는 삭제하지 않아요.\n\n'
                  '삭제 후 서버 알림과 자동 등록을 중지해요. 기기에 저장한 지역·체크 기록은 남으며, 지역 날씨는 계속 조회할 수 있어요.\n\n'
                  '이미 전송 중인 알림은 도착할 수 있어요. 운영 로그·백업과 Firebase·광고 서비스의 데이터까지 즉시 삭제하는 기능은 아니에요.\n\n'
                  '기존 설치는 알림 수신 경로로 본인 확인이 필요할 수 있어요. 삭제 요청 중에는 앱을 열어 두세요.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                FilledButton(
                    key: const ValueKey('server-data-confirm-delete'),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('삭제하기'))
              ],
            ));
    if (confirmed == true) await onDelete();
  }

  Future<void> _confirmResume(BuildContext context) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('서버 기능 다시 사용'),
              scrollable: true,
              content: const Text(
                  '새 설치 식별자로 서버 등록을 시작해요. 선택 지역과 설정을 보내며, GPS 정밀 위치가 확인되면 좌표도 전송해요. 기기 알림이 허용되어 있으면 알림 토큰도 등록해요.\n\n날씨 알림 스위치는 자동으로 켜지지 않아요.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('다시 사용하기'))
              ],
            ));
    if (confirmed == true) await onResume();
  }
}
