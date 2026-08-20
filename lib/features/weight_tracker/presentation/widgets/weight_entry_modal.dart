import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/weight_entry.dart';
import '../../domain/weight_unit.dart';
import '../../../calorie_tracker/presentation/theme/app_theme.dart';

class WeightEntryModal extends StatefulWidget {
  const WeightEntryModal({
    super.key,
    this.initialEntry,
    required this.defaultUnit,
    this.defaultWeight,
  });

  final WeightEntry? initialEntry;
  final WeightUnit defaultUnit;
  final double? defaultWeight;

  static Future<dynamic> showAdd(
    BuildContext context, {
    required WeightUnit defaultUnit,
    double? defaultWeight,
  }) {
    return showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => WeightEntryModal(
        defaultUnit: defaultUnit,
        defaultWeight: defaultWeight,
      ),
    );
  }

  static Future<dynamic> showEdit(
    BuildContext context,
    WeightEntry entry, {
    required WeightUnit defaultUnit,
  }) {
    return showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => WeightEntryModal(
        initialEntry: entry,
        defaultUnit: defaultUnit,
      ),
    );
  }

  @override
  State<WeightEntryModal> createState() => _WeightEntryModalState();
}

class _WeightEntryModalState extends State<WeightEntryModal> {
  late final TextEditingController _weightController;
  late final TextEditingController _bodyFatController;
  late final TextEditingController _noteController;

  late WeightUnit _unit;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  bool get _isEditing => widget.initialEntry != null;

  static const List<String> _quickNotes = <String>[
    'Morning',
    'Fasted',
    'Post-workout',
    'Evening',
  ];

  @override
  void initState() {
    super.initState();
    final WeightEntry? initial = widget.initialEntry;

    _unit = initial?.unit ?? widget.defaultUnit;
    final double initialWeight = initial?.weight ?? widget.defaultWeight ?? 70.0;
    _weightController = TextEditingController(
      text: initialWeight.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
    );

    _bodyFatController = TextEditingController(
      text: initial?.bodyFatPercentage != null
          ? initial!.bodyFatPercentage!.toStringAsFixed(1)
          : '',
    );

    _noteController = TextEditingController(text: initial?.note ?? '');

    _selectedDate = initial?.date ?? DateTime.now();
    _selectedTime = initial != null
        ? TimeOfDay.fromDateTime(initial.date)
        : TimeOfDay.now();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _adjustWeight(double delta) {
    final double current = double.tryParse(_weightController.text.trim()) ?? 70.0;
    final double updated = (current + delta).clamp(10.0, 500.0);
    _weightController.text = updated.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    setState(() {});
  }

  void _toggleUnit(WeightUnit newUnit) {
    if (_unit == newUnit) return;
    final double? current = double.tryParse(_weightController.text.trim());
    setState(() {
      if (current != null && current > 0) {
        final double converted = _unit.convertTo(current, newUnit);
        _weightController.text = converted.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
      }
      _unit = newUnit;
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _onSave() {
    final double? weight = double.tryParse(_weightController.text.trim());
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight')),
      );
      return;
    }

    final double? bodyFat = double.tryParse(_bodyFatController.text.trim());
    final String note = _noteController.text.trim();

    final DateTime fullDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final WeightEntry entry = WeightEntry(
      id: widget.initialEntry?.id,
      weight: weight,
      unit: _unit,
      date: fullDate,
      note: note.isNotEmpty ? note : null,
      bodyFatPercentage: (bodyFat != null && bodyFat > 0) ? bodyFat : null,
      createdAt: widget.initialEntry?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(entry);
  }

  void _onDelete() {
    Navigator.of(context).pop('delete');
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final EdgeInsets bottomInsets = MediaQuery.of(context).viewInsets;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _isEditing ? 'Edit Weigh-in' : 'Log Weight',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                // Unit Switcher
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: <Widget>[
                      _buildUnitOption(WeightUnit.kg, isDark),
                      _buildUnitOption(WeightUnit.lbs, isDark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main Weight Input with Quick Step Adjusters
            Row(
              children: <Widget>[
                _buildStepButton('-0.5', () => _adjustWeight(-0.5), isDark),
                const SizedBox(width: 6),
                _buildStepButton('-0.1', () => _adjustWeight(-0.1), isDark),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('weightInputField'),
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      suffixText: _unit.displayName,
                      suffixStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStepButton('+0.1', () => _adjustWeight(0.1), isDark),
                const SizedBox(width: 6),
                _buildStepButton('+0.5', () => _adjustWeight(0.5), isDark),
              ],
            ),
            const SizedBox(height: 18),

            // Date & Time Selectors Row
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('pickDateButton'),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      DateFormat('MMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('pickTimeButton'),
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: Text(
                      _selectedTime.format(context),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Optional Body Fat %
            TextField(
              key: const Key('bodyFatInputField'),
              controller: _bodyFatController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Body Fat % (Optional)',
                prefixIcon: Icon(Icons.percent_rounded, size: 18),
                hintText: 'e.g. 15.4',
              ),
            ),
            const SizedBox(height: 14),

            // Quick Note Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _quickNotes.map((String tag) {
                final bool isSelected = _noteController.text.contains(tag);
                return ActionChip(
                  label: Text(tag, style: const TextStyle(fontSize: 11)),
                  backgroundColor: isSelected
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  onPressed: () {
                    setState(() {
                      if (_noteController.text.isEmpty) {
                        _noteController.text = tag;
                      } else if (!_noteController.text.contains(tag)) {
                        _noteController.text = '${_noteController.text}, $tag';
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // Custom Note Input
            TextField(
              key: const Key('weightNoteInputField'),
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
                hintText: 'e.g. Morning fasted after cardio',
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons (Save & Delete)
            Row(
              children: <Widget>[
                if (_isEditing) ...<Widget>[
                  IconButton.filledTonal(
                    key: const Key('deleteWeightEntryButton'),
                    onPressed: _onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.fat.withValues(alpha: 0.15),
                      foregroundColor: AppColors.fat,
                      padding: const EdgeInsets.all(14),
                    ),
                    tooltip: 'Delete Entry',
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('saveWeightEntryButton'),
                    onPressed: _onSave,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(_isEditing ? 'Update Weigh-in' : 'Save Weigh-in'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitOption(WeightUnit unit, bool isDark) {
    final bool isSelected = _unit == unit;
    return GestureDetector(
      key: Key('unitSelector_${unit.name}'),
      onTap: () => _toggleUnit(unit),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          unit.displayName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildStepButton(String text, VoidCallback onPressed, bool isDark) {
    return SizedBox(
      width: 44,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
    );
  }
}
