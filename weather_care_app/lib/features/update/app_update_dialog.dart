import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/store_update_service.dart';
import '../../theme/weather_theme.dart';

class AppUpdateDialog extends StatefulWidget {
  final StoreUpdate update;
  final Future<bool> Function(Uri)? openStore;
  final Future<StoreUpdate?> Function() checkForUpdate;

  const AppUpdateDialog({
    super.key,
    required this.update,
    required this.checkForUpdate,
    this.openStore,
  });

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _opening = false;
  bool _checking = false;
  String? _error;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _checkForUpdate);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final update = await widget.checkForUpdate();
      if (!mounted) return;
      if (update == null) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _error = '아직 업데이트가 완료되지 않았어요.\n스토어에서 업데이트를 완료해 주세요.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '버전을 확인하지 못했어요.\n인터넷 연결을 확인하고 다시 시도해 주세요.');
    }
    if (mounted) setState(() => _checking = false);
  }

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
        setState(() => _opening = false);
        return;
      }
    } catch (_) {
      // 스토어 열기 실패 시에도 업데이트가 확인될 때까지 안내를 유지한다.
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
    return PopScope(
      canPop: false,
      child: Dialog(
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
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text('날씨챙겨를 계속 이용하려면\n최신 버전으로 업데이트해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, height: 1.6)),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('app-update-open-store'),
                  onPressed: _opening || _checking ? null : _openStore,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  child: Text(_opening ? '스토어 여는 중…' : '업데이트'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
