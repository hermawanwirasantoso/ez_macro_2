import 'package:flutter/material.dart';

import 'features/calorie_tracker/data/api_key_storage.dart';
import 'features/calorie_tracker/data/calorie_storage.dart';
import 'features/calorie_tracker/data/google_ai_calorie_parser.dart';
import 'features/calorie_tracker/data/nutrition_label_image_source.dart';
import 'features/calorie_tracker/domain/calorie_parser.dart';
import 'features/calorie_tracker/domain/nutrition_label_image.dart';
import 'features/calorie_tracker/domain/parse_result.dart';
import 'features/calorie_tracker/domain/saved_food.dart';
import 'features/calorie_tracker/domain/tracker_state.dart';
import 'features/calorie_tracker/presentation/theme/app_theme.dart';
import 'features/calorie_tracker/presentation/widgets/ai_logger_card.dart';
import 'features/calorie_tracker/presentation/widgets/api_key_modal.dart';
import 'features/calorie_tracker/presentation/widgets/date_navigation_bar.dart';
import 'features/calorie_tracker/presentation/widgets/detailed_nutrition_modal.dart';
import 'features/calorie_tracker/presentation/widgets/food_entry_modal.dart';
import 'features/calorie_tracker/presentation/widgets/hero_calorie_card.dart';
import 'features/calorie_tracker/presentation/widgets/meal_category_tabs.dart';
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
    CalorieStorage? calorieStorage,
    this.nutritionLabelImageSource,
  })  : apiKeyStorage = apiKeyStorage ?? const SecureApiKeyStorage(),
        calorieStorage = calorieStorage ?? const PreferencesCalorieStorage();

  final ApiKeyStorage apiKeyStorage;
  final CalorieStorage calorieStorage;
  final NutritionLabelImageSource? nutritionLabelImageSource;

  @override
  State<MacroTrackerApp> createState() => _MacroTrackerAppState();
}

class _MacroTrackerAppState extends State<MacroTrackerApp> {
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
  }

  Future<void> _loadInitialSettings() async {
    try {
      final UserSettings settings = await widget.calorieStorage.loadSettings();
      if (mounted && settings.isDarkMode != _isDarkMode) {
        setState(() {
          _isDarkMode = settings.isDarkMode;
        });
      }
    } catch (_) {
      // Retain default dark mode
    }
  }

  void _toggleThemeMode() {
    final bool newMode = !_isDarkMode;
    setState(() {
      _isDarkMode = newMode;
    });

    // Save theme preference asynchronously
    widget.calorieStorage.loadSettings().then((UserSettings current) {
      widget.calorieStorage.saveSettings(current.copyWith(isDarkMode: newMode));
    }).catchError((_) {});
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
        calorieStorage: widget.calorieStorage,
        nutritionLabelImageSource: widget.nutritionLabelImageSource,
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
    CalorieStorage? calorieStorage,
    this.nutritionLabelImageSource,
  })  : apiKeyStorage = apiKeyStorage ?? const SecureApiKeyStorage(),
        calorieStorage = calorieStorage ?? const PreferencesCalorieStorage();

  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final ApiKeyStorage apiKeyStorage;
  final CalorieStorage calorieStorage;
  final NutritionLabelImageSource? nutritionLabelImageSource;

  @override
  State<CalorieHomePage> createState() => _CalorieHomePageState();
}

class _CalorieHomePageState extends State<CalorieHomePage> {
  late final CalorieTrackerState _trackerState;
  String? _userApiKey;
  late CalorieParser _calorieParser = _buildParser();
  final CalorieParser _fallbackParser = const RegexCalorieParser();
  final TextEditingController _nlInputController = TextEditingController();
  bool _isParsing = false;
  bool _lastUsedFallback = false;
  bool _showSpreadDetails = false;
  ParseResult? _lastParse;
  List<SavedFood> _savedFoods = <SavedFood>[];

  @override
  void initState() {
    super.initState();
    _trackerState = CalorieTrackerState(storage: widget.calorieStorage);
    _loadSavedApiKey();
    _initTrackerData();
    _loadSavedFoods();
  }

  Future<void> _initTrackerData() async {
    await _trackerState.initFromStorage(storage: widget.calorieStorage);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSavedFoods() async {
    try {
      final List<SavedFood> savedFoods =
          await widget.calorieStorage.loadSavedFoods();
      if (mounted) {
        setState(() {
          _savedFoods = savedFoods;
        });
      }
    } catch (_) {
      // Keep an empty in-memory catalog if storage is unavailable.
    }
  }

  Future<void> _saveFoodForFutureUse(SavedFood food) async {
    final int existingIndex = _savedFoods.indexWhere(
      (SavedFood item) => item.name.toLowerCase() == food.name.toLowerCase(),
    );
    final SavedFood foodToSave = existingIndex == -1
        ? food
        : food.copyWith(
            id: _savedFoods[existingIndex].id,
            updatedAt: DateTime.now(),
          );

    await widget.calorieStorage.saveSavedFood(foodToSave);
    final List<SavedFood> savedFoods =
        await widget.calorieStorage.loadSavedFoods();
    if (mounted) {
      setState(() {
        _savedFoods = savedFoods;
      });
    }
  }

  Future<void> _deleteSavedFood(SavedFood food) async {
    await widget.calorieStorage.deleteSavedFood(food.id);
    if (mounted) {
      setState(() {
        _savedFoods.removeWhere((SavedFood item) => item.id == food.id);
      });
    }
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
    int saturatedFatG = 0,
    int fiberG = 0,
    int addedSugarG = 0,
    int sodiumMg = 0,
    String? rangeText,
    String? sourceLabel,
    double? spreadPercent,
    MealType? mealType,
  }) {
    setState(() {
      _trackerState.addCalories(
        calories: calories,
        mealLabel: mealLabel,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        saturatedFatG: saturatedFatG,
        fiberG: fiberG,
        addedSugarG: addedSugarG,
        sodiumMg: sodiumMg,
        rangeText: rangeText,
        sourceLabel: sourceLabel,
        spreadPercent: spreadPercent,
        mealType: mealType,
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

  Future<void> _editEntry(int index) async {
    if (index < 0 || index >= _trackerState.filteredEntries.length) return;
    final FoodLogEntry target = _trackerState.filteredEntries[index];

    final dynamic result = await FoodEntryModal.showEdit(context, target);
    if (result == null || !mounted) return;

    if (result == 'delete') {
      setState(() {
        _trackerState.removeEntryById(target.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted.')),
      );
    } else if (result is FoodLogEntry) {
      final int originalIndex = _trackerState.entries.indexWhere((FoodLogEntry e) => e.id == target.id);
      if (originalIndex != -1) {
        setState(() {
          _trackerState.editEntry(originalIndex, result);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry updated.')),
        );
      }
    }
  }

  Future<void> _openQuickAddModal() async {
    final FoodLogEntry? result = await FoodEntryModal.showAdd(
      context,
      defaultMealType: _trackerState.selectedMealFilter ?? MealType.forTime(),
      savedFoods: _savedFoods,
      onSaveFood: _saveFoodForFutureUse,
      onDeleteSavedFood: _deleteSavedFood,
      nutritionLabelImageSource: widget.nutritionLabelImageSource,
      hasConfiguredApiKey: _hasConfiguredApiKey,
      onParseNutritionLabel: (
        NutritionLabelImage image, {
        String? hint,
      }) {
        return _calorieParser.parseNutritionLabel(image, hint: hint);
      },
    );

    if (result != null && mounted) {
      _addCalories(
        result.calories,
        result.mealLabel,
        proteinG: result.proteinG,
        carbsG: result.carbsG,
        fatG: result.fatG,
        saturatedFatG: result.saturatedFatG,
        fiberG: result.fiberG,
        addedSugarG: result.addedSugarG,
        sodiumMg: result.sodiumMg,
        sourceLabel: result.sourceLabel ?? 'Manual',
        mealType: result.mealType,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged ${result.mealLabel} (${result.calories} kcal).')),
      );
    }
  }

  Future<void> _confirmClearDay() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Day Logs?'),
          content: Text(
            'Are you sure you want to remove all food entries for ${_trackerState.formattedDate}?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.fat),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() {
        _trackerState.clearCurrentDay();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day log cleared.')),
      );
    }
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
      saturatedFatG: result.saturatedFatG,
      fiberG: result.fiberG,
      addedSugarG: result.addedSugarG,
      sodiumMg: result.sodiumMg,
      rangeText: '$low-$high kcal',
      sourceLabel: sourceLabel,
      spreadPercent: uncertainty,
      mealType: _trackerState.selectedMealFilter ?? MealType.forTime(),
    );
    _nlInputController.clear();
  }

  void _openDetailedNutrition() {
    DetailedNutritionModal.show(context, trackerState: _trackerState);
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: <Widget>[
              // Top Date Navigator & Streak Row
              DateNavigationBar(
                trackerState: _trackerState,
                progress: progress,
                onPreviousDay: () {
                  setState(() {
                    _trackerState.selectedDate =
                        _trackerState.selectedDate.subtract(const Duration(days: 1));
                  });
                  _trackerState.loadForDate(_trackerState.selectedDate).then((_) {
                    if (mounted) setState(() {});
                  });
                },
                onNextDay: () {
                  setState(() {
                    _trackerState.selectedDate =
                        _trackerState.selectedDate.add(const Duration(days: 1));
                  });
                  _trackerState.loadForDate(_trackerState.selectedDate).then((_) {
                    if (mounted) setState(() {});
                  });
                },
                onSelectDate: (DateTime date) {
                  setState(() {
                    _trackerState.selectedDate = date;
                  });
                  _trackerState.loadForDate(date).then((_) {
                    if (mounted) setState(() {});
                  });
                },
                onJumpToToday: () {
                  setState(() {
                    _trackerState.selectedDate = DateTime.now();
                  });
                  _trackerState.loadForDate(_trackerState.selectedDate).then((_) {
                    if (mounted) setState(() {});
                  });
                },
              ),
              const SizedBox(height: 10),

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
                onOpenDetailedNutrition: _openDetailedNutrition,
              ),

              const SizedBox(height: 12),

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
                onQuickAdd: _openQuickAddModal,
                selectedMealType: _trackerState.selectedMealFilter,
              ),

              const SizedBox(height: 14),

              // Meal Category Tabs Filter
              MealCategoryTabs(
                trackerState: _trackerState,
                selectedFilter: _trackerState.selectedMealFilter,
                onSelectFilter: (MealType? type) {
                  setState(() {
                    _trackerState.setMealFilter(type);
                  });
                },
              ),

              const SizedBox(height: 10),

              // Recent Entries List Section
              RecentEntriesSection(
                entries: _trackerState.filteredEntries,
                selectedMealFilter: _trackerState.selectedMealFilter,
                onRemoveEntry: _removeEntry,
                onEditEntry: _editEntry,
                onClearAll: _confirmClearDay,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
