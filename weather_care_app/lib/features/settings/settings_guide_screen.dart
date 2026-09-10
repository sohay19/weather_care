import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/weather_theme.dart';
import 'settings_guide.dart';

class SettingsGuideScreen extends StatelessWidget {
  final SettingsGuide guide;
  final Future<bool> Function(Uri)? openLink;

  const SettingsGuideScreen({super.key, required this.guide, this.openLink});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: MediaQuery.textScalerOf(context).scale(kToolbarHeight),
          title: Text(guide.title, maxLines: 2),
        ),
        body: SafeArea(
          child: ListView(
            key: ValueKey('settings-guide-${guide.name}'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(guide.subtitle,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              for (final section in guide.sections)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: WeatherCareTheme.surfaceDecoration(radius: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      for (final paragraph in section.paragraphs) ...[
                        const SizedBox(height: 10),
                        Text(paragraph),
                      ],
                      for (final link in section.links)
                        _GuideLinkButton(link: link, openLink: openLink),
                    ],
                  ),
                ),
              if (guide.sections.any((section) => section.links.isNotEmpty))
                const Text('링크는 외부 브라우저로 열려요. 인터넷 연결이 필요해요.'),
            ],
          ),
        ),
      );
}

class _GuideLinkButton extends StatefulWidget {
  final GuideLink link;
  final Future<bool> Function(Uri)? openLink;
  const _GuideLinkButton({required this.link, this.openLink});

  @override
  State<_GuideLinkButton> createState() => _GuideLinkButtonState();
}

class _GuideLinkButtonState extends State<_GuideLinkButton> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    var opened = false;
    try {
      final uri = Uri.parse(widget.link.url);
      opened = await (widget.openLink?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // The browser may be missing or unavailable. Never expose raw errors.
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (opened) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('링크를 열지 못했어요'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('브라우저와 인터넷 연결을 확인하거나 주소를 복사해서 열어주세요.'),
            const SizedBox(height: 12),
            SelectableText(widget.link.url),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              var copied = false;
              try {
                await Clipboard.setData(ClipboardData(text: widget.link.url));
                copied = true;
              } catch (_) {
                // Keep the selectable URL visible if the clipboard is unavailable.
              }
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                content: Text(
                    copied ? '주소를 복사했어요.' : '주소를 복사하지 못했어요. 주소를 길게 눌러 선택해주세요.'),
              ));
            },
            child: const Text('주소 복사'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextButton.icon(
          onPressed: _opening ? null : _open,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text('${widget.link.label} · 외부 브라우저'),
        ),
      );
}
