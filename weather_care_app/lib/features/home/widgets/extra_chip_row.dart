import 'package:flutter/material.dart';

class ExtraChipRow extends StatelessWidget {
  final List<Widget> children;
  const ExtraChipRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ]),
      );
}
