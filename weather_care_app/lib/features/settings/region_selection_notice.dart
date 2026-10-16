import 'package:flutter/material.dart';

bool canAddForecastGrid(
  BuildContext context,
  String gridId,
  Set<String> savedGridIds,
) {
  if (!savedGridIds.contains(gridId)) return true;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('구역 추가'),
      content: const Text('이미 추가된 구역입니다'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
  return false;
}
