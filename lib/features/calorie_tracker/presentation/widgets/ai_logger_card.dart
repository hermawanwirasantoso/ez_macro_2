import 'package:flutter/material.dart';
import '../../domain/parse_result.dart';
import '../theme/app_theme.dart';

class AiLoggerCard extends StatelessWidget {
  const AiLoggerCard({
    super.key,
    required this.inputController,
    required this.isParsing,
    required this.hasConfiguredApiKey,
    required this.lastParse,
    required this.lastUsedFallback,
    required this.showSpreadDetails,
    required this.onParse,
    required this.onSelectSuggestion,
    this.onConfigureApiKey,
  });

  final TextEditingController inputController;
  final bool isParsing;
  final bool hasConfiguredApiKey;
  final ParseResult? lastParse;
  final bool lastUsedFallback;
  final bool showSpreadDetails;
  final VoidCallback onParse;
  final ValueChanged<String> onSelectSuggestion;
  final VoidCallback? onConfigureApiKey;

  static const List<String> _suggestions = <String>[
    'a bowl of rice',
    '200g of chicken breast',
    '2 eggs with toast',
    'banana smoothie 320 kcal',
    'salmon salad 450 kcal',
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFF64748B).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row with Title & Status Badge
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Log With AI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasConfiguredApiKey
                          ? 'AI key detected. If AI fails, local estimate is used.'
                          : 'No AI key detected. Running local estimate only.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('configureApiKeyButton'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: onConfigureApiKey,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: hasConfiguredApiKey
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasConfiguredApiKey
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasConfiguredApiKey ? AppColors.success : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          hasConfiguredApiKey ? 'AI Ready' : 'Local NLP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: hasConfiguredApiKey ? AppColors.success : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.settings_outlined,
                          size: 13,
                          color: hasConfiguredApiKey ? AppColors.success : AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Suggestion Chips
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final String suggestion = _suggestions[index];
                return ActionChip(
                  label: Text(
                    suggestion,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () => onSelectSuggestion(suggestion),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Input field and Parse Button
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('nlInputField'),
                  controller: inputController,
                  decoration: InputDecoration(
                    hintText: 'e.g. a bowl of rice, or chicken rice 620 kcal',
                    isDense: true,
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    suffixIcon: inputController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
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
              const SizedBox(width: 10),
              FilledButton(
                key: const Key('parseMealButton'),
                onPressed: isParsing ? null : onParse,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isParsing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.bolt, size: 18),
                          SizedBox(width: 4),
                          Text('Parse'),
                        ],
                      ),
              ),
            ],
          ),

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
                    'Detected: ${lastParse!.mealLabel}, ${lastParse!.calories} kcal, P ${lastParse!.proteinG}g C ${lastParse!.carbsG}g F ${lastParse!.fatG}g (${(lastParse!.confidence * 100).round()}% confidence) [${lastUsedFallback ? 'Local' : 'AI'}]',
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
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
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
