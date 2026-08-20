import 'dart:convert';

/// Persistent user settings including daily macro goals and app preferences.
class UserSettings {
  const UserSettings({
    this.dailyGoal = 2200,
    this.targetProteinG = 160,
    this.targetCarbsG = 255,
    this.targetFatG = 60,
    this.isDarkMode = true,
    this.hasCompletedOnboarding = true,
  });

  final int dailyGoal;
  final int targetProteinG;
  final int targetCarbsG;
  final int targetFatG;
  final bool isDarkMode;
  final bool hasCompletedOnboarding;

  UserSettings copyWith({
    int? dailyGoal,
    int? targetProteinG,
    int? targetCarbsG,
    int? targetFatG,
    bool? isDarkMode,
    bool? hasCompletedOnboarding,
  }) {
    return UserSettings(
      dailyGoal: dailyGoal ?? this.dailyGoal,
      targetProteinG: targetProteinG ?? this.targetProteinG,
      targetCarbsG: targetCarbsG ?? this.targetCarbsG,
      targetFatG: targetFatG ?? this.targetFatG,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'dailyGoal': dailyGoal,
      'targetProteinG': targetProteinG,
      'targetCarbsG': targetCarbsG,
      'targetFatG': targetFatG,
      'isDarkMode': isDarkMode,
      'hasCompletedOnboarding': hasCompletedOnboarding,
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      dailyGoal: (map['dailyGoal'] as num?)?.toInt() ?? 2200,
      targetProteinG: (map['targetProteinG'] as num?)?.toInt() ?? 160,
      targetCarbsG: (map['targetCarbsG'] as num?)?.toInt() ?? 255,
      targetFatG: (map['targetFatG'] as num?)?.toInt() ?? 60,
      isDarkMode: map['isDarkMode'] as bool? ?? true,
      hasCompletedOnboarding: map['hasCompletedOnboarding'] as bool? ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserSettings.fromJson(String source) =>
      UserSettings.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSettings &&
        other.dailyGoal == dailyGoal &&
        other.targetProteinG == targetProteinG &&
        other.targetCarbsG == targetCarbsG &&
        other.targetFatG == targetFatG &&
        other.isDarkMode == isDarkMode &&
        other.hasCompletedOnboarding == hasCompletedOnboarding;
  }

  @override
  int get hashCode {
    return Object.hash(
      dailyGoal,
      targetProteinG,
      targetCarbsG,
      targetFatG,
      isDarkMode,
      hasCompletedOnboarding,
    );
  }
}
