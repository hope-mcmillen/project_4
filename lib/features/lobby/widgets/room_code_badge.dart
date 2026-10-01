import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';

/// A small, copyable room reference that leaves the topic in the foreground.
class RoomCodeBadge extends StatelessWidget {
  const RoomCodeBadge({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Copy room code',
    child: TextButton.icon(
      style: TextButton.styleFrom(
        backgroundColor: AppColors.mint,
        foregroundColor: AppColors.deepTeal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Room code copied')));
        }
      },
      icon: const Icon(Icons.copy_rounded, size: 16),
      label: Text(
        code,
        semanticsLabel: 'Room code ${code.split('').join(' ')}',
      ),
    ),
  );
}
