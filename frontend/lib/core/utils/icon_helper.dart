import 'package:flutter/material.dart';

class IconHelper {
  static const Map<String, IconData> icons = {
    'article': Icons.article,
    'grant': Icons.monetization_on,
    'hackathon': Icons.code,
    'rid': Icons.psychology,
    'conference': Icons.groups,
    'media_mention': Icons.campaign,
    'media_pub': Icons.newspaper,
    'mentoring': Icons.school,
    'scholarship': Icons.military_tech,
    'internship': Icons.work,
    'development': Icons.terminal,
    'presentation': Icons.record_voice_over,
    'startup': Icons.rocket_launch,
    'contest': Icons.emoji_events,
    'star': Icons.star,
    'other': Icons.more_horiz,
  };

  static IconData getIcon(String? name) {
    if (name == null || !icons.containsKey(name)) {
      return Icons.help_outline;
    }
    return icons[name]!;
  }

  static String? getName(IconData data) {
    return icons.entries.firstWhere((e) => e.value == data).key;
  }
}


