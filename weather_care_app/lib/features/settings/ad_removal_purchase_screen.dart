import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/weather_theme.dart';

class AdRemovalPurchaseScreen extends StatefulWidget {
  final String? localizedPrice;
  final bool isOwned;
  final Future<void> Function()? onPurchase;
  final Future<void> Function()? onRestore;

  const AdRemovalPurchaseScreen({
    super.key,
    this.localizedPrice,
    this.isOwned = false,
    this.onPurchase,
    this.onRestore,
  });

  @override
  State<AdRemovalPurchaseScreen> createState() =>
      _AdRemovalPurchaseScreenState();
}

class _AdRemovalPurchaseScreenState extends State<AdRemovalPurchaseScreen> {
  bool _busy = false;

  Future<void> _run(
    Future<void> Function()? action,
    String previewMessage,
  ) async {
    if (_busy) return;
    if (action == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(previewMessage)));
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPurchaseHelp() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('ad-removal-purchase-help-dialog'),
        scrollable: true,
        title: const Text('구매·복원 안내'),
        content: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '구매 내역 복원은 이미 광고 제거를 구매한 사용자가 앱을 재설치하거나 기기를 바꾼 뒤, 추가 결제 없이 구매 권한을 다시 적용하는 기능이에요.',
            ),
            SizedBox(height: 16),
            Text(
              '복원 조건',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text('구매할 때 사용한 것과 같은 플랫폼의 같은 스토어 계정으로 로그인해야 해요.'),
            SizedBox(height: 16),
            Text(
              '플랫폼별 처리',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              '구매와 복원은 현재 기기의 플랫폼 스토어 계정을 기준으로 처리돼요. Android와 iOS의 구매 내역은 서로 복원되지 않아요.',
            ),
            SizedBox(height: 16),
            Text(
              '가격 표시',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text('실제 가격은 결제 연결 후 스토어에서 불러와 표시할 예정이에요.'),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('ad-removal-purchase-help-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final owned = widget.isOwned;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(key: ValueKey('ad-removal-back')),
        title: const Text('광고 제거'),
      ),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('ad-removal-purchase-screen'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: WeatherCareTheme.mood(
                'clear',
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          owned
                              ? Icons.verified_rounded
                              : Icons.workspace_premium_outlined,
                          color: WeatherCareTheme.primaryDeep,
                          size: 27,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          owned ? '구매 완료' : '평생 이용 · 1회 구매',
                          style: WeatherCareTheme.specialLabelStyle.copyWith(
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    owned ? '광고 없이 이용 중이에요' : '날씨만, 더 편안하게',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 24,
                          height: 1.25,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    owned
                        ? '이 플랫폼에서 날씨챙겨의 모든 광고가 제거됐어요.'
                        : '한 번 구매하면 이 플랫폼에서 날씨챙겨의 모든 광고가 사라져요.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: WeatherCareTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: WeatherCareTheme.surfaceDecoration(radius: 24),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '광고 제거 혜택',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 14),
                  _BenefitRow(
                    icon: Icons.view_day_outlined,
                    title: '화면 속 광고 제거',
                    subtitle: 'Today·Main·Week의 광고가 보이지 않아요',
                  ),
                  SizedBox(height: 14),
                  _BenefitRow(
                    icon: Icons.open_in_new_off_rounded,
                    title: '앱 실행 광고 제거',
                    subtitle: '날씨를 확인할 때 기다리지 않아도 돼요',
                  ),
                  SizedBox(height: 14),
                  _BenefitRow(
                    icon: Icons.restore_rounded,
                    title: '구매 내역 복원',
                    subtitle: '재설치·기기 변경 후 같은 플랫폼과 스토어 계정에서 복원해요',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: WeatherCareTheme.surfaceDecoration(radius: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '평생 광고 제거',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('ad-removal-purchase-help'),
                        tooltip: '구매·복원 안내',
                        visualDensity: VisualDensity.compact,
                        onPressed: _showPurchaseHelp,
                        icon: const Icon(Icons.help_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.localizedPrice ?? '스토어 가격으로 표시돼요',
                    key: const ValueKey('ad-removal-price'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: WeatherCareTheme.primaryDeep,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '매달 결제하지 않는 비소모성 상품이에요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  if (owned)
                    Container(
                      key: const ValueKey('ad-removal-owned-status'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: WeatherCareTheme.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: WeatherCareTheme.primaryDeep),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '구매가 적용되어 광고가 표시되지 않아요.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    FilledButton.icon(
                      key: const ValueKey('ad-removal-purchase'),
                      onPressed: _busy
                          ? null
                          : () => unawaited(_run(
                                widget.onPurchase,
                                '지금은 UI 미리보기예요. 결제 기능은 다음 단계에서 연결해요.',
                              )),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.workspace_premium_outlined),
                      label: const Text('광고 제거 구매하기'),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('ad-removal-restore'),
                    onPressed: _busy
                        ? null
                        : () => unawaited(_run(
                              widget.onRestore,
                              '지금은 UI 미리보기예요. 구매 내역 복원은 다음 단계에서 연결해요.',
                            )),
                    child: const Text('구매 내역 복원'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: WeatherCareTheme.primarySoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 20, color: WeatherCareTheme.primaryDeep),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: WeatherCareTheme.microTextStyle),
            ],
          ),
        ),
      ],
    );
  }
}
