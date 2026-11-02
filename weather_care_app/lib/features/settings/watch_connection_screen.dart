import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WatchConnectionScreen extends StatefulWidget {
  final Future<void> Function()? onRefresh;
  const WatchConnectionScreen({super.key, this.onRefresh});
  @override
  State<WatchConnectionScreen> createState() => _WatchConnectionScreenState();
}

class _WatchConnectionScreenState extends State<WatchConnectionScreen> {
  static const _channel = MethodChannel('com.codesoha.weathercare/home-widget');
  final _code = TextEditingController();
  bool _busy = true;
  bool _linked = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _perform('wearStatus');
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _perform(String method) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final raw = await _channel.invokeMethod<String>(
          method, method == 'wearClaim' ? _code.text : null);
      final result = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _linked = result['linked'] == true;
      });
      if (method == 'wearClaim' || method == 'wearSend') {
        if (method == 'wearClaim') {
          await widget.onRefresh?.call();
          await _channel.invokeMethod<String>('wearSend');
        }
        if (mounted) {
          setState(() {
            _message = '날씨 전송을 요청했어요. 워치에서 새로고침해 주세요.';
          });
        }
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _message = switch (error.code) {
            'WEAR_INVALID_CODE' => '워치에 표시된 8자리 코드를 입력해 주세요.',
            'WEAR_INVALID_OR_EXPIRED_CODE' =>
              '코드가 만료되었거나 이미 사용됐어요. 워치에서 새 코드를 만들어 주세요.',
            'WEAR_RATE_LIMITED' => '잠시 후 다시 연결해 주세요.',
            'WEAR_ALREADY_LINKED' => '기존 연결을 해제한 뒤 새 워치를 연결해 주세요.',
            _ => '연결을 확인하지 못했어요. 인터넷 연결 후 다시 시도해 주세요.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = '날씨를 보내지 못했어요. 다시 시도해 주세요.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('워치 연결')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Text(_linked ? '워치가 연결되어 있어요' : '워치의 연결 코드를 입력해 주세요',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          if (!_linked) ...[
            TextField(
              controller: _code,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              maxLength: 9,
              decoration: const InputDecoration(
                  labelText: '연결 코드',
                  hintText: 'ABCD-EFGH',
                  border: OutlineInputBorder()),
              onSubmitted: (_) {
                if (!_busy) _perform('wearClaim');
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: _busy ? null : () => _perform('wearClaim'),
                child: const Text('워치 연결')),
          ] else ...[
            FilledButton(
                onPressed: _busy ? null : () => _perform('wearSend'),
                child: const Text('날씨 다시 보내기')),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _busy ? null : () => _perform('wearUnlink'),
                child: const Text('연결 해제')),
          ],
          const SizedBox(height: 12),
          TextButton(
              onPressed: _busy ? null : () => _perform('wearStatus'),
              child: const Text('연결 상태 확인')),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_message != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_message!)),
        ]),
      );
}
