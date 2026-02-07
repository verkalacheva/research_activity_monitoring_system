import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class UrlHelper {
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&' "'" r'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
  );
  
  static final RegExp _telegramRegExp = RegExp(r'^@[a-zA-Z0-9_]{5,32}$');
  static final RegExp _telegramUrlRegExp = RegExp(r'^https?://t\.me/([a-zA-Z0-9_]{5,32})/?$');
  static final RegExp _orcidRegExp = RegExp(r'^\d{4}-\d{4}-\d{4}-\d{3}[\dX]$');

  static Future<void> launchURL(BuildContext context, String text) async {
    Uri? url;
    
    if (_emailRegExp.hasMatch(text)) {
      url = Uri.parse('mailto:$text');
    } else if (_telegramRegExp.hasMatch(text)) {
      final username = text.substring(1);
      url = Uri.parse('https://t.me/$username');
    } else if (_telegramUrlRegExp.hasMatch(text)) {
      url = Uri.parse(text);
    } else if (_orcidRegExp.hasMatch(text)) {
      url = Uri.parse('https://orcid.org/$text');
    }

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось распознать ссылку: $text')),
      );
      return;
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось открыть: $text')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при открытии: $e')),
        );
      }
    }
  }

  static bool isLinkable(String text) {
    if (text.isEmpty || text == '—' || text == 'Не указано') return false;
    return _emailRegExp.hasMatch(text) || 
           _telegramRegExp.hasMatch(text) || 
           _telegramUrlRegExp.hasMatch(text) ||
           _orcidRegExp.hasMatch(text);
  }

  static Widget buildClickableText(BuildContext context, String text, {TextStyle? style, bool enabled = true}) {
    if (enabled && isLinkable(text)) {
      return InkWell(
        onTap: () => launchURL(context, text),
        child: Text(
          text,
          style: (style ?? const TextStyle()).copyWith(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }
    return Text(text, style: style);
  }
}

