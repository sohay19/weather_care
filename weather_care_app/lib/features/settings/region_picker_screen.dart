import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/selectable_region.dart';
import '../../services/region_catalog.dart';

const weatherGridSelectorUrl =
    'https://weather-care.pages.dev/weather-map/select';
const _selectionChannel = 'WeatherGridSelection';

typedef RegionMapBuilder = Widget Function(
  BuildContext context,
  ValueChanged<String> onSelectionMessage,
);

class RegionPickerScreen extends StatefulWidget {
  final Future<RegionCatalog> Function()? loadCatalog;
  final String? selectedGridId;
  final RegionMapBuilder? mapBuilder;

  const RegionPickerScreen({
    super.key,
    this.loadCatalog,
    this.selectedGridId,
    this.mapBuilder,
  });

  @override
  State<RegionPickerScreen> createState() => _RegionPickerScreenState();
}

class _RegionPickerScreenState extends State<RegionPickerScreen> {
  late final Future<RegionCatalog> _catalog;
  WebViewController? _webViewController;
  int _loadingProgress = 0;
  bool _mainFrameFailed = false;
  bool _handlingSelection = false;

  @override
  void initState() {
    super.initState();
    _catalog = widget.loadCatalog?.call() ?? RegionCatalog.load();
    if (widget.mapBuilder == null) _initializeWebView();
  }

  Uri get _selectorUri {
    final selected = widget.selectedGridId;
    final uri = Uri.parse(weatherGridSelectorUrl);
    if (selected == null || !RegExp(r'^\d{1,3}_\d{1,3}$').hasMatch(selected)) {
      return uri;
    }
    return uri.replace(queryParameters: {'grid': selected});
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xfff4f7fa))
      ..addJavaScriptChannel(
        _selectionChannel,
        onMessageReceived: (message) =>
            _handleSelectionMessage(message.message),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _loadingProgress = progress);
        },
        onPageStarted: (_) {
          if (!mounted) return;
          setState(() => _mainFrameFailed = false);
        },
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() => _loadingProgress = 100);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame != true || !mounted) return;
          setState(() => _mainFrameFailed = true);
        },
        onNavigationRequest: (request) {
          if (!request.isMainFrame) return NavigationDecision.navigate;
          final uri = Uri.tryParse(request.url);
          final allowed = uri != null &&
              uri.scheme == 'https' &&
              uri.host == 'weather-care.pages.dev' &&
              (uri.path == '/weather-map/select' ||
                  uri.path == '/weather-map/select/');
          return allowed
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(_selectorUri);
  }

  Future<void> _handleSelectionMessage(String rawMessage) async {
    if (_handlingSelection) return;
    _handlingSelection = true;
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map<String, dynamic> ||
          decoded['type'] != 'weather-grid-selection') {
        throw const FormatException('Invalid selection message');
      }
      final nxValue = decoded['nx'];
      final nyValue = decoded['ny'];
      if (nxValue is! num ||
          nyValue is! num ||
          nxValue != nxValue.toInt() ||
          nyValue != nyValue.toInt()) {
        throw const FormatException('Invalid grid coordinates');
      }
      final nx = nxValue.toInt();
      final ny = nyValue.toInt();
      final selection = ForecastGridSelection(nx: nx, ny: ny);
      if (nx < 1 ||
          nx > 149 ||
          ny < 1 ||
          ny > 253 ||
          decoded['gridId'] != selection.gridId) {
        throw const FormatException('Grid is out of range');
      }
      final catalog = await _catalog;
      final exists = catalog.regions.any(
        (region) => region.nx == nx && region.ny == ny,
      );
      if (!exists) throw const FormatException('Unknown forecast grid');
      if (mounted) Navigator.pop(context, selection);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('선택한 예보 구역을 확인하지 못했어요.\n지도를 새로고침한 뒤 다시 선택해주세요.'),
        ));
      }
    } finally {
      _handlingSelection = false;
    }
  }

  void _reload() {
    setState(() {
      _mainFrameFailed = false;
      _loadingProgress = 0;
    });
    _webViewController?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final customMap = widget.mapBuilder;
    final map = customMap != null
        ? customMap(context, _handleSelectionMessage)
        : WebViewWidget(controller: _webViewController!);
    return Scaffold(
      appBar: AppBar(title: const Text('예보 구역 선택')),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: map),
            if (customMap == null &&
                !_mainFrameFailed &&
                _loadingProgress < 100)
              Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  value: _loadingProgress == 0 ? null : _loadingProgress / 100,
                ),
              ),
            if (_mainFrameFailed)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 42),
                          const SizedBox(height: 14),
                          const Text(
                            '예보 구역 지도를 불러오지 못했어요.\n인터넷 연결을 확인해주세요.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: _reload,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
