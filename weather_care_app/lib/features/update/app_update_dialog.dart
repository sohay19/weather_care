import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/store_update_service.dart';
import '../../theme/weather_theme.dart';

class AppUpdateDialog extends StatefulWidget {
  final StoreUpdate update;
  final Future<bool> Function(Uri)? openStore;

  const AppUpdateDialog({super.key, required this.update, this.openStore});

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _opening = false;
  String? _error;

  Future<void> _openStore() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final opened = await (widget.openStore ??
          (url) => launchUrl(url, mode: LaunchMode.externalApplication))(
        widget.update.storeUrl,
      );
      if (!mounted) return;
      if (opened) {
        Navigator.of(context).pop();
        return;
      }
    } catch (_) {
      // 열기 실패 시 안내를 유지해 다시 시도하거나 나중에 진행할 수 있다.
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      _error = '스토어를 열지 못했어요. 잠시 후 다시 시도해주세요.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = WeatherCareTheme.of(context);
    return Dialog(
      key: const ValueKey('app-update-dialog'),
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(Icons.system_update_rounded,
                      size: 34, color: colors.primaryDeep),
                ),
              ),
              const SizedBox(height: 22),
              const Text('새로운 버전이 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('더 편리해진 날씨챙겨를 만나보세요.\n아래 버튼을 눌러 바로 이동할 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, height: 1.6)),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('app-update-open-store'),
                onPressed: _opening ? null : _openStore,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                child: Text(_opening ? '스토어 여는 중…' : '업데이트'),
              ),
              const SizedBox(height: 6),
              TextButton(
                key: const ValueKey('app-update-later'),
                onPressed: () => Navigator.of(context).pop(),
                child:
                    Text('나중에', style: TextStyle(color: colors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
