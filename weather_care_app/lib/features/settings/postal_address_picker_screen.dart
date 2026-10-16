import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/postal_address.dart';

typedef PostalAddressPicker = Future<PostalAddress?> Function(
    BuildContext context, String query);
typedef PostalSearchBuilder = Widget Function(
    BuildContext context, ValueChanged<String> onMessage);

Future<PostalAddress?> showPostalAddressPicker(
    BuildContext context, String query) async {
  if (kIsWeb ||
      ![TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]
          .contains(defaultTargetPlatform)) {
    throw UnsupportedError('Postal address search is unavailable');
  }
  return Navigator.of(context).push<PostalAddress>(MaterialPageRoute(
      builder: (_) => PostalAddressPickerScreen(query: query)));
}

class PostalAddressPickerScreen extends StatefulWidget {
  final String query;
  final PostalSearchBuilder? searchBuilder;

  const PostalAddressPickerScreen(
      {super.key, required this.query, this.searchBuilder});

  @override
  State<PostalAddressPickerScreen> createState() =>
      _PostalAddressPickerScreenState();
}

class _PostalAddressPickerScreenState extends State<PostalAddressPickerScreen> {
  WebViewController? _controller;
  Timer? _timeout;
  bool _loading = true;
  bool _failed = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    if (widget.searchBuilder != null) return;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('PostalAddressSelection',
          onMessageReceived: (message) => _onMessage(message.message))
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (!request.isMainFrame) return NavigationDecision.navigate;
          return request.url == 'about:blank' ||
                  request.url == 'https://weather-care.pages.dev/'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) _fail();
        },
      ));
    _load();
  }

  void _load() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 20), _fail);
    _controller!.loadHtmlString(postalSearchHtml(widget.query),
        baseUrl: 'https://weather-care.pages.dev/');
  }

  void _fail() {
    if (!mounted || _completed) return;
    _timeout?.cancel();
    setState(() {
      _failed = true;
      _loading = false;
    });
  }

  void _onMessage(String raw) {
    if (!mounted || _completed) return;
    try {
      if (raw.length > 8192) throw const FormatException();
      final message = jsonDecode(raw);
      if (message is! Map<String, dynamic>) throw const FormatException();
      if (message['type'] == 'ready') {
        _timeout?.cancel();
        setState(() {
          _loading = false;
          _failed = false;
        });
      } else if (message['type'] == 'error') {
        _fail();
      } else if (message['type'] == 'postal-address-selection' &&
          message['data'] is Map<String, dynamic>) {
        final address = PostalAddress.fromJson(message['data']);
        _completed = true;
        _timeout?.cancel();
        Navigator.pop(context, address);
      } else {
        throw const FormatException();
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택한 주소를 확인하지 못했어요. 다시 선택해주세요.')));
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('도로명·지번 주소 검색')),
        body: SafeArea(
            child: Stack(children: [
          Positioned.fill(
              child: widget.searchBuilder?.call(context, _onMessage) ??
                  WebViewWidget(controller: _controller!)),
          if (_loading)
            const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator()),
          if (_failed)
            Positioned.fill(
                child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('주소 검색을 열지 못했어요. 인터넷 연결을 확인해주세요.'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _failed = false;
                        });
                        if (_controller != null) _load();
                      },
                      child: const Text('다시 시도')),
                ]),
              )),
            )),
        ])),
      );
}

String postalSearchHtml(String query) {
  final encodedQuery = jsonEncode(query).replaceAll('<', r'\u003c');
  return '''<!doctype html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body,#search{margin:0;width:100%;height:100%;}body{overflow:auto;}</style>
</head><body><div id="search"></div>
<script>
function send(type, data) {
  PostalAddressSelection.postMessage(JSON.stringify({type:type,data:data}));
}
function start() {
  new kakao.Postcode({width:'100%',height:'100%',minWidth:280,
    onresize:function(){send('ready');},
    onsearch:function(){send('ready');},
    oncomplete:function(data){send('postal-address-selection', {
      roadAddress:data.roadAddress, jibunAddress:data.jibunAddress,
      autoRoadAddress:data.autoRoadAddress, autoJibunAddress:data.autoJibunAddress
    });}
  }).embed(document.getElementById('search'),{q:$encodedQuery,autoClose:false});
}
</script>
<script src="https://t1.kakaocdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"
 onload="start()" onerror="send('error')"></script></body></html>''';
}
