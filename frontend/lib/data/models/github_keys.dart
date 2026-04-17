class GitHubCheckKey {
  final String key;
  final String label;
  final String category;

  const GitHubCheckKey({required this.key, required this.label, required this.category});

  factory GitHubCheckKey.fromJson(Map<String, dynamic> json) {
    return GitHubCheckKey(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      category: json['category'] ?? '',
    );
  }
}

class GitHubCheckKeysRegistry {
  final List<GitHubCheckKey> criteriaKeys;
  final List<GitHubCheckKey> activityKeys;
  final Map<String, String> categoryLabels;

  const GitHubCheckKeysRegistry({
    required this.criteriaKeys,
    required this.activityKeys,
    required this.categoryLabels,
  });

  factory GitHubCheckKeysRegistry.fromJson(Map<String, dynamic> json) {
    return GitHubCheckKeysRegistry(
      criteriaKeys: (json['criteria_keys'] as List? ?? [])
          .map((e) => GitHubCheckKey.fromJson(e))
          .toList(),
      activityKeys: (json['activity_keys'] as List? ?? [])
          .map((e) => GitHubCheckKey.fromJson(e))
          .toList(),
      categoryLabels: Map<String, String>.from(json['category_labels'] ?? {}),
    );
  }

  String labelFor(String key) {
    for (final k in [...criteriaKeys, ...activityKeys]) {
      if (k.key == key) return k.label;
    }
    return key;
  }
}
