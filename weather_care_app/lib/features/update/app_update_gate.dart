import 'package:flutter/material.dart';

import '../../services/store_update_service.dart';
import '../../services/theme_mode_settings.dart';
import '../../theme/weather_theme.dart';
import 'app_update_dialog.dart';

/// 앱을 새로 실행할 때 한 번 확인하고 홈의 권한 안내·광고보다 먼저 표시한다.
class AppUpdateGate extends StatefulWidget {
  final Widget child;
  final StoreUpdateService service;
  final VoidCallback? onComplete;
  final Future<bool> Function(Uri)? openStore;
  final bool skipCheck;

  const AppUpdateGate({
    super.key,
    required this.child,
    this.service = const StoreUpdateService(),
    this.onComplete,
    this.openStore,
    this.skipCheck = false,
  });

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final update =
        widget.skipCheck ? null : await widget.service.checkForUpdate();
    if (!mounted) return;
    if (update != null) {
      await showDialog<void>(
        context: _navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (_) =>
            AppUpdateDialog(update: update, openStore: widget.openStore),
      );
    }
    if (!mounted) return;
    setState(() => _complete = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_complete) return widget.child;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: WeatherCareTheme.light(),
      darkTheme: WeatherCareTheme.dark(),
      themeMode: ThemeModeSettings.instance.value,
      builder: WeatherCareTheme.textScaleBuilder,
      home: Scaffold(
        body: Center(
          child: Builder(builder: (context) {
            final colors = WeatherCareTheme.of(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wb_sunny_rounded,
                    size: 56, color: colors.primaryDeep),
                const SizedBox(height: 18),
                const Text('날씨챙겨',
                    style:
                        TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text('새 버전을 확인하고 있어요',
                    style: TextStyle(color: colors.textSecondary)),
              ],
            );
          }),
        ),
      ),
    );
  }
}
