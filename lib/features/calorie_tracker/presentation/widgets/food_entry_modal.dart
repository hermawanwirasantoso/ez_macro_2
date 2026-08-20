import 'package:flutter/material.dart';
import '../../data/nutrition_label_image_source.dart';
import '../../domain/daily_log.dart';
import '../../domain/meal_type.dart';
import '../../domain/nutrition_label_image.dart';
import '../../domain/parse_result.dart';
import '../../domain/saved_food.dart';
import '../theme/app_theme.dart';

typedef NutritionLabelParseCallback = Future<ParseResult?> Function(
  NutritionLabelImage image, {
  String? hint,
});

/// Modal dialog for manually creating or editing a food log entry.
class FoodEntryModal extends StatefulWidget {
  const FoodEntryModal({
    super.key,
    this.initialEntry,
    this.initialMealType,
    this.savedFoods = const <SavedFood>[],
    this.onSaveFood,
    this.onDeleteSavedFood,
    this.nutritionLabelImageSource,
    this.onParseNutritionLabel,
    this.hasConfiguredApiKey = false,
  });

  final FoodLogEntry? initialEntry;
  final MealType? initialMealType;
  final List<SavedFood> savedFoods;
  final Future<void> Function(SavedFood food)? onSaveFood;
  final Future<void> Function(SavedFood food)? onDeleteSavedFood;
  final NutritionLabelImageSource? nutritionLabelImageSource;
  final NutritionLabelParseCallback? onParseNutritionLabel;
  final bool hasConfiguredApiKey;

  static Future<FoodLogEntry?> showAdd(
    BuildContext context, {
    MealType? defaultMealType,
    List<SavedFood> savedFoods = const <SavedFood>[],
    Future<void> Function(SavedFood food)? onSaveFood,
    Future<void> Function(SavedFood food)? onDeleteSavedFood,
    NutritionLabelImageSource? nutritionLabelImageSource,
    NutritionLabelParseCallback? onParseNutritionLabel,
    bool hasConfiguredApiKey = false,
  }) {
    return showModalBottomSheet<FoodLogEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => FoodEntryModal(
        initialMealType: defaultMealType ?? MealType.forTime(),
        savedFoods: savedFoods,
        onSaveFood: onSaveFood,
        onDeleteSavedFood: onDeleteSavedFood,
        nutritionLabelImageSource: nutritionLabelImageSource,
        onParseNutritionLabel: onParseNutritionLabel,
        hasConfiguredApiKey: hasConfiguredApiKey,
      ),
    );
  }

  static Future<dynamic> showEdit(
    BuildContext context,
    FoodLogEntry entry, {
    List<SavedFood> savedFoods = const <SavedFood>[],
    Future<void> Function(SavedFood food)? onSaveFood,
    Future<void> Function(SavedFood food)? onDeleteSavedFood,
    NutritionLabelImageSource? nutritionLabelImageSource,
    NutritionLabelParseCallback? onParseNutritionLabel,
    bool hasConfiguredApiKey = false,
  }) {
    return showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => FoodEntryModal(
        initialEntry: entry,
        savedFoods: savedFoods,
        onSaveFood: onSaveFood,
        onDeleteSavedFood: onDeleteSavedFood,
        nutritionLabelImageSource: nutritionLabelImageSource,
        onParseNutritionLabel: onParseNutritionLabel,
        hasConfiguredApiKey: hasConfiguredApiKey,
      ),
    );
  }

  @override
  State<FoodEntryModal> createState() => _FoodEntryModalState();
}

class _FoodEntryModalState extends State<FoodEntryModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _calController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _saturatedFatController;
  late final TextEditingController _fiberController;
  late final TextEditingController _addedSugarController;
  late final TextEditingController _sodiumController;
  late final TextEditingController _portionQuantityController;
  late final TextEditingController _savePortionSizeController;
  late final TextEditingController _savePortionUnitController;
  late MealType _selectedMealType;
  late List<SavedFood> _savedFoods;
  String? _selectedSavedFoodId;
  SavedFood? _selectedSavedFood;
  String? _errorMessage;
  bool _saveForFutureUse = false;
  bool _isSaving = false;
  bool _isScanningLabel = false;
  bool _filledFromLabel = false;
  bool _showDetailedNutrition = false;

  // Base nutrition values for portion scaling
  int _baseCalories = 0;
  int _baseProtein = 0;
  int _baseCarbs = 0;
  int _baseFat = 0;
  int _baseSaturatedFat = 0;
  int _baseFiber = 0;
  int _baseAddedSugar = 0;
  int _baseSodium = 0;
  double _basePortionSize = 1.0;
  String _basePortionUnit = 'serving';
  double _currentPortionMultiplier = 1.0;

  bool get _isEditing => widget.initialEntry != null;

  String get _basePortionDisplay {
    final String sizeStr = _basePortionSize == _basePortionSize.toInt().toDouble()
        ? '${_basePortionSize.toInt()}'
        : _basePortionSize.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    final String unitStr =
        _basePortionUnit.trim().isEmpty ? 'serving' : _basePortionUnit.trim();
    if (unitStr.toLowerCase() == 'serving' ||
        unitStr.toLowerCase() == 'portion') {
      if (_basePortionSize == 1.0) {
        return '1 $unitStr';
      } else {
        return '$sizeStr ${unitStr}s';
      }
    }
    return '$sizeStr $unitStr';
  }

  @override
  void initState() {
    super.initState();
    final FoodLogEntry? entry = widget.initialEntry;
    _nameController = TextEditingController(text: entry?.mealLabel ?? '');
    _calController =
        TextEditingController(text: entry != null ? '${entry.calories}' : '');
    _proteinController =
        TextEditingController(text: entry != null ? '${entry.proteinG}' : '0');
    _carbsController =
        TextEditingController(text: entry != null ? '${entry.carbsG}' : '0');
    _fatController =
        TextEditingController(text: entry != null ? '${entry.fatG}' : '0');
    _saturatedFatController = TextEditingController(
        text: entry != null ? '${entry.saturatedFatG}' : '0');
    _fiberController =
        TextEditingController(text: entry != null ? '${entry.fiberG}' : '0');
    _addedSugarController =
        TextEditingController(text: entry != null ? '${entry.addedSugarG}' : '0');
    _sodiumController =
        TextEditingController(text: entry != null ? '${entry.sodiumMg}' : '0');
    _showDetailedNutrition = entry != null &&
        (entry.saturatedFatG > 0 ||
            entry.fiberG > 0 ||
            entry.addedSugarG > 0 ||
            entry.sodiumMg > 0);

    if (entry != null) {
      _baseCalories = entry.calories;
      _baseProtein = entry.proteinG;
      _baseCarbs = entry.carbsG;
      _baseFat = entry.fatG;
      _baseSaturatedFat = entry.saturatedFatG;
      _baseFiber = entry.fiberG;
      _baseAddedSugar = entry.addedSugarG;
      _baseSodium = entry.sodiumMg;
      _basePortionSize = entry.portionSize > 0 ? entry.portionSize : 1.0;
      _basePortionUnit = entry.portionUnit.trim().isNotEmpty
          ? entry.portionUnit.trim()
          : 'serving';
    }

    final String portionStr =
        _basePortionSize == _basePortionSize.toInt().toDouble()
            ? '${_basePortionSize.toInt()}'
            : '$_basePortionSize';
    _portionQuantityController = TextEditingController(text: portionStr);
    _savePortionSizeController = TextEditingController(text: portionStr);
    _savePortionUnitController = TextEditingController(text: _basePortionUnit);
    _selectedMealType =
        entry?.mealType ?? widget.initialMealType ?? MealType.forTime();
    _savedFoods = List<SavedFood>.from(widget.savedFoods);
  }

  void _syncBaseNutritionFromInputs() {
    if (_currentPortionMultiplier > 0) {
      _baseCalories =
          ((int.tryParse(_calController.text.trim()) ?? 0) / _currentPortionMultiplier)
              .round();
      _baseProtein =
          ((int.tryParse(_proteinController.text.trim()) ?? 0) /
                  _currentPortionMultiplier)
              .round();
      _baseCarbs =
          ((int.tryParse(_carbsController.text.trim()) ?? 0) /
                  _currentPortionMultiplier)
              .round();
      _baseFat =
          ((int.tryParse(_fatController.text.trim()) ?? 0) /
                  _currentPortionMultiplier)
              .round();
      _baseSaturatedFat =
          ((int.tryParse(_saturatedFatController.text.trim()) ?? 0) /
                  _currentPortionMultiplier)
              .round();
      _baseFiber =
          ((int.tryParse(_fiberController.text.trim()) ?? 0) /
                  _currentPortionMultiplier)
              .round();
      _baseAddedSugar =
          ((int.tryParse(_addedSugarController.text.trim()) ?? 0) /
                  _currentPortionMultiplier)
              .round();
      _baseSodium =
          ((int.tryParse(_sodiumController.text.trim()) ?? 0) /
                  _currentPortionMultiplier)
              .round();
    }
  }

  void _calculateCaloriesFromMacros() {
    final int p = int.tryParse(_proteinController.text.trim()) ?? 0;
    final int c = int.tryParse(_carbsController.text.trim()) ?? 0;
    final int f = int.tryParse(_fatController.text.trim()) ?? 0;
    final int calculated = (p * 4) + (c * 4) + (f * 9);
    setState(() {
      _calController.text = calculated.toString();
      _syncBaseNutritionFromInputs();
    });
  }

  void _useSavedFood(SavedFood food) {
    setState(() {
      _selectedSavedFoodId = food.id;
      _selectedSavedFood = food;
      _baseCalories = food.calories;
      _baseProtein = food.proteinG;
      _baseCarbs = food.carbsG;
      _baseFat = food.fatG;
      _baseSaturatedFat = food.saturatedFatG;
      _baseFiber = food.fiberG;
      _baseAddedSugar = food.addedSugarG;
      _baseSodium = food.sodiumMg;
      _basePortionSize = food.portionSize > 0 ? food.portionSize : 1.0;
      _basePortionUnit = food.portionUnit.trim().isNotEmpty ? food.portionUnit.trim() : 'serving';
      _currentPortionMultiplier = 1.0;

      final String portionStr = _basePortionSize == _basePortionSize.toInt().toDouble()
          ? '${_basePortionSize.toInt()}'
          : '$_basePortionSize';
      _portionQuantityController.text = portionStr;

      _nameController.text = food.name;
      _calController.text = food.calories.toString();
      _proteinController.text = food.proteinG.toString();
      _carbsController.text = food.carbsG.toString();
      _fatController.text = food.fatG.toString();
      _saturatedFatController.text = food.saturatedFatG.toString();
      _fiberController.text = food.fiberG.toString();
      _addedSugarController.text = food.addedSugarG.toString();
      _sodiumController.text = food.sodiumMg.toString();
      if (food.saturatedFatG > 0 ||
          food.fiberG > 0 ||
          food.addedSugarG > 0 ||
          food.sodiumMg > 0) {
        _showDetailedNutrition = true;
      }
      _saveForFutureUse = false;
      _filledFromLabel = false;
      _errorMessage = null;
    });
  }

  void _setPortionMultiplier(double multiplier) {
    if (multiplier <= 0) return;
    final double targetQuantity = multiplier * _basePortionSize;
    final String portionStr = targetQuantity == targetQuantity.toInt().toDouble()
        ? '${targetQuantity.toInt()}'
        : targetQuantity.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

    setState(() {
      _currentPortionMultiplier = multiplier;
      _portionQuantityController.text = portionStr;
      _scaleNutrition(multiplier);
    });
  }

  void _onPortionQuantityChanged(String value) {
    final double? parsedQuantity = double.tryParse(value.trim());
    if (parsedQuantity != null && parsedQuantity > 0 && _basePortionSize > 0) {
      final double multiplier = parsedQuantity / _basePortionSize;
      setState(() {
        _currentPortionMultiplier = multiplier;
        _scaleNutrition(multiplier);
      });
    }
  }

  void _adjustPortion(double delta) {
    final double currentQuantity =
        double.tryParse(_portionQuantityController.text.trim()) ?? _basePortionSize;
    double newQuantity = currentQuantity + delta;
    if (newQuantity < 0.1) {
      newQuantity = 0.1;
    }
    final String portionStr = newQuantity == newQuantity.toInt().toDouble()
        ? '${newQuantity.toInt()}'
        : newQuantity.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

    setState(() {
      _portionQuantityController.text = portionStr;
      if (_basePortionSize > 0) {
        final double multiplier = newQuantity / _basePortionSize;
        _currentPortionMultiplier = multiplier;
        _scaleNutrition(multiplier);
      }
    });
  }

  void _scaleNutrition(double multiplier) {
    final int scaledCal = (_baseCalories * multiplier).round().clamp(0, 99999);
    final int scaledProtein = (_baseProtein * multiplier).round().clamp(0, 9999);
    final int scaledCarbs = (_baseCarbs * multiplier).round().clamp(0, 9999);
    final int scaledFat = (_baseFat * multiplier).round().clamp(0, 9999);
    final int scaledSatFat = (_baseSaturatedFat * multiplier).round().clamp(0, 9999);
    final int scaledFiber = (_baseFiber * multiplier).round().clamp(0, 9999);
    final int scaledAddedSugar = (_baseAddedSugar * multiplier).round().clamp(0, 9999);
    final int scaledSodium = (_baseSodium * multiplier).round().clamp(0, 99999);

    _calController.text = scaledCal.toString();
    _proteinController.text = scaledProtein.toString();
    _carbsController.text = scaledCarbs.toString();
    _fatController.text = scaledFat.toString();
    _saturatedFatController.text = scaledSatFat.toString();
    _fiberController.text = scaledFiber.toString();
    _addedSugarController.text = scaledAddedSugar.toString();
    _sodiumController.text = scaledSodium.toString();
  }

  Future<void> _scanNutritionLabel() async {
    if (_isScanningLabel || _isSaving) {
      return;
    }

    if (!widget.hasConfiguredApiKey || widget.onParseNutritionLabel == null) {
      setState(() {
        _errorMessage = 'Add a Google AI key to scan nutrition labels.';
      });
      return;
    }

    final NutritionLabelPickSource? source = await showModalBottomSheet<NutritionLabelPickSource>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                key: const Key('scanFromCameraOption'),
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                subtitle: const Text('Capture the nutrition facts panel'),
                onTap: () => Navigator.of(context).pop(NutritionLabelPickSource.camera),
              ),
              ListTile(
                key: const Key('scanFromGalleryOption'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Use an existing label photo'),
                onTap: () => Navigator.of(context).pop(NutritionLabelPickSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    setState(() {
      _isScanningLabel = true;
      _errorMessage = null;
    });

    try {
      final NutritionLabelImageSource imageSource =
          widget.nutritionLabelImageSource ?? NutritionLabelImageSource.device();
      final NutritionLabelImage? image = await imageSource.pick(source: source);
      if (!mounted) {
        return;
      }
      if (image == null || image.isEmpty) {
        setState(() {
          _isScanningLabel = false;
          _errorMessage = 'No photo selected. Try again to scan a nutrition label.';
        });
        return;
      }

      final ParseResult? result = await widget.onParseNutritionLabel!(
        image,
        hint: _nameController.text.trim(),
      );
      if (!mounted) {
        return;
      }

      if (result == null) {
        setState(() {
          _isScanningLabel = false;
          _errorMessage =
              'Could not read this nutrition label. Try a clearer photo of the facts panel.';
        });
        return;
      }

      setState(() {
        _isScanningLabel = false;
        _filledFromLabel = true;
        _selectedSavedFoodId = null;
        _selectedSavedFood = null;
        _baseCalories = result.calories;
        _baseProtein = result.proteinG;
        _baseCarbs = result.carbsG;
        _baseFat = result.fatG;
        _baseSaturatedFat = result.saturatedFatG;
        _baseFiber = result.fiberG;
        _baseAddedSugar = result.addedSugarG;
        _baseSodium = result.sodiumMg;
        _basePortionSize = result.portionSize > 0 ? result.portionSize : 1.0;
        _basePortionUnit = result.portionUnit.trim().isNotEmpty
            ? result.portionUnit.trim()
            : 'serving';
        _currentPortionMultiplier = 1.0;

        final String portionStr =
            _basePortionSize == _basePortionSize.toInt().toDouble()
                ? '${_basePortionSize.toInt()}'
                : '$_basePortionSize';
        _portionQuantityController.text = portionStr;
        _savePortionSizeController.text = portionStr;
        _savePortionUnitController.text = _basePortionUnit;

        _nameController.text = result.mealLabel;
        _calController.text = result.calories.toString();
        _proteinController.text = result.proteinG.toString();
        _carbsController.text = result.carbsG.toString();
        _fatController.text = result.fatG.toString();
        _saturatedFatController.text = result.saturatedFatG.toString();
        _fiberController.text = result.fiberG.toString();
        _addedSugarController.text = result.addedSugarG.toString();
        _sodiumController.text = result.sodiumMg.toString();
        if (result.saturatedFatG > 0 ||
            result.fiberG > 0 ||
            result.addedSugarG > 0 ||
            result.sodiumMg > 0) {
          _showDetailedNutrition = true;
        }
        if (result.confidence >= 0.90) {
          _saveForFutureUse = true;
        }
        _errorMessage = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isScanningLabel = false;
          _errorMessage =
              'Could not read this nutrition label. Try a clearer photo of the facts panel.';
        });
      }
    }
  }

  Future<void> _removeSavedFood(SavedFood food) async {
    try {
      if (widget.onDeleteSavedFood != null) {
        await widget.onDeleteSavedFood!(food);
      }
      if (mounted) {
        setState(() {
          _savedFoods.removeWhere((SavedFood item) => item.id == food.id);
          if (_selectedSavedFoodId == food.id) {
            _selectedSavedFoodId = null;
            _selectedSavedFood = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not remove this saved food. Please try again.';
        });
      }
    }
  }

  Future<void> _onSave() async {
    if (_isSaving) return;

    final String name = _nameController.text.trim();
    final int? calories = int.tryParse(_calController.text.trim());
    final int protein = int.tryParse(_proteinController.text.trim()) ?? 0;
    final int carbs = int.tryParse(_carbsController.text.trim()) ?? 0;
    final int fat = int.tryParse(_fatController.text.trim()) ?? 0;
    final int saturatedFat = int.tryParse(_saturatedFatController.text.trim()) ?? 0;
    final int fiber = int.tryParse(_fiberController.text.trim()) ?? 0;
    final int addedSugar = int.tryParse(_addedSugarController.text.trim()) ?? 0;
    final int sodium = int.tryParse(_sodiumController.text.trim()) ?? 0;

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a food or meal name.';
      });
      return;
    }

    if (calories == null || calories <= 0) {
      setState(() {
        _errorMessage = 'Please enter valid calories (> 0).';
      });
      return;
    }

    if (protein < 0 ||
        carbs < 0 ||
        fat < 0 ||
        saturatedFat < 0 ||
        fiber < 0 ||
        addedSugar < 0 ||
        sodium < 0) {
      setState(() {
        _errorMessage = 'Macro values cannot be negative.';
      });
      return;
    }

    final double savePortionSize =
        double.tryParse(_savePortionSizeController.text.trim()) ??
            (double.tryParse(_portionQuantityController.text.trim()) ??
                _basePortionSize);
    final String savePortionUnit =
        _savePortionUnitController.text.trim().isEmpty
            ? (_basePortionUnit.isNotEmpty ? _basePortionUnit : 'serving')
            : _savePortionUnitController.text.trim();

    final SavedFood? foodToSave = _saveForFutureUse
        ? SavedFood(
            name: name,
            calories: calories,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            saturatedFatG: saturatedFat,
            fiberG: fiber,
            addedSugarG: addedSugar,
            sodiumMg: sodium,
            portionSize: savePortionSize > 0 ? savePortionSize : 1.0,
            portionUnit: savePortionUnit,
          )
        : null;

    if (foodToSave != null && widget.onSaveFood != null) {
      setState(() {
        _isSaving = true;
      });
      try {
        await widget.onSaveFood!(foodToSave);
      } catch (_) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _errorMessage = 'Could not save this food for later. Please try again.';
          });
        }
        return;
      }
    }

    final double entryPortionSize =
        double.tryParse(_portionQuantityController.text.trim()) ??
            (double.tryParse(_savePortionSizeController.text.trim()) ??
                _basePortionSize);
    final String entryPortionUnit =
        _savePortionUnitController.text.trim().isNotEmpty
            ? _savePortionUnitController.text.trim()
            : (_basePortionUnit.isNotEmpty ? _basePortionUnit : 'serving');

    final FoodLogEntry result = FoodLogEntry(
      id: widget.initialEntry?.id,
      mealLabel: name,
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      saturatedFatG: saturatedFat,
      fiberG: fiber,
      addedSugarG: addedSugar,
      sodiumMg: sodium,
      portionSize: entryPortionSize > 0 ? entryPortionSize : 1.0,
      portionUnit: entryPortionUnit,
      rangeText: widget.initialEntry?.rangeText,
      sourceLabel: widget.initialEntry?.sourceLabel ??
          (_selectedSavedFoodId != null
              ? 'Saved'
              : (_filledFromLabel ? 'Label' : 'Manual')),
      spreadPercent: widget.initialEntry?.spreadPercent,
      mealType: _selectedMealType,
      timestamp: widget.initialEntry?.timestamp ?? DateTime.now(),
    );

    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  void _onDelete() {
    // Return special deletion marker
    Navigator.of(context).pop('delete');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _calController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _saturatedFatController.dispose();
    _fiberController.dispose();
    _addedSugarController.dispose();
    _sodiumController.dispose();
    _portionQuantityController.dispose();
    _savePortionSizeController.dispose();
    _savePortionUnitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Title
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedMealType.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isEditing ? Icons.edit_note_rounded : Icons.restaurant_menu_rounded,
                    color: _selectedMealType.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _isEditing ? 'Edit Meal' : 'Quick Add Food',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isEditing
                            ? 'Update calorie and macro values for this entry.'
                            : 'Log food directly, or scan a nutrition label.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    key: const Key('deleteEntryModalButton'),
                    onPressed: _onDelete,
                    icon: const Icon(Icons.delete_outline, color: AppColors.fat),
                    tooltip: 'Delete entry',
                  ),
              ],
            ),

            if (!_isEditing) ...<Widget>[
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('scanNutritionLabelButton'),
                  onTap: _isScanningLabel || _isSaving ? null : _scanNutritionLabel,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? <Color>[
                                AppColors.primary.withValues(alpha: 0.16),
                                const Color(0xFF8B5CF6).withValues(alpha: 0.10),
                              ]
                            : <Color>[
                                AppColors.primary.withValues(alpha: 0.08),
                                const Color(0xFF8B5CF6).withValues(alpha: 0.04),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _filledFromLabel
                            ? AppColors.success.withValues(alpha: 0.5)
                            : AppColors.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _filledFromLabel
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isScanningLabel
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : Icon(
                                  _filledFromLabel
                                      ? Icons.check_circle_rounded
                                      : Icons.document_scanner_rounded,
                                  size: 20,
                                  color: _filledFromLabel ? AppColors.success : AppColors.primary,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Text(
                                    _isScanningLabel
                                        ? 'Reading label...'
                                        : 'Scan nutrition label',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'AI Vision',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryLight,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _filledFromLabel
                                    ? 'Auto-filled from photo • Tap to re-scan'
                                    : 'Take photo or choose from gallery to auto-fill macros',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _filledFromLabel
                                      ? AppColors.success
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  fontWeight: _filledFromLabel ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.camera_alt_rounded,
                          size: 18,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_filledFromLabel) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  'Label scanned. Review the values, then log or save.',
                  key: const Key('nutritionLabelScanSuccess'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ],

            if (!_isEditing && _savedFoods.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  const Icon(Icons.bookmark_outline, size: 18, color: AppColors.primary),
                  const SizedBox(width: 7),
                  const Text(
                    'Saved Foods',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    'Tap to use',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                key: const Key('savedFoodsList'),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: _savedFoods.map(_savedFoodTile).toList(),
                ),
              ),
            ],

            if (_selectedSavedFood != null || _isEditing || _filledFromLabel)
              _portionSelectorWidget(isDark),

            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.fat.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.fat.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.error_outline, size: 16, color: AppColors.fat),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: AppColors.fat, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Meal Category Selector Chips
            const Text(
              'Meal Category',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: MealType.values.map((MealType type) {
                  final bool isSelected = _selectedMealType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('mealTypeChip_${type.name}'),
                      avatar: Icon(
                        type.icon,
                        size: 14,
                        color: isSelected ? Colors.white : type.color,
                      ),
                      label: Text(type.displayName),
                      selected: isSelected,
                      selectedColor: type.color,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() {
                            _selectedMealType = type;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // Food Name Field
            TextField(
              key: const Key('mealLabelField'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Food / Meal Name',
                hintText: 'e.g. Oatmeal with blueberries',
                prefixIcon: const Icon(Icons.fastfood_outlined, size: 20),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),

            if (_savedFoods.isNotEmpty)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nameController,
                builder: (BuildContext context, TextEditingValue value, Widget? _) {
                  final String query = value.text.trim().toLowerCase();
                  if (query.isEmpty) return const SizedBox.shrink();
                  final List<SavedFood> matching = _savedFoods
                      .where((SavedFood f) =>
                          f.id != _selectedSavedFoodId &&
                          (f.name.toLowerCase().contains(query) ||
                              query.contains(f.name.toLowerCase())))
                      .toList();
                  if (matching.isEmpty) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Row(
                          children: <Widget>[
                            Icon(Icons.inventory_2_outlined, size: 13, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'Matching Stored Foods (Tap to fill):',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: matching.map((SavedFood food) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  key: Key('modalStoredFoodChip_${food.id}'),
                                  avatar: const Icon(
                                    Icons.bookmark_rounded,
                                    size: 13,
                                    color: AppColors.primary,
                                  ),
                                  label: Text('${food.name} (${food.calories} kcal)'),
                                  onPressed: () => _useSavedFood(food),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 12),

            // Calories Field
            TextField(
              key: const Key('caloriesField'),
              controller: _calController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Calories (kcal)',
                hintText: 'e.g. 350',
                prefixIcon: const Icon(Icons.local_fire_department_outlined, size: 20, color: AppColors.calories),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Macros Row (Protein, Carbs, Fat)
            Row(
              children: <Widget>[
                Expanded(
                  child: _macroInputField(
                    key: 'proteinField',
                    label: 'Protein',
                    unit: 'g',
                    controller: _proteinController,
                    color: AppColors.protein,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _macroInputField(
                    key: 'carbsField',
                    label: 'Carbs',
                    unit: 'g',
                    controller: _carbsController,
                    color: AppColors.carbs,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _macroInputField(
                    key: 'fatField',
                    label: 'Fat',
                    unit: 'g',
                    controller: _fatController,
                    color: AppColors.fat,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Auto-calculate helper button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('calcCaloriesFromMacrosButton'),
                onPressed: _calculateCaloriesFromMacros,
                icon: const Icon(Icons.calculate_outlined, size: 16, color: AppColors.primary),
                label: const Text(
                  'Calc calories from macros (4/4/9)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Expandable Detailed Nutrition Section
            Material(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const Key('detailedNutritionExpansionTile'),
                  initiallyExpanded: _showDetailedNutrition,
                  onExpansionChanged: (bool expanded) {
                    setState(() {
                      _showDetailedNutrition = expanded;
                    });
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  childrenPadding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
                  leading: const Icon(
                    Icons.format_list_bulleted_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Additional Nutrition (Optional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Saturated fat, fiber, added sugar, sodium',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _macroInputField(
                            key: 'saturatedFatField',
                            label: 'Sat. Fat',
                            unit: 'g',
                            controller: _saturatedFatController,
                            color: const Color(0xFFF97316),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _macroInputField(
                            key: 'fiberField',
                            label: 'Fiber',
                            unit: 'g',
                            controller: _fiberController,
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _macroInputField(
                            key: 'addedSugarField',
                            label: 'Added Sugar',
                            unit: 'g',
                            controller: _addedSugarController,
                            color: const Color(0xFFEC4899),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _macroInputField(
                            key: 'sodiumField',
                            label: 'Sodium',
                            unit: 'mg',
                            controller: _sodiumController,
                            color: const Color(0xFF06B6D4),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (widget.onSaveFood != null) ...<Widget>[
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        key: const Key('saveForFutureUseCheckbox'),
                        value: _saveForFutureUse,
                        onChanged: _isSaving
                            ? null
                            : (bool? value) {
                                setState(() {
                                  _saveForFutureUse = value ?? false;
                                });
                              },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Save for future use',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Keep this food in Quick Add with portion settings.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    if (_saveForFutureUse) ...<Widget>[
                      const Divider(height: 14),
                      const Text(
                        'Base Portion Settings',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Expanded(
                            flex: 2,
                            child: TextField(
                              key: const Key('portionSizeField'),
                              controller: _savePortionSizeController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Portion Size',
                                hintText: '1',
                                isDense: true,
                                filled: true,
                                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              key: const Key('portionUnitField'),
                              controller: _savePortionUnitController,
                              decoration: InputDecoration(
                                labelText: 'Unit',
                                hintText: 'serving, g, cup...',
                                isDense: true,
                                filled: true,
                                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <String>[
                            'serving',
                            'g',
                            'oz',
                            'cup',
                            'piece',
                            'scoop',
                            'slice',
                            'bowl',
                          ].map((String unit) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: ActionChip(
                                key: Key('saveUnitChip_$unit'),
                                label: Text(unit, style: const TextStyle(fontSize: 10)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setState(() {
                                    _savePortionUnitController.text = unit;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('saveEntryButton'),
                    onPressed: _isSaving ? null : _onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _isSaving
                          ? 'Saving...'
                          : (_isEditing ? 'Save Changes' : 'Log Food'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _portionSelectorWidget(bool isDark) {
    final String unitLabel =
        _basePortionUnit.isNotEmpty ? _basePortionUnit : 'serving';
    final double step =
        _basePortionSize > 10 ? 25.0 : (_basePortionSize > 1 ? 1.0 : 0.5);

    return Container(
      key: const Key('portionSelectorCard'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.pie_chart_outline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Choose Portion',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Base: $_basePortionDisplay',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              IconButton.filledTonal(
                key: const Key('portionDecrementButton'),
                onPressed: () => _adjustPortion(-step),
                icon: const Icon(Icons.remove, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Decrease portion',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('portionInputField'),
                  controller: _portionQuantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: _onPortionQuantityChanged,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Portion',
                    suffixText: unitLabel,
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const Key('portionIncrementButton'),
                onPressed: () => _adjustPortion(step),
                icon: const Icon(Icons.add, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Increase portion',
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <double>[0.5, 1.0, 1.5, 2.0, 3.0].map((double mult) {
                final String label = mult == mult.toInt().toDouble()
                    ? '${mult.toInt()}x'
                    : '${mult}x';
                final bool isSelected = (_currentPortionMultiplier - mult).abs() < 0.01;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: Key('portionChip_${mult == mult.toInt().toDouble() ? mult.toInt() : mult}'),
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    onSelected: (_) => _setPortionMultiplier(mult),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedFoodTile(SavedFood food) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: Key('savedFoodTile_${food.id}'),
        dense: true,
        onTap: () => _useSavedFood(food),
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.bookmark_rounded,
            size: 18,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          food.name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${food.calories} kcal  ·  ${food.portionDisplay}  ·  P ${food.proteinG}g  C ${food.carbsG}g  F ${food.fatG}g',
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        trailing: widget.onDeleteSavedFood == null
            ? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary)
            : IconButton(
                key: Key('deleteSavedFood_${food.id}'),
                onPressed: () => _removeSavedFood(food),
                icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.fat),
                tooltip: 'Remove saved food',
              ),
      ),
    );
  }

  Widget _macroInputField({
    required String key,
    required String label,
    required String unit,
    required TextEditingController controller,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          key: Key(key),
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: unit,
            isDense: true,
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: color.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
