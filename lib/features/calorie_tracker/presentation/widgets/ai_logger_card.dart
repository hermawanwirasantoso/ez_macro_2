import 'package:flutter/material.dart';
import '../../domain/meal_type.dart';
import '../../domain/parse_result.dart';
import '../../domain/saved_food.dart';
import '../../domain/saved_food_matcher.dart';
import '../theme/app_theme.dart';

class AiLoggerCard extends StatelessWidget {
  const AiLoggerCard({
    super.key,
    required this.inputController,
    required this.isParsing,
    required this.hasConfiguredApiKey,
    required this.lastParse,
    required this.lastUsedFallback,
    this.lastParseSource,
    required this.showSpreadDetails,
    required this.onParse,
    required this.onSelectSuggestion,
    this.onConfigureApiKey,
    this.onQuickAdd,
    this.selectedMealType,
    this.onSelectMealType,
    this.savedFoods = const <SavedFood>[],
    this.onSelectSavedFood,
  });

  final TextEditingController inputController;
  final bool isParsing;
  final bool hasConfiguredApiKey;
  final ParseResult? lastParse;
  final bool lastUsedFallback;
  final String? lastParseSource;
  final bool showSpreadDetails;
  final VoidCallback onParse;
  final ValueChanged<String> onSelectSuggestion;
  final VoidCallback? onConfigureApiKey;
  final VoidCallback? onQuickAdd;
  final MealType? selectedMealType;
  final ValueChanged<MealType>? onSelectMealType;
  final List<SavedFood> savedFoods;
  final ValueChanged<SavedFood>? onSelectSavedFood;

  static const List<String> _suggestions = <String>[
    'a bowl of rice',
    '200g of chicken breast',
    '2 eggs with toast',
    'banana smoothie 320 kcal',
    'salmon salad 450 kcal',
  ];

  List<SavedFood> _getMatchingSavedFoods(String query) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty || savedFoods.isEmpty) {
      return <SavedFood>[];
    }

    final String queryLower = trimmed.toLowerCase();
    final List<String> queryTokens = queryLower
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();

    final List<SavedFood> matches = savedFoods.where((SavedFood food) {
      final String nameLower = food.name.toLowerCase();
      // 1. Exact match
      if (nameLower == queryLower) return true;
      // 2. Substring match
      if (nameLower.contains(queryLower) || queryLower.contains(nameLower)) return true;
      // 3. Token match
      final List<String> nameTokens = nameLower
          .split(RegExp(r'\s+'))
          .where((String s) => s.isNotEmpty)
          .toList();
      if (queryTokens.any((String q) => nameTokens.any((String n) => n.contains(q) || q.contains(n)))) {
        return true;
      }
      // 4. Match via SavedFoodMatcher (handles portion formats like "200g chicken breast")
      if (SavedFoodMatcher.findMatch(trimmed, <SavedFood>[food]) != null) {
        return true;
      }
      return false;
    }).toList();

    matches.sort((SavedFood a, SavedFood b) {
      final String aName = a.name.toLowerCase();
      final String bName = b.name.toLowerCase();
      if (aName == queryLower && bName != queryLower) return -1;
      if (bName == queryLower && aName != queryLower) return 1;
      if (aName.startsWith(queryLower) && !bName.startsWith(queryLower)) return -1;
      if (bName.startsWith(queryLower) && !aName.startsWith(queryLower)) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: AppColors.card(isDark),
        border: Border.all(color: AppColors.border(isDark)),
        boxShadow: AppColors.cardShadow(isDark),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: inputController,
        builder: (BuildContext context, TextEditingValue textValue, Widget? _) {
          final String currentText = textValue.text;
          final String query = currentText.trim();
          final List<SavedFood> matchingStoredFoods = _getMatchingSavedFoods(query);
          final ParseResult? matchedStoredResult =
              query.isEmpty ? null : SavedFoodMatcher.findMatch(query, savedFoods);
          final bool isStoredFoodMatch = matchedStoredResult != null;
          SavedFood? matchedSavedFood;
          if (matchedStoredResult != null && savedFoods.isNotEmpty) {
            final int idx = savedFoods.indexWhere(
              (SavedFood f) => f.name.toLowerCase() == matchedStoredResult.mealLabel.toLowerCase(),
            );
            if (idx != -1) {
              matchedSavedFood = savedFoods[idx];
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header: title, live status line and AI status pill
              Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[AppColors.primaryLight, AppColors.accent],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Log a meal',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                        Text(
                          isStoredFoodMatch
                              ? 'Saved food found. Logs instantly, no API call.'
                              : (hasConfiguredApiKey
                                  ? 'Describe it in plain words. AI does the math.'
                                  : 'Using local estimates. Add a key for AI.'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isStoredFoodMatch ? FontWeight.w700 : FontWeight.w500,
                            color: isStoredFoodMatch ? AppColors.success : AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('configureApiKeyButton'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: onConfigureApiKey,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: hasConfiguredApiKey
                              ? AppColors.success.withValues(alpha: isDark ? 0.18 : 0.1)
                              : AppColors.subtleFill(isDark),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasConfiguredApiKey ? AppColors.success : AppColors.carbs,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasConfiguredApiKey ? 'AI Ready' : 'Local NLP',
                              key: const Key('configureApiKeyBadge'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: hasConfiguredApiKey
                                    ? (isDark ? AppColors.brandGlow : AppColors.success)
                                    : AppColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Input field with an attached parse button
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: const Key('nlInputField'),
                      controller: inputController,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(isDark),
                      ),
                      decoration: InputDecoration(
                        hintText: 'What did you eat?',
                        prefixIcon: Icon(
                          isStoredFoodMatch ? Icons.offline_bolt_rounded : Icons.restaurant_rounded,
                          size: 20,
                          color: isStoredFoodMatch ? AppColors.success : AppColors.textSecondary(isDark),
                        ),
                        suffixIcon: currentText.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                tooltip: 'Clear',
                                onPressed: () {
                                  inputController.clear();
                                },
                              )
                            : null,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onParse(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: FilledButton(
                      key: const Key('parseMealButton'),
                      onPressed: isParsing ? null : onParse,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isParsing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Icon(Icons.arrow_upward_rounded, size: 22, semanticLabel: 'Log meal'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Quick actions: manual entry, saved foods, then example phrases
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    if (onQuickAdd != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          key: const Key('openQuickAddButton'),
                          onPressed: onQuickAdd,
                          avatar: Icon(Icons.add_rounded, size: 16, color: AppColors.brandText(isDark)),
                          label: Text(
                            'Manual Add',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandText(isDark),
                            ),
                          ),
                          backgroundColor: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.1),
                          side: BorderSide.none,
                        ),
                      ),
                    if (savedFoods.isNotEmpty)
                      ...savedFoods.take(4).map((SavedFood food) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            key: Key('storedFoodChip_${food.id}'),
                            avatar: Icon(
                              Icons.bookmark_rounded,
                              size: 14,
                              color: AppColors.brandText(isDark),
                            ),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  food.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(isDark),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${food.calories} kcal',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary(isDark),
                                  ),
                                ),
                              ],
                            ),
                            onPressed: () {
                              inputController.text = food.name;
                              inputController.selection = TextSelection.fromPosition(
                                TextPosition(offset: food.name.length),
                              );
                              onSelectSuggestion(food.name);
                              onSelectSavedFood?.call(food);
                            },
                          ),
                        );
                      }),
                    ...List<Widget>.generate(
                      _suggestions.length,
                      (int index) {
                        final String suggestion = _suggestions[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            key: Key('suggestionChip_$index'),
                            label: Text(
                              suggestion,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                            backgroundColor: Colors.transparent,
                            onPressed: () => onSelectSuggestion(suggestion),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Stored Food Match Banner (when direct match detected)
              if (matchedStoredResult != null) ...<Widget>[
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: const Key('storedFoodMatchBanner'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: matchedSavedFood != null && onSelectSavedFood != null
                        ? () => onSelectSavedFood?.call(matchedSavedFood!)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.offline_bolt_rounded,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        'Using Stored Food: ${matchedStoredResult.mealLabel}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${matchedStoredResult.calories} kcal)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  matchedSavedFood != null
                                      ? 'Tap to adjust portion or log • No API call.'
                                      : 'Input will be logged directly from stored food data — no API call.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (matchedSavedFood != null && onSelectSavedFood != null) ...<Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.tune, size: 11, color: AppColors.primaryLight),
                                  SizedBox(width: 3),
                                  Text(
                                    'Portion',
                                    key: Key('adjustPortionBannerButton'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'NO API',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // Stored Food Suggestions List (when user types and matching items found)
              if (query.isNotEmpty && matchingStoredFoods.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  key: const Key('storedFoodSuggestionsList'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 15,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Stored Foods (${matchingStoredFoods.length})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.offline_bolt_rounded, size: 11, color: AppColors.success),
                                SizedBox(width: 3),
                                Text(
                                  'Stored Data • No API Call',
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
                      const SizedBox(height: 8),
                      ...matchingStoredFoods.take(5).map((SavedFood food) {
                        return Container(
                          key: Key('storedFoodSuggestion_${food.id}'),
                          margin: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                inputController.text = food.name;
                                inputController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: food.name.length),
                                );
                                onSelectSuggestion(food.name);
                                onSelectSavedFood?.call(food);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.bookmark_rounded,
                                        size: 15,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            food.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? AppColors.darkTextPrimary
                                                  : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${food.calories} kcal  •  P: ${food.proteinG}g  C: ${food.carbsG}g  F: ${food.fatG}g  •  ${food.portionDisplay}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors.lightTextSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      key: Key('storedFoodBadge_${food.id}'),
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.success.withValues(alpha: 0.28),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Icon(Icons.offline_bolt_rounded, size: 12, color: AppColors.success),
                                          SizedBox(width: 3),
                                          Text(
                                            'Stored',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              // Parse Result Box
              if (lastParse != null) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (showSpreadDetails) ...<Widget>[
                        Builder(
                          builder: (BuildContext context) {
                            final double uncertainty = lastParse!.uncertaintyPercent(
                              isFallback: lastUsedFallback,
                            );
                            final int low = lastParse!.caloriesLowerBound(uncertainty);
                            final int high = lastParse!.caloriesUpperBound(uncertainty);
                            return Text(
                              'Estimated range: $low-$high kcal (${(uncertainty * 100).round()}% spread)',
                              key: const Key('spreadText'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.caloriesLight : AppColors.calories,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        'Detected: ${lastParse!.mealLabel}, ${lastParse!.calories} kcal, P ${lastParse!.proteinG}g C ${lastParse!.carbsG}g F ${lastParse!.fatG}g (${(lastParse!.confidence * 100).round()}% confidence) [${lastParseSource ?? (lastUsedFallback ? 'Local' : 'AI')}]',
                        key: const Key('parseResultText'),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Visual Macro Badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          _MacroPill(
                            label: '${lastParse!.calories} kcal',
                            color: AppColors.calories,
                          ),
                          _MacroPill(
                            label: 'P: ${lastParse!.proteinG}g',
                            color: AppColors.protein,
                          ),
                          _MacroPill(
                            label: 'C: ${lastParse!.carbsG}g',
                            color: AppColors.carbs,
                          ),
                          _MacroPill(
                            label: 'F: ${lastParse!.fatG}g',
                            color: AppColors.fat,
                          ),
                          _MacroPill(
                            label: '${(lastParse!.confidence * 100).round()}% conf',
                            color: AppColors.success,
                          ),
                          if (lastParseSource == 'Saved')
                            const _MacroPill(
                              label: '⚡ Stored Food (No API call)',
                              color: AppColors.success,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
