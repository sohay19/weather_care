import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreUpdateNotificationScreen extends StatefulWidget {
  final Uri? storeUrl;
  final Future<bool> Function(Uri)? openStore;

  const StoreUpdateNotificationScreen(
      {super.key, this.storeUrl, this.openStore});

  @override
  State<StoreUpdateNotificationScreen> createState() =>
      _StoreUpdateNotificationScreenState();
}

class _StoreUpdateNotificationScreenState
    extends State<StoreUpdateNotificationScreen> {
  bool _opening = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openStore();
    });
  }

  void _backToApp() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed('/');
    }
  }

  Future<void> _openStore() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    var opened = false;
    try {
      final url = widget.storeUrl;
      final allowedHost = switch (defaultTargetPlatform) {
        TargetPlatform.android => 'play.google.com',
        TargetPlatform.iOS => 'apps.apple.com',
        _ => '',
      };
      if (!kIsWeb &&
          url != null &&
          url.scheme == 'https' &&
          url.host == allowedHost) {
        opened = await (widget.openStore ??
            (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(url);
      }
    } catch (_) {
      // 스토어 미설치·연결 오류가 있어도 앱으로 돌아갈 수 있다.
    }
    if (!mounted) return;
    if (opened) {
      _backToApp();
      return;
    }
    setState(() {
      _opening = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('업데이트 안내')),
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_opening) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_failed ? '스토어를 열지 못했어요. 잠시 후 다시 시도해 주세요.' : '스토어로 이동하고 있어요.',
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (_failed)
              FilledButton(onPressed: _openStore, child: const Text('다시 열기')),
            TextButton(onPressed: _backToApp, child: const Text('앱으로 돌아가기')),
          ]),
        )),
      );
}
