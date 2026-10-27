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

  const AppUpdateGate({
    super.key,
    required this.child,
    this.service = const StoreUpdateService(),
    this.onComplete,
    this.openStore,
  });

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _complete = false;
  bool _checking = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    if (_checking || _complete) return;
    setState(() {
      _checking = true;
      _failed = false;
    });
    StoreUpdate? update;
    try {
      update = await widget.service.checkForUpdate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _failed = true;
      });
      return;
    }
    if (!mounted) return;
    if (update != null) {
      final confirmed = await showDialog<bool>(
        context: _navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (_) => AppUpdateDialog(
          update: update!,
          openStore: widget.openStore,
          checkForUpdate: widget.service.checkForUpdate,
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        setState(() {
          _checking = false;
          _failed = true;
        });
        return;
      }
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
    return PopScope(
      canPop: false,
      child: MaterialApp(
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
                  Text(
                      _failed
                          ? '버전을 확인하지 못했어요.\n인터넷 연결을 확인하고 다시 시도해 주세요.'
                          : '새 버전을 확인하고 있어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary)),
                  if (_failed) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _checkForUpdate,
                      child: const Text('다시 확인'),
                    ),
                  ],
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
