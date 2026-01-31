import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClipboardHelper {
  static void copyToClipboard(BuildContext context, String text, {String? message}) {
    if (text.isEmpty) return;
    
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? 'Скопировано в буфер обмена'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }
}

