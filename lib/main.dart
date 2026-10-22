import 'package:flutter/material.dart';

import 'features/barcode/data/barcode_scanner_source.dart';
import 'features/barcode/data/open_food_facts_lookup.dart';
import 'features/barcode/domain/barcode_lookup.dart';
import 'features/barcode/domain/product_info.dart';
import 'features/calorie_tracker/data/api_key_storage.dart';
import 'features/calorie_tracker/data/calorie_storage.dart';
import 'features/calorie_tracker/data/chained_calorie_parser.dart';
import 'features/calorie_tracker/data/claude_calorie_parser.dart';
import 'features/calorie_tracker/data/google_ai_calorie_parser.dart';
import 'features/calorie_tracker/data/qwencloud_calorie_parser.dart';
import 'features/calorie_tracker/data/nutrition_label_image_source.dart';
import 'features/calorie_tracker/domain/calorie_parser.dart';
import 'features/calorie_tracker/domain/nutrition_label_image.dart';
import 'features/calorie_tracker/domain/parse_result.dart';
import 'features/calorie_tracker/domain/saved_food.dart';
import 'features/calorie_tracker/domain/saved_food_matcher.dart';
import 'features/calorie_tracker/domain/tracker_state.dart';
import 'features/calorie_tracker/presentation/theme/app_theme.dart';
import 'features/calorie_tracker/presentation/widgets/ai_logger_card.dart';
import 'features/calorie_tracker/presentation/widgets/app_header.dart';
import 'features/calorie_tracker/presentation/widgets/api_key_modal.dart';
import 'features/calorie_tracker/presentation/widgets/date_navigation_bar.dart';
import 'features/calorie_tracker/presentation/widgets/detailed_nutrition_modal.dart';
import 'features/calorie_tracker/presentation/widgets/food_entry_modal.dart';
import 'features/calorie_tracker/presentation/widgets/hero_calorie_card.dart';
import 'features/calorie_tracker/presentation/widgets/meal_category_tabs.dart';
import 'features/calorie_tracker/presentation/widgets/recent_entries_section.dart';
import 'features/calorie_tracker/presentation/widgets/stored_food_portion_modal.dart';
import 'features/calorie_tracker/presentation/widgets/target_editor_modal.dart';

import 'features/weight_tracker/data/weight_storage.dart';
import 'features/weight_tracker/presentation/weight_tracker_page.dart';
import 'features/tdee_calculator/presentation/tdee_calculator_screen.dart';
import 'features/insights/presentation/insights_and_backup_modal.dart';
import 'features/recipes/data/recipe_storage.dart';
import 'features/recipes/domain/recipe.dart';
import 'features/recipes/presentation/recipe_list_modal.dart';

const String _anthropicApiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
const String _claudeApiKey = String.fromEnvironment('CLAUDE_API_KEY');
const String _anthropicBaseUrl = String.fromEnvironment(
  'ANTHROPIC_BASE_URL',
  defaultValue: 'https://api.anthropic.com',
);
const String _claudeModel = String.fromEnvironment(
  'CLAUDE_MODEL',
  defaultValue: 'claude-haiku-5-5',
);
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
const String _googleAiThinkingLevel = String.fromEnvironment('GOOGLE_AI_THINKING_LEVEL');
const String _qwenApiKey = String.fromEnvironment('QWEN_API_KEY');
const String _dashscopeApiKey = String.fromEnvironment('DASHSCOPE_API_KEY');
const String _qwenCloudApiKey = String.fromEnvironment('QWENCLOUD_API_KEY');
const String _qwenCloudBaseUrl = String.fromEnvironment(
  'QWENCLOUD_BASE_URL',
  defaultValue: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
);
const String _qwenCloudModel = String.fromEnvironment(
  'QWENCLOUD_MODEL',
  defaultValue: 'deepseek-v4.1-flash',
);

void main() {
  runApp(const MacroTrackerApp());
}

class MacroTrackerApp extends StatefulWidget {
  const MacroTrackerApp({
    super.key,
    ApiKeyStorage? apiKeyStorage,
    CalorieStorage? calorieStorage,
    WeightStorage? weightStorage,
    RecipeStorage? recipeStorage,
    this.calorieParser,
    this.nutritionLabelImageSource,
    this.barcodeScannerSource,
    this.barcodeLookup,
    this.initialTabIndex = 0,
    this.showOnboarding,
  })  : apiKeyStorage = apiKeyStorage ?? const SecureApiKeyStorage(),
        calorieStorage = calorieStorage ?? const PreferencesCalorieStorage(),
        weightStorage = weightStorage ?? const PreferencesWeightStorage(),
        recipeStorage = recipeStorage ?? const PreferencesRecipeStorage();

  final ApiKeyStorage apiKeyStorage;
  final CalorieStorage calorieStorage;
  final WeightStorage weightStorage;
  final RecipeStorage recipeStorage;
  final CalorieParser? calorieParser;
  final NutritionLabelImageSource? nutritionLabelImageSource;
  final BarcodeScannerSource? barcodeScannerSource;
  final BarcodeLookup? barcodeLookup;
  final int initialTabIndex;
  final bool? showOnboarding;

  @override
  State<MacroTrackerApp> createState() => _MacroTrackerAppState();
}

class _MacroTrackerAppState extends State<MacroTrackerApp> {
  bool _isDarkMode = true;
  bool _hasCompletedOnboarding = true;

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
  }

  Future<void> _loadInitialSettings() async {
    try {
      final UserSettings settings = await widget.calorieStorage.loadSettings();
      if (mounted) {
        setState(() {
          _isDarkMode = settings.isDarkMode;
          _hasCompletedOnboarding = widget.showOnboarding != null
              ? !widget.showOnboarding!
              : settings.hasCompletedOnboarding;
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
    final bool showOnboardingScreen = widget.showOnboarding ?? !_hasCompletedOnboarding;

    return MaterialApp(
      title: 'EZ Macro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(isDarkMode: _isDarkMode),
      home: showOnboardingScreen
          ? TdeeCalculatorScreen(
              calorieStorage: widget.calorieStorage,
              weightStorage: widget.weightStorage,
              isDarkMode: _isDarkMode,
              onComplete: () {
                setState(() {
                  _hasCompletedOnboarding = true;
                });
              },
            )
          : MainNavigationScreen(
              onToggleTheme: _toggleThemeMode,
              isDarkMode: _isDarkMode,
              apiKeyStorage: widget.apiKeyStorage,
              calorieStorage: widget.calorieStorage,
              weightStorage: widget.weightStorage,
              recipeStorage: widget.recipeStorage,
              calorieParser: widget.calorieParser,
              nutritionLabelImageSource: widget.nutritionLabelImageSource,
              barcodeScannerSource: widget.barcodeScannerSource,
              barcodeLookup: widget.barcodeLookup,
              initialIndex: widget.initialTabIndex,
            ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
    required this.apiKeyStorage,
    required this.calorieStorage,
    required this.weightStorage,
    required this.recipeStorage,
    this.calorieParser,
    this.nutritionLabelImageSource,
    this.barcodeScannerSource,
    this.barcodeLookup,
    this.initialIndex = 0,
  });

  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final ApiKeyStorage apiKeyStorage;
  final CalorieStorage calorieStorage;
  final WeightStorage weightStorage;
  final RecipeStorage recipeStorage;
  final CalorieParser? calorieParser;
  final NutritionLabelImageSource? nutritionLabelImageSource;
  final BarcodeScannerSource? barcodeScannerSource;
  final BarcodeLookup? barcodeLookup;
  final int initialIndex;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;

    final Widget navBar = Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackgroundGrad2 : AppColors.lightSurface,
        border: Border(
          top: BorderSide(color: AppColors.border(isDark)),
        ),
      ),
      child: NavigationBar(
        key: const Key('mainBottomNavigationBar'),
        selectedIndex: _currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            key: Key('navDestinationCalories'),
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded),
            label: 'Calories',
          ),
          NavigationDestination(
            key: Key('navDestinationWeight'),
            icon: Icon(Icons.monitor_weight_outlined),
            selectedIcon: Icon(Icons.monitor_weight_rounded),
            label: 'Weight',
          ),
        ],
      ),
    );

    final List<Widget> pages = <Widget>[
      CalorieHomePage(
        onToggleTheme: widget.onToggleTheme,
        isDarkMode: widget.isDarkMode,
        apiKeyStorage: widget.apiKeyStorage,
        calorieStorage: widget.calorieStorage,
        weightStorage: widget.weightStorage,
        recipeStorage: widget.recipeStorage,
        calorieParser: widget.calorieParser,
        nutritionLabelImageSource: widget.nutritionLabelImageSource,
        barcodeScannerSource: widget.barcodeScannerSource,
        barcodeLookup: widget.barcodeLookup,
        bottomNavigationBar: navBar,
      ),
      WeightTrackerPage(
        onToggleTheme: widget.onToggleTheme,
        isDarkMode: widget.isDarkMode,
        weightStorage: widget.weightStorage,
        bottomNavigationBar: navBar,
      ),
    ];

    return IndexedStack(
      index: _currentIndex,
      children: pages,
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
    WeightStorage? weightStorage,
    RecipeStorage? recipeStorage,
    this.calorieParser,
    this.nutritionLabelImageSource,
    this.barcodeScannerSource,
    this.barcodeLookup,
    this.bottomNavigationBar,
  })  : apiKeyStorage = apiKeyStorage ?? const SecureApiKeyStorage(),
        calorieStorage = calorieStorage ?? const PreferencesCalorieStorage(),
        weightStorage = weightStorage ?? const PreferencesWeightStorage(),
        recipeStorage = recipeStorage ?? const PreferencesRecipeStorage();

  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final ApiKeyStorage apiKeyStorage;
  final CalorieStorage calorieStorage;
  final WeightStorage weightStorage;
  final RecipeStorage recipeStorage;
  final CalorieParser? calorieParser;
  final NutritionLabelImageSource? nutritionLabelImageSource;
  final BarcodeScannerSource? barcodeScannerSource;
  final BarcodeLookup? barcodeLookup;
  final Widget? bottomNavigationBar;

  @override
  State<CalorieHomePage> createState() => _CalorieHomePageState();
}

class _CalorieHomePageState extends State<CalorieHomePage> {
  late final CalorieTrackerState _trackerState;
  String? _userApiKey;
  String? _userQwenApiKey;
  String? _userClaudeApiKey;
  late CalorieParser _calorieParser = _buildParser();
  final CalorieParser _fallbackParser = const RegexCalorieParser();
  final TextEditingController _nlInputController = TextEditingController();
  bool _isParsing = false;
  bool _lastUsedFallback = false;
  String? _lastParseSource;
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
    await widget.calorieStorage.saveSavedFood(food);
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
      final String? qwenKey = await widget.apiKeyStorage.getQwenApiKey();
      final String? claudeKey = await widget.apiKeyStorage.getClaudeApiKey();
      if (!mounted) {
        return;
      }
      final bool hasGemini = key != null && key.isNotEmpty;
      final bool hasQwen = qwenKey != null && qwenKey.isNotEmpty;
      final bool hasClaude = claudeKey != null && claudeKey.isNotEmpty;
      if (hasGemini || hasQwen || hasClaude) {
        setState(() {
          if (hasClaude) {
            _userClaudeApiKey = claudeKey;
          }
          if (hasGemini) {
            _userApiKey = key;
          }
          if (hasQwen) {
            _userQwenApiKey = qwenKey;
          }
          _calorieParser = _buildParser();
        });
      }
    } catch (_) {
      // Gracefully handle any platform or storage read failures
    }
  }

  bool get _hasConfiguredApiKey =>
      _resolveClaudeApiKey().isNotEmpty ||
      _resolveApiKey().isNotEmpty ||
      _resolveQwenApiKey().isNotEmpty;

  BarcodeScannerSource get _barcodeScannerSource =>
      widget.barcodeScannerSource ?? const DeviceBarcodeScannerSource();

  BarcodeLookup get _barcodeLookup =>
      widget.barcodeLookup ?? OpenFoodFactsBarcodeLookup();

  Future<ProductInfo?> _lookupBarcode(String barcode) {
    return _barcodeLookup.lookup(barcode);
  }

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
    double portionSize = 1.0,
    String portionUnit = 'serving',
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
        portionSize: portionSize,
        portionUnit: portionUnit,
        rangeText: rangeText,
        sourceLabel: sourceLabel,
        spreadPercent: spreadPercent,
        mealType: mealType,
      );
    });
  }

  /// [index] is a position in [CalorieTrackerState.filteredEntries], which is
  /// what the food log shows.
  void _removeEntry(int index) {
    if (index < 0 || index >= _trackerState.filteredEntries.length) return;
    _removeEntryWithUndo(_trackerState.filteredEntries[index]);
  }

  void _removeEntryWithUndo(FoodLogEntry entry) {
    final int position = _trackerState.entries.indexWhere((FoodLogEntry e) => e.id == entry.id);
    if (position == -1) return;
    final DateTime day = _trackerState.selectedDate;

    setState(() {
      _trackerState.removeEntryAt(position);
    });
    _showUndoSnackBar(
      'Removed ${entry.mealLabel}.',
      () => _trackerState.restoreEntries(<FoodLogEntry>[entry], date: day, index: position),
    );
  }

  void _showUndoSnackBar(String message, Future<void> Function() undo) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          key: const Key('undoRemoveButton'),
          label: 'Undo',
          onPressed: () async {
            await undo();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  Future<void> _logEntryAgain(int index) async {
    if (index < 0 || index >= _trackerState.filteredEntries.length) return;
    final FoodLogEntry source = _trackerState.filteredEntries[index];
    final bool wasViewingToday = _trackerState.isToday;

    if (!wasViewingToday) {
      setState(() {
        _trackerState.selectedDate = DateTime.now();
      });
      await _trackerState.loadForDate(DateTime.now());
      if (!mounted) return;
    }

    setState(() {
      _trackerState.addCopiedEntries(<FoodLogEntry>[source]);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasViewingToday
              ? 'Logged ${source.mealLabel} again.'
              : 'Logged ${source.mealLabel} to today.',
        ),
      ),
    );
  }

  Future<void> _copyDayToToday() async {
    if (_trackerState.isToday || _trackerState.entries.isEmpty) return;

    final String sourceLabel = _trackerState.formattedDate;
    final int count = _trackerState.entries.length;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Copy Day to Today?'),
          content: Text(
            'Copy $count ${count == 1 ? 'entry' : 'entries'} from $sourceLabel '
            'to today? Entries already logged today will be kept.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirmCopyDayButton'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Copy'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final List<FoodLogEntry> sourceEntries =
        List<FoodLogEntry>.from(_trackerState.entries);

    setState(() {
      _trackerState.selectedDate = DateTime.now();
    });
    await _trackerState.loadForDate(DateTime.now());
    if (!mounted) return;

    setState(() {
      _trackerState.addCopiedEntries(sourceEntries);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $count ${count == 1 ? 'entry' : 'entries'} to today.')),
    );
  }

  Future<void> _editEntry(int index) async {
    if (index < 0 || index >= _trackerState.filteredEntries.length) return;
    final FoodLogEntry target = _trackerState.filteredEntries[index];

    final dynamic result = await FoodEntryModal.showEdit(
      context,
      target,
      savedFoods: _savedFoods,
      onSaveFood: _saveFoodForFutureUse,
      onDeleteSavedFood: _deleteSavedFood,
      nutritionLabelImageSource: widget.nutritionLabelImageSource,
      hasConfiguredApiKey: _hasConfiguredApiKey,
      barcodeScannerSource: _barcodeScannerSource,
      onLookupBarcode: _lookupBarcode,
      recipeStorage: widget.recipeStorage,
      onParseNutritionLabel: (
        NutritionLabelImage image, {
        String? hint,
      }) {
        return _calorieParser.parseNutritionLabel(image, hint: hint);
      },
    );
    if (result == null || !mounted) return;

    if (result == 'delete') {
      _removeEntryWithUndo(target);
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
      barcodeScannerSource: _barcodeScannerSource,
      onLookupBarcode: _lookupBarcode,
      recipeStorage: widget.recipeStorage,
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
        portionSize: result.portionSize,
        portionUnit: result.portionUnit,
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
      final List<FoodLogEntry> cleared = List<FoodLogEntry>.of(_trackerState.entries);
      final DateTime day = _trackerState.selectedDate;
      setState(() {
        _trackerState.clearCurrentDay();
      });
      _showUndoSnackBar(
        'Day log cleared.',
        () => _trackerState.restoreEntries(cleared, date: day),
      );
    }
  }

  CalorieParser _buildParser() {
    if (widget.calorieParser != null) {
      return widget.calorieParser!;
    }

    final List<CalorieParser> parsers = <CalorieParser>[];
    final String claudeKey = _resolveClaudeApiKey();
    if (claudeKey.isNotEmpty) {
      parsers.add(
        ClaudeCalorieParser(
          apiKey: claudeKey,
          model: _claudeModel,
          baseUrl: _anthropicBaseUrl,
        ),
      );
    }

    final String geminiKey = _resolveApiKey();
    if (geminiKey.isNotEmpty) {
      parsers.add(
        GoogleAiCalorieParser(
          apiKey: geminiKey,
          model: _googleAiModel,
          baseUrl: _googleAiBaseUrl,
          thinkingConfig: _googleAiThinkingLevel.isNotEmpty
              ? <String, Object>{'thinkingLevel': _googleAiThinkingLevel}
              : null,
        ),
      );
    }

    final String qwenKey = _resolveQwenApiKey();
    if (qwenKey.isNotEmpty) {
      parsers.add(
        QwenCloudCalorieParser(
          apiKey: qwenKey,
          model: _qwenCloudModel,
          baseUrl: _qwenCloudBaseUrl,
        ),
      );
    }

    if (parsers.isEmpty) {
      return const RegexCalorieParser();
    }
    if (parsers.length == 1) {
      return parsers.first;
    }
    return ChainedCalorieParser(parsers);
  }

  String _resolveClaudeApiKey() {
    if (_userClaudeApiKey != null && _userClaudeApiKey!.isNotEmpty) {
      return _userClaudeApiKey!;
    }
    return _resolveEnvClaudeApiKey();
  }

  String _resolveEnvClaudeApiKey() {
    if (_anthropicApiKey.isNotEmpty) {
      return _anthropicApiKey;
    }
    return _claudeApiKey;
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

  String _resolveQwenApiKey() {
    if (_userQwenApiKey != null && _userQwenApiKey!.isNotEmpty) {
      return _userQwenApiKey!;
    }
    return _resolveEnvQwenApiKey();
  }

  String _resolveEnvQwenApiKey() {
    if (_qwenApiKey.isNotEmpty) {
      return _qwenApiKey;
    }
    if (_dashscopeApiKey.isNotEmpty) {
      return _dashscopeApiKey;
    }
    return _qwenCloudApiKey;
  }

  Future<void> _openApiKeyModal() async {
    final ApiKeyModalResult? updated = await ApiKeyModal.show(
      context,
      storage: widget.apiKeyStorage,
      currentKey: _userApiKey,
      envKey: _resolveEnvApiKey(),
      currentQwenKey: _userQwenApiKey,
      envQwenKey: _resolveEnvQwenApiKey(),
      currentClaudeKey: _userClaudeApiKey,
      envClaudeKey: _resolveEnvClaudeApiKey(),
    );
    if (updated != null && mounted) {
      setState(() {
        _userClaudeApiKey = updated.claudeKey;
        _userApiKey = updated.geminiKey;
        _userQwenApiKey = updated.qwenKey;
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

    // 1. Check local saved foods first to avoid calling LLM
    final ParseResult? savedMatch =
        SavedFoodMatcher.findMatch(rawInput, _savedFoods);

    ParseResult? result;
    bool usedFallback = false;
    bool fromSaved = false;

    if (savedMatch != null) {
      result = savedMatch;
      fromSaved = true;
    } else {
      final ParseResult? primaryResult = await _calorieParser.parse(rawInput);
      result = primaryResult;
      if (result == null) {
        result = await _fallbackParser.parse(rawInput);
        usedFallback = result != null;
      }
    }

    if (!mounted) {
      return;
    }

    // 2. Autosave item if confidence is >= 90% (0.90) and was not already matched from saved foods
    if (result != null && !fromSaved && result.confidence >= 0.90) {
      final SavedFood autoSavedFood = SavedFood(
        name: result.mealLabel,
        calories: result.calories,
        proteinG: result.proteinG,
        carbsG: result.carbsG,
        fatG: result.fatG,
        saturatedFatG: result.saturatedFatG,
        fiberG: result.fiberG,
        addedSugarG: result.addedSugarG,
        sodiumMg: result.sodiumMg,
        portionSize: result.portionSize,
        portionUnit: result.portionUnit,
      );
      await _saveFoodForFutureUse(autoSavedFood);
    }

    if (!mounted) {
      return;
    }

    final String sourceLabel = fromSaved
        ? 'Saved'
        : (usedFallback ? 'Local' : 'AI');

    setState(() {
      _isParsing = false;
      _lastParse = result;
      _lastUsedFallback = usedFallback;
      _lastParseSource = sourceLabel;
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
      portionSize: result.portionSize,
      portionUnit: result.portionUnit,
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

  Future<void> _handleSelectSavedFood(SavedFood food) async {
    _onSelectSuggestion(food.name);
    final FoodLogEntry? result = await StoredFoodPortionModal.show(
      context,
      food: food,
      defaultMealType: _trackerState.selectedMealFilter ?? MealType.forTime(),
      onOpenFullEdit: () async {
          Navigator.of(context).pop();
          final FoodLogEntry? manualResult = await FoodEntryModal.showAdd(
            context,
            defaultMealType: _trackerState.selectedMealFilter ?? MealType.forTime(),
            savedFoods: _savedFoods,
            onSaveFood: _saveFoodForFutureUse,
            onDeleteSavedFood: _deleteSavedFood,
            nutritionLabelImageSource: widget.nutritionLabelImageSource,
            hasConfiguredApiKey: _hasConfiguredApiKey,
            barcodeScannerSource: _barcodeScannerSource,
            onLookupBarcode: _lookupBarcode,
            onParseNutritionLabel: (
            NutritionLabelImage image, {
            String? hint,
          }) {
            return _calorieParser.parseNutritionLabel(image, hint: hint);
          },
        );
        if (manualResult != null && mounted) {
          _addCalories(
            manualResult.calories,
            manualResult.mealLabel,
            proteinG: manualResult.proteinG,
            carbsG: manualResult.carbsG,
            fatG: manualResult.fatG,
            saturatedFatG: manualResult.saturatedFatG,
            fiberG: manualResult.fiberG,
            addedSugarG: manualResult.addedSugarG,
            sodiumMg: manualResult.sodiumMg,
            portionSize: manualResult.portionSize,
            portionUnit: manualResult.portionUnit,
            sourceLabel: manualResult.sourceLabel ?? 'Manual',
            mealType: manualResult.mealType,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logged ${manualResult.mealLabel} (${manualResult.calories} kcal).'),
            ),
          );
        }
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
        portionSize: result.portionSize,
        portionUnit: result.portionUnit,
        sourceLabel: result.sourceLabel ?? 'Saved',
        mealType: result.mealType,
      );
      _nlInputController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged ${result.mealLabel} (${result.calories} kcal).'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nlInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      bottomNavigationBar: widget.bottomNavigationBar,
      appBar: AppBar(
        toolbarHeight: 62,
        titleSpacing: 16,
        actionsPadding: const EdgeInsets.only(right: 12),
        title: const AppHeaderTitle(icon: Icons.eco_rounded, title: 'EZ Macro'),
        actions: <Widget>[
          HeaderActionButton(
            key: const Key('openApiKeyModalButton'),
            onPressed: _openApiKeyModal,
            icon: Icons.key_rounded,
            iconColor: _hasConfiguredApiKey ? AppColors.success : null,
            tooltip: 'Configure AI API Keys',
          ),
          HeaderActionButton(
            key: const Key('openRecipesModalButton'),
            onPressed: () {
              RecipeListModal.show(
                context,
                recipeStorage: widget.recipeStorage,
                savedFoods: _savedFoods,
                defaultMealType: _trackerState.selectedMealFilter ?? MealType.forTime(),
                onLogRecipe: (Recipe recipe, double servings, MealType mealType) {
                  final FoodLogEntry entry = recipe.toFoodLogEntry(
                    loggedServings: servings,
                    mealType: mealType,
                  );
                  _addCalories(
                    entry.calories,
                    entry.mealLabel,
                    proteinG: entry.proteinG,
                    carbsG: entry.carbsG,
                    fatG: entry.fatG,
                    saturatedFatG: entry.saturatedFatG,
                    fiberG: entry.fiberG,
                    addedSugarG: entry.addedSugarG,
                    sodiumMg: entry.sodiumMg,
                    portionSize: entry.portionSize,
                    portionUnit: entry.portionUnit,
                    sourceLabel: entry.sourceLabel ?? 'Recipe',
                    mealType: entry.mealType,
                  );
                },
              );
            },
            icon: Icons.menu_book_rounded,
            tooltip: 'Recipes & Meal Templates',
          ),
          HeaderActionButton(
            key: const Key('openInsightsModalButton'),
            onPressed: () {
              InsightsAndBackupModal.show(
                context,
                calorieStorage: widget.calorieStorage,
                weightStorage: widget.weightStorage,
                recipeStorage: widget.recipeStorage,
                onDataRestored: () {
                  _initTrackerData();
                  _loadSavedFoods();
                },
              );
            },
            icon: Icons.insights_rounded,
            tooltip: 'Weekly Insights & Backup',
          ),
          HeaderActionButton(
            key: const Key('toggleThemeButton'),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle theme',
            child: AnimatedSwitcher(
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
                size: 19,
                color: widget.isDarkMode ? AppColors.carbs : AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: <Widget>[
              // Top Date Navigator & Streak Row
              DateNavigationBar(
                trackerState: _trackerState,
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
                lastParseSource: _lastParseSource,
                showSpreadDetails: _showSpreadDetails,
                onParse: _parseAndLogMeal,
                onSelectSuggestion: _onSelectSuggestion,
                onConfigureApiKey: _openApiKeyModal,
                onQuickAdd: _openQuickAddModal,
                selectedMealType: _trackerState.selectedMealFilter,
                savedFoods: _savedFoods,
                onSelectSavedFood: _handleSelectSavedFood,
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
                onLogAgain: _logEntryAgain,
                onCopyDayToToday:
                    _trackerState.isToday ? null : _copyDayToToday,
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
