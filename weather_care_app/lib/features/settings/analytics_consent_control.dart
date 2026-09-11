import 'package:flutter/material.dart';
import '../../services/analytics_consent.dart';

class AnalyticsConsentControl extends StatelessWidget {
  const AnalyticsConsentControl({super.key, this.controller});
  final AnalyticsConsent? controller;

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
                                          '동의하면 이용 통계 수집을 시작해요. 광고 개인화 동의와는 별개이며 설정에서 언제든 철회할 수 있어요.'),
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
              ],
            ));
  }
}
