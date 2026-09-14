import 'package:flutter/material.dart';
import '../../services/analytics_consent.dart';

class AnalyticsConsentControl extends StatelessWidget {
  const AnalyticsConsentControl(
      {super.key, this.controller, this.onDeleteCollectedData});
  final AnalyticsConsent? controller;
  final Future<void> Function(String appInstanceId)? onDeleteCollectedData;

  @override
  Widget build(BuildContext context) {
    final consent = controller ?? AnalyticsConsent.instance;
    return ListenableBuilder(
        listenable: consent,
        builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('앱 이용 통계 수집 (선택)'),
                  subtitle: const Text(
                      '앱 개선을 위해 Firebase Analytics로 앱 이용 기록과 기기·앱 정보를 수집해요. 동의하지 않아도 날씨·알림 기능을 이용할 수 있어요. 끄면 이후 분석 수집을 중단해요. 이미 전송된 자료의 삭제와는 달라요.'),
                  value: consent.enabled,
                  onChanged: !consent.ready || consent.busy
                      ? null
                      : (value) async {
                          if (value) {
                            final accepted = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                      title: const Text('앱 이용 통계 수집에 동의할까요?'),
                                      content: const Text(
                                          '동의하면 앱 이용 이벤트, 앱 인스턴스 식별자, 대략적인 지역과 기기·운영체제·앱 정보가 암호화된 통신으로 Google LLC(googlekrsupport@google.com)의 전 세계 시설에 전송돼요. 앱 개선을 위해 사용자·이벤트 자료를 2개월 보관하도록 설정했으며, 표준 집계 보고서는 이 기간의 적용 대상이 아니에요.\n\n'
                                          '이 국외 이전과 이용 통계 수집은 선택 사항이에요. 동의하지 않아도 날씨·알림 기능을 이용할 수 있고 설정에서 언제든 철회하거나 전송된 자료의 삭제를 요청할 수 있어요. 광고 개인화 동의와는 별개예요.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('동의하지 않음')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('동의')),
                                      ],
                                    ));
                            if (accepted != true) return;
                          }
                          await consent.change(value);
                        },
                ),
                if (consent.error != null) ...[
                  Text(consent.error!),
                  TextButton(
                      onPressed: consent.busy
                          ? null
                          : () => consent.ready
                              ? consent.change(consent.requested)
                              : consent.initialize(),
                      child: const Text('다시 시도')),
                ],
                if (onDeleteCollectedData != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('analytics-data-delete'),
                    onPressed: !consent.ready || consent.busy
                        ? null
                        : () => _confirmDeletion(context, consent),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('전송된 이용 통계 삭제 요청'),
                  ),
                ],
                if (consent.deletionStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(consent.deletionStatus!,
                        key: const ValueKey('analytics-deletion-status')),
                  ),
                if (consent.deletionError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(consent.deletionError!,
                        key: const ValueKey('analytics-deletion-error')),
                  ),
              ],
            ));
  }

  Future<void> _confirmDeletion(
      BuildContext context, AnalyticsConsent consent) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('전송된 이용 통계를 삭제할까요?'),
              scrollable: true,
              content: const Text(
                  '이용 통계 수집을 중단하고, 이 기기의 Firebase 앱 인스턴스 ID와 연결된 과거 자료의 삭제를 Google Analytics에 요청해요. 삭제 요청 접수와 실제 삭제 완료는 달라요.\n\n'
                  '요청이 접수되면 기기에 남은 분석 데이터와 앱 인스턴스 ID도 초기화해요. 서버의 날씨·알림 데이터와 광고 서비스 자료는 이 요청으로 삭제되지 않아요.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                FilledButton(
                    key: const ValueKey('analytics-data-confirm-delete'),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('수집 중단 및 삭제 요청')),
              ],
            ));
    if (confirmed == true) {
      await consent.deleteCollectedData(onDeleteCollectedData!);
    }
  }
}
