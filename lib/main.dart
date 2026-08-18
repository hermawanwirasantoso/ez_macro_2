import 'package:flutter/material.dart';

import 'features/calorie_tracker/data/api_key_storage.dart';
import 'features/calorie_tracker/data/google_ai_calorie_parser.dart';
import 'features/calorie_tracker/domain/calorie_parser.dart';
import 'features/calorie_tracker/domain/parse_result.dart';
import 'features/calorie_tracker/domain/tracker_state.dart';
import 'features/calorie_tracker/presentation/theme/app_theme.dart';
import 'features/calorie_tracker/presentation/widgets/ai_logger_card.dart';
import 'features/calorie_tracker/presentation/widgets/api_key_modal.dart';
import 'features/calorie_tracker/presentation/widgets/hero_calorie_card.dart';
import 'features/calorie_tracker/presentation/widgets/recent_entries_section.dart';
import 'features/calorie_tracker/presentation/widgets/target_editor_modal.dart';

const String _googleAiApiKey = String.fromEnvironment('GOOGLE_AI_API_KEY');
const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _googleApiKey = String.fromEnvironment('GOOGLE_API_KEY');
const String _googleAiStudioApiKey = String.fromEnvironment('GOOGLE_AI_STUDIO_API_KEY');
const String _googleAiBaseUrl = String.fromEnvironment(
  'GOOGLE_AI_BASE_URL',
  defaultValue: 'https://generativelanguage.googleapis.com/v1beta',
);
const String _googleAiModel = String.fromEnvironment(
  'GOOGLE_AI_MODEL',
  defaultValue: 'gemini-3.5-flash-lite',
);

void main() {
  runApp(const MacroTrackerApp());
}

class MacroTrackerApp extends StatefulWidget {
  const MacroTrackerApp({
    super.key,
    ApiKeyStorage? apiKeyStorage,
  }) : apiKeyStorage = apiKeyStorage ?? const SecureApiKeyStorage();

  final ApiKeyStorage apiKeyStorage;

  @override
  State<MacroTrackerApp> createState() => _MacroTrackerAppState();
}

class _MacroTrackerAppState extends State<MacroTrackerApp> {
  bool _isDarkMode = true;

  void _toggleThemeMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EZ Macro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(isDarkMode: _isDarkMode),
      home: CalorieHomePage(
        onToggleTheme: _toggleThemeMode,
        isDarkMode: _isDarkMode,
        apiKeyStorage: widget.apiKeyStorage,
      ),
    );
  }
}

class CalorieHomePage extends StatefulWidget {
  const CalorieHomePage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
    ApiKeyStorage? apiKeyStorage,
  }) : apiKeyStorage = apiKeyStorage ?? const SecureApiKeyStorage();

  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final ApiKeyStorage apiKeyStorage;

  @override
  State<CalorieHomePage> createState() => _CalorieHomePageState();
}

class _CalorieHomePageState extends State<CalorieHomePage> {
  final CalorieTrackerState _trackerState = CalorieTrackerState();
  String? _userApiKey;
  late CalorieParser _calorieParser = _buildParser();
  final CalorieParser _fallbackParser = const RegexCalorieParser();
  final TextEditingController _nlInputController = TextEditingController();
  bool _isParsing = false;
  bool _lastUsedFallback = false;
  bool _showSpreadDetails = false;
  ParseResult? _lastParse;

  @override
  void initState() {
    super.initState();
    _loadSavedApiKey();
  }

  Future<void> _loadSavedApiKey() async {
    try {
      final String? key = await widget.apiKeyStorage.getApiKey();
      if (mounted && key != null && key.isNotEmpty) {
        setState(() {
          _userApiKey = key;
          _calorieParser = _buildParser();
        });
      }
    } catch (_) {
      // Gracefully handle any platform or storage read failures
    }
  }

  bool get _hasConfiguredApiKey => _resolveApiKey().isNotEmpty;

  void _addCalories(
    int calories,
    String mealLabel, {
    int proteinG = 0,
    int carbsG = 0,
    int fatG = 0,
    String? rangeText,
    String? sourceLabel,
    double? spreadPercent,
  }) {
    setState(() {
      _trackerState.addCalories(
        calories: calories,
        mealLabel: mealLabel,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        rangeText: rangeText,
        sourceLabel: sourceLabel,
        spreadPercent: spreadPercent,
      );
    });
  }

  void _removeEntry(int index) {
    setState(() {
      _trackerState.removeEntryAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry removed. Totals updated.')),
    );
  }

  CalorieParser _buildParser() {
    final String apiKey = _resolveApiKey();
    if (apiKey.isNotEmpty) {
      return GoogleAiCalorieParser(
        apiKey: apiKey,
        model: _googleAiModel,
        baseUrl: _googleAiBaseUrl,
      );
    }
    return const RegexCalorieParser();
  }

  String _resolveApiKey() {
    if (_userApiKey != null && _userApiKey!.isNotEmpty) {
      return _userApiKey!;
    }
    return _resolveEnvApiKey();
  }

  String _resolveEnvApiKey() {
    if (_geminiApiKey.isNotEmpty) {
      return _geminiApiKey;
    }
    if (_googleAiApiKey.isNotEmpty) {
      return _googleAiApiKey;
    }
    if (_googleApiKey.isNotEmpty) {
      return _googleApiKey;
    }
    return _googleAiStudioApiKey;
  }

  Future<void> _openApiKeyModal() async {
    final String? updatedKey = await ApiKeyModal.show(
      context,
      storage: widget.apiKeyStorage,
      currentKey: _userApiKey,
      envKey: _resolveEnvApiKey(),
    );
    if (updatedKey != null && mounted) {
      setState(() {
        _userApiKey = updatedKey.isEmpty ? null : updatedKey;
        _calorieParser = _buildParser();
      });
    }
  }

  Future<void> _parseAndLogMeal() async {
    final String rawInput = _nlInputController.text.trim();
    if (rawInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a meal description first.')),
      );
      return;
    }

    setState(() {
      _isParsing = true;
    });

    final ParseResult? primaryResult = await _calorieParser.parse(rawInput);
    ParseResult? result = primaryResult;
    bool usedFallback = false;
    if (result == null) {
      result = await _fallbackParser.parse(rawInput);
      usedFallback = result != null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isParsing = false;
      _lastParse = result;
      _lastUsedFallback = usedFallback;
    });

    if (usedFallback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI unavailable for this request, using local estimate.'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not estimate this food yet. Try a simpler phrase like "a bowl of rice".',
          ),
        ),
      );
      return;
    }

    final double uncertainty =
        result.uncertaintyPercent(isFallback: usedFallback);
    final int low = result.caloriesLowerBound(uncertainty);
    final int high = result.caloriesUpperBound(uncertainty);
    final String sourceLabel = usedFallback ? 'Local' : 'AI';

    _addCalories(
      result.calories,
      result.mealLabel,
      proteinG: result.proteinG,
      carbsG: result.carbsG,
      fatG: result.fatG,
      rangeText: '$low-$high kcal',
      sourceLabel: sourceLabel,
      spreadPercent: uncertainty,
    );
    _nlInputController.clear();
  }

  Future<void> _openTargetEditor() async {
    final bool? saved = await TargetEditorModal.show(context, _trackerState);
    if (saved == true && mounted) {
      setState(() {});
      FocusScope.of(context).unfocus();
    }
  }

  void _onSelectSuggestion(String suggestion) {
    _nlInputController.text = suggestion;
    _nlInputController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
  }

  @override
  void dispose() {
    _nlInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final double progress = _trackerState.dailyGoal <= 0
        ? 0
        : (_trackerState.consumedCalories / _trackerState.dailyGoal).clamp(0, 1).toDouble();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[AppColors.primary, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'EZ Macro',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              key: const Key('openApiKeyModalButton'),
              onPressed: _openApiKeyModal,
              icon: Icon(
                Icons.vpn_key_rounded,
                size: 18,
                color: _hasConfiguredApiKey
                    ? AppColors.success
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
              tooltip: 'Configure Google AI API Key',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              key: const Key('toggleThemeButton'),
              onPressed: widget.onToggleTheme,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return RotationTransition(
                    turns: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Icon(
                  widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey<bool>(widget.isDarkMode),
                  color: widget.isDarkMode ? Colors.amber : AppColors.primaryDark,
                ),
              ),
              tooltip: 'Toggle theme',
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const <Color>[
                    AppColors.darkBackgroundGrad1,
                    AppColors.darkBackground,
                    AppColors.darkBackgroundGrad2,
                  ]
                : const <Color>[
                    AppColors.lightBackgroundGrad1,
                    AppColors.lightBackground,
                    AppColors.lightBackgroundGrad2,
                  ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: <Widget>[
              // Top Banner Row: "Today's Calories" Title + Streak Banner + Percentage Ring
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          "Today's Calories",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: AppColors.streak.withValues(alpha: 0.12),
                            border: Border.all(
                              color: AppColors.streak.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.local_fire_department, color: AppColors.streak, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Streak 5 days',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.streak,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Animated Circular Indicator
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: progress,
                      ),
                      duration: const Duration(milliseconds: 700),
                      builder: (BuildContext context, double value, Widget? child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            SizedBox(
                              width: 54,
                              height: 54,
                              child: CircularProgressIndicator(
                                strokeWidth: 5.5,
                                strokeCap: StrokeCap.round,
                                value: value,
                                backgroundColor: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : AppColors.primary.withValues(alpha: 0.12),
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              '${(value * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hero Calorie and Macro Card
              HeroCalorieCard(
                trackerState: _trackerState,
                showSpreadDetails: _showSpreadDetails,
                onToggleSpread: (bool value) {
                  setState(() {
                    _showSpreadDetails = value;
                  });
                },
                onOpenTargetEditor: _openTargetEditor,
              ),

              const SizedBox(height: 18),

              // AI Natural Language Input Card
              AiLoggerCard(
                inputController: _nlInputController,
                isParsing: _isParsing,
                hasConfiguredApiKey: _hasConfiguredApiKey,
                lastParse: _lastParse,
                lastUsedFallback: _lastUsedFallback,
                showSpreadDetails: _showSpreadDetails,
                onParse: _parseAndLogMeal,
                onSelectSuggestion: _onSelectSuggestion,
                onConfigureApiKey: _openApiKeyModal,
              ),

              const SizedBox(height: 20),

              // Recent Entries List Section
              RecentEntriesSection(
                entries: _trackerState.entries,
                onRemoveEntry: _removeEntry,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
