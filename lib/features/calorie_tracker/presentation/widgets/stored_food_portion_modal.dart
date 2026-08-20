import 'package:flutter/material.dart';

import '../../domain/daily_log.dart';
import '../../domain/meal_type.dart';
import '../../domain/saved_food.dart';
import '../theme/app_theme.dart';

/// Modal dialog for quickly logging a stored food item with optional portion adjustment.
class StoredFoodPortionModal extends StatefulWidget {
  const StoredFoodPortionModal({
    super.key,
    required this.food,
    this.defaultMealType,
    this.onOpenFullEdit,
  });

  final SavedFood food;
  final MealType? defaultMealType;
  final VoidCallback? onOpenFullEdit;

  static Future<FoodLogEntry?> show(
    BuildContext context, {
    required SavedFood food,
    MealType? defaultMealType,
    VoidCallback? onOpenFullEdit,
  }) {
    return showModalBottomSheet<FoodLogEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => StoredFoodPortionModal(
        food: food,
        defaultMealType: defaultMealType,
        onOpenFullEdit: onOpenFullEdit,
      ),
    );
  }

  @override
  State<StoredFoodPortionModal> createState() => _StoredFoodPortionModalState();
}

class _StoredFoodPortionModalState extends State<StoredFoodPortionModal> {
  late final TextEditingController _quantityController;
  late MealType _selectedMealType;
  double _multiplier = 1.0;
  String? _errorMessage;

  double get _basePortionSize => widget.food.portionSize > 0 ? widget.food.portionSize : 1.0;
  String get _portionUnit => widget.food.portionUnit.trim().isNotEmpty
      ? widget.food.portionUnit.trim()
      : 'serving';

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.defaultMealType ?? MealType.forTime();
    final String initialPortionStr = _basePortionSize == _basePortionSize.toInt().toDouble()
        ? '${_basePortionSize.toInt()}'
        : '$_basePortionSize';
    _quantityController = TextEditingController(text: initialPortionStr);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  double get _stepSize {
    final String unitLower = _portionUnit.toLowerCase();
    if (unitLower == 'g' || unitLower == 'gram' || unitLower == 'grams' || unitLower == 'ml') {
      if (_basePortionSize >= 50) return 25.0;
      if (_basePortionSize >= 20) return 10.0;
      return 5.0;
    }
    if (_basePortionSize <= 1.0) return 0.5;
    if (_basePortionSize <= 5.0) return 0.5;
    return 1.0;
  }

  void _onQuantityChanged(String value) {
    final double? parsed = double.tryParse(value.trim());
    if (parsed != null && parsed > 0 && _basePortionSize > 0) {
      setState(() {
        _multiplier = parsed / _basePortionSize;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = 'Please enter a portion greater than 0.';
      });
    }
  }

  void _setMultiplier(double multiplier) {
    if (multiplier <= 0) return;
    final double newQuantity = _basePortionSize * multiplier;
    final String formatted = newQuantity == newQuantity.toInt().toDouble()
        ? '${newQuantity.toInt()}'
        : newQuantity.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

    setState(() {
      _multiplier = multiplier;
      _quantityController.text = formatted;
      _errorMessage = null;
    });
  }

  void _adjustQuantity(double delta) {
    final double currentVal = double.tryParse(_quantityController.text.trim()) ?? _basePortionSize;
    final double updated = (currentVal + delta).clamp(0.1, 99999.0);
    final String formatted = updated == updated.toInt().toDouble()
        ? '${updated.toInt()}'
        : updated.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

    setState(() {
      _quantityController.text = formatted;
      _multiplier = updated / _basePortionSize;
      _errorMessage = null;
    });
  }

  int get _calculatedCalories => (widget.food.calories * _multiplier).round().clamp(0, 99999);
  int get _calculatedProtein => (widget.food.proteinG * _multiplier).round().clamp(0, 9999);
  int get _calculatedCarbs => (widget.food.carbsG * _multiplier).round().clamp(0, 9999);
  int get _calculatedFat => (widget.food.fatG * _multiplier).round().clamp(0, 9999);
  int get _calculatedSaturatedFat => (widget.food.saturatedFatG * _multiplier).round().clamp(0, 9999);
  int get _calculatedFiber => (widget.food.fiberG * _multiplier).round().clamp(0, 9999);
  int get _calculatedAddedSugar => (widget.food.addedSugarG * _multiplier).round().clamp(0, 9999);
  int get _calculatedSodium => (widget.food.sodiumMg * _multiplier).round().clamp(0, 99999);

  void _onConfirmAdd() {
    final double? parsed = double.tryParse(_quantityController.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid portion size (> 0).';
      });
      return;
    }

    final FoodLogEntry entry = widget.food.toFoodLogEntry(
      mealType: _selectedMealType,
      chosenPortionSize: parsed,
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final bool hasExtraMicros = widget.food.saturatedFatG > 0 ||
        widget.food.fiberG > 0 ||
        widget.food.addedSugarG > 0 ||
        widget.food.sodiumMg > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Drag Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row: Icon, Title & Badge, Close Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[AppColors.primary, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bookmark_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.food.name,
                        key: const Key('portionModalFoodTitle'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.offline_bolt_rounded, size: 12, color: AppColors.success),
                                SizedBox(width: 3),
                                Text(
                                  'Stored Food • No API Call',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('closePortionModalButton'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Calorie and Macro Summary Card
            Container(
              key: const Key('portionModalNutritionSummary'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Estimated Calories',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: <Widget>[
                              Text(
                                '$_calculatedCalories',
                                key: const Key('portionModalCaloriesText'),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.calories,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'kcal',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.calories),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _multiplier == 1.0
                              ? 'Base: ${widget.food.portionDisplay}'
                              : '${(_multiplier * 100).round()}% of base',
                          key: const Key('portionModalBaseText'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Primary Macros Row
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _macroBadge(
                          label: 'Protein',
                          value: '$_calculatedProtein g',
                          color: AppColors.protein,
                          isDark: isDark,
                          key: 'portionModalProteinBadge',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _macroBadge(
                          label: 'Carbs',
                          value: '$_calculatedCarbs g',
                          color: AppColors.carbs,
                          isDark: isDark,
                          key: 'portionModalCarbsBadge',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _macroBadge(
                          label: 'Fat',
                          value: '$_calculatedFat g',
                          color: AppColors.fat,
                          isDark: isDark,
                          key: 'portionModalFatBadge',
                        ),
                      ),
                    ],
                  ),
                  if (hasExtraMicros) ...<Widget>[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: <Widget>[
                        if (widget.food.fiberG > 0)
                          _microBadge('Fiber: ${_calculatedFiber}g', isDark),
                        if (widget.food.saturatedFatG > 0)
                          _microBadge('Sat Fat: ${_calculatedSaturatedFat}g', isDark),
                        if (widget.food.addedSugarG > 0)
                          _microBadge('Sugar: ${_calculatedAddedSugar}g', isDark),
                        if (widget.food.sodiumMg > 0)
                          _microBadge('Sodium: ${_calculatedSodium}mg', isDark),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Portion Editor Section
            Row(
              children: <Widget>[
                const Icon(Icons.scale_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Portion Size',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  'Base: ${widget.food.portionDisplay}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Stepper & Text Field Row
            Row(
              children: <Widget>[
                IconButton.filledTonal(
                  key: const Key('portionModalDecrementButton'),
                  onPressed: () => _adjustQuantity(-_stepSize),
                  icon: const Icon(Icons.remove, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Decrease portion',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('portionModalQuantityField'),
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    onChanged: _onQuantityChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      suffixText: _portionUnit,
                      suffixStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('portionModalIncrementButton'),
                  onPressed: () => _adjustQuantity(_stepSize),
                  icon: const Icon(Icons.add, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Increase portion',
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Quick Multipliers Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <double>[0.5, 1.0, 1.5, 2.0, 3.0].map((double mult) {
                  final String label = mult == mult.toInt().toDouble()
                      ? '${mult.toInt()}x'
                      : '${mult}x';
                  final bool isSelected = (_multiplier - mult).abs() < 0.01;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: Key('portionModalChip_${mult == mult.toInt().toDouble() ? mult.toInt() : mult}'),
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      onSelected: (_) => _setMultiplier(mult),
                    ),
                  );
                }).toList(),
              ),
            ),

            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: AppColors.fat, fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: 14),

            // Meal Type Category Selector
            const Text(
              'Meal Category',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
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
                      key: Key('portionModalMealType_${type.name}'),
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

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: <Widget>[
                if (widget.onOpenFullEdit != null) ...<Widget>[
                  OutlinedButton.icon(
                    key: const Key('fullEditStoredFoodButton'),
                    onPressed: widget.onOpenFullEdit,
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Edit Details'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('confirmAddStoredFoodButton'),
                    onPressed: _onConfirmAdd,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text(
                      _multiplier == 1.0
                          ? 'Add to Log ($_calculatedCalories kcal)'
                          : 'Log Food ($_calculatedCalories kcal)',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _macroBadge({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required String key,
  }) {
    return Container(
      key: Key(key),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _microBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}
