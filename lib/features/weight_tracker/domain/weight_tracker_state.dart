import 'weight_entry.dart';
import 'weight_goal.dart';
import 'weight_unit.dart';
import '../data/weight_storage.dart';

/// Available time range filters for the weight chart and analytics.
enum WeightTimeRange {
  sevenDays('7D', Duration(days: 7)),
  thirtyDays('30D', Duration(days: 30)),
  ninetyDays('90D', Duration(days: 90)),
  oneYear('1Y', Duration(days: 365)),
  all('ALL', null);

  const WeightTimeRange(this.label, this.duration);

  final String label;
  final Duration? duration;
}

/// State controller and analytics engine for the Weight Tracker feature.
class WeightTrackerState {
  WeightTrackerState({
    required this.storage,
    List<WeightEntry>? initialEntries,
    WeightGoal? initialGoal,
  })  : _entries = initialEntries ?? <WeightEntry>[],
        _goal = initialGoal ?? const WeightGoal();

  final WeightStorage storage;
  List<WeightEntry> _entries;
  WeightGoal _goal;
  WeightTimeRange _selectedRange = WeightTimeRange.thirtyDays;

  List<WeightEntry> get entries => List<WeightEntry>.unmodifiable(_entries);
  WeightGoal get goal => _goal;
  WeightTimeRange get selectedRange => _selectedRange;

  /// Loads stored data from persistence.
  Future<void> initFromStorage() async {
    _entries = await storage.loadEntries();
    _goal = await storage.loadGoal();
    _sortEntries();
  }

  void _sortEntries() {
    _entries.sort((WeightEntry a, WeightEntry b) => b.date.compareTo(a.date));
  }

  WeightEntry? get latestEntry => _entries.isNotEmpty ? _entries.first : null;

  WeightEntry? get previousEntry => _entries.length > 1 ? _entries[1] : null;

  double? get currentWeight => latestEntry?.weight;

  WeightUnit get preferredUnit => _goal.unit;

  /// Delta in weight between the most recent weigh-in and the one before it.
  double? get lastEntryDelta {
    if (latestEntry == null || previousEntry == null) return null;
    final double prevConverted =
        previousEntry!.unit.convertTo(previousEntry!.weight, latestEntry!.unit);
    return latestEntry!.weight - prevConverted;
  }

  /// Total change from starting weight or first recorded entry.
  double? get totalChange {
    if (latestEntry == null) return null;
    final double currentVal = latestEntry!.weight;
    final WeightUnit currentUnit = latestEntry!.unit;

    if (_goal.hasStart) {
      final double startInCurrent =
          _goal.unit.convertTo(_goal.startingWeight!, currentUnit);
      return currentVal - startInCurrent;
    } else if (_entries.length > 1) {
      final WeightEntry oldest = _entries.last;
      final double oldestInCurrent =
          oldest.unit.convertTo(oldest.weight, currentUnit);
      return currentVal - oldestInCurrent;
    }
    return 0.0;
  }

  /// Progress (0.0 to 1.0) towards user's target weight.
  double get goalProgress {
    if (latestEntry == null) return 0.0;
    return _goal.calculateProgress(latestEntry!.weight, latestEntry!.unit);
  }

  /// Remaining weight distance to target in goal unit.
  double? get remainingToGoal {
    if (latestEntry == null) return null;
    return _goal.calculateRemaining(latestEntry!.weight, latestEntry!.unit);
  }

  /// Calculates BMI if height and current weight are available.
  double? get currentBmi {
    if (latestEntry == null) return null;
    return _goal.calculateBmi(latestEntry!.weight, latestEntry!.unit);
  }

  String? get bmiCategory {
    final double? bmi = currentBmi;
    if (bmi == null) return null;
    return WeightGoal.getBmiCategory(bmi);
  }

  /// Entries filtered by the selected time range, sorted chronologically ascending (for chart).
  List<WeightEntry> get chartEntries {
    if (_entries.isEmpty) return <WeightEntry>[];
    final DateTime now = DateTime.now();

    final List<WeightEntry> filtered;
    if (_selectedRange.duration == null) {
      filtered = List<WeightEntry>.from(_entries);
    } else {
      final DateTime cutoff = now.subtract(_selectedRange.duration!);
      filtered = _entries.where((WeightEntry e) => e.date.isAfter(cutoff) || e.date.isAtSameMomentAs(cutoff)).toList();
    }

    filtered.sort((WeightEntry a, WeightEntry b) => a.date.compareTo(b.date));
    return filtered;
  }

  /// Filtered entries sorted chronologically descending (newest first for list view).
  List<WeightEntry> get filteredListEntries {
    final List<WeightEntry> list = chartEntries;
    return list.reversed.toList();
  }

  double? get minWeightInRange {
    final List<WeightEntry> list = chartEntries;
    if (list.isEmpty) return null;
    double min = list.first.unit.convertTo(list.first.weight, preferredUnit);
    for (final WeightEntry e in list) {
      final double val = e.unit.convertTo(e.weight, preferredUnit);
      if (val < min) min = val;
    }
    return min;
  }

  double? get maxWeightInRange {
    final List<WeightEntry> list = chartEntries;
    if (list.isEmpty) return null;
    double max = list.first.unit.convertTo(list.first.weight, preferredUnit);
    for (final WeightEntry e in list) {
      final double val = e.unit.convertTo(e.weight, preferredUnit);
      if (val > max) max = val;
    }
    return max;
  }

  double? get averageWeightInRange {
    final List<WeightEntry> list = chartEntries;
    if (list.isEmpty) return null;
    final double total = list.fold<double>(
      0.0,
      (double sum, WeightEntry e) => sum + e.unit.convertTo(e.weight, preferredUnit),
    );
    return total / list.length;
  }

  /// Change over the selected time range.
  double? get rangeChange {
    final List<WeightEntry> list = chartEntries;
    if (list.length < 2) return 0.0;
    final double firstVal = list.first.unit.convertTo(list.first.weight, preferredUnit);
    final double lastVal = list.last.unit.convertTo(list.last.weight, preferredUnit);
    return lastVal - firstVal;
  }

  void setRange(WeightTimeRange range) {
    _selectedRange = range;
  }

  Future<void> addEntry(WeightEntry entry) async {
    // If an entry for the exact same ID exists, update it, otherwise add
    final int index = _entries.indexWhere((WeightEntry e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
    } else {
      _entries.add(entry);
    }
    _sortEntries();
    await storage.saveEntry(entry);
  }

  Future<void> editEntry(WeightEntry entry) async {
    final int index = _entries.indexWhere((WeightEntry e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      _sortEntries();
      await storage.saveEntry(entry);
    }
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((WeightEntry e) => e.id == id);
    await storage.deleteEntry(id);
  }

  Future<void> setGoal(WeightGoal goal) async {
    _goal = goal;
    await storage.saveGoal(goal);
  }
}
