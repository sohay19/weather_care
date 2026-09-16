import 'package:flutter/material.dart';
import '../../services/ads_consent.dart';

class AdsPrivacyControl extends StatelessWidget {
  const AdsPrivacyControl({super.key, this.controller});
  final AdsConsent? controller;
  @override
  Widget build(BuildContext context) {
    final consent = controller ?? AdsConsent.instance;
    return ListenableBuilder(
        listenable: consent,
        builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (consent.privacyOptionsRequired)
                  ListTile(
                      title: const Text('광고 개인정보 선택'),
                      subtitle: const Text(
                          '광고 관련 선택을 확인하거나 변경해요.\n앱 이용 통계 동의와는 별개예요.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: consent.busy ? null : consent.openPrivacyOptions),
                if (consent.error != null) ...[
                  Text(consent.error!),
                  TextButton(
                      onPressed: consent.busy ? null : consent.refresh,
                      child: const Text('광고 개인정보 선택 다시 확인')),
                ],
              ],
            ));
  }
}
