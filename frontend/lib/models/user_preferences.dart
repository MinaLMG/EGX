class UserPreferences {
  final String language;
  final String theme;
  final List<String> selectedInterestIds;

  UserPreferences({
    required this.language,
    required this.theme,
    required this.selectedInterestIds,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final interests = (json['selectedInterests'] as List? ?? [])
        .map((i) => i is Map ? (i['_id'] ?? i['id'] ?? '') as String : i.toString())
        .toList();

    return UserPreferences(
      language:            json['language'] ?? 'en',
      theme:               json['theme'] ?? 'system',
      selectedInterestIds: List<String>.from(interests),
    );
  }

  factory UserPreferences.defaults() {
    return UserPreferences(
      language: 'en',
      theme: 'system',
      selectedInterestIds: [],
    );
  }
}
