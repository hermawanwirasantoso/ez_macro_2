import 'package:ez_macro_2/features/calorie_tracker/data/nutrition_label_image_source.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/nutrition_label_image.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/parse_result.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/theme/app_theme.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/ai_logger_card.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/food_entry_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Manual Add and Scan Nutrition Label button visibility & polish', () {
    testWidgets('AiLoggerCard renders clear, prominent Manual Add button with text and icon',
        (WidgetTester tester) async {
      bool quickAddTapped = false;
      final TextEditingController controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiLoggerCard(
                inputController: controller,
                isParsing: false,
                hasConfiguredApiKey: true,
                lastParse: null,
                lastUsedFallback: false,
                showSpreadDetails: false,
                onParse: () {},
                onSelectSuggestion: (_) {},
                onConfigureApiKey: () {},
                onQuickAdd: () {
                  quickAddTapped = true;
                },
              ),
            ),
          ),
        ),
      );

      // Verify Manual Add button is present with text and key
      expect(find.byKey(const Key('openQuickAddButton')), findsOneWidget);
      expect(find.text('Manual Add'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // Tap Manual Add button
      await tester.tap(find.byKey(const Key('openQuickAddButton')));
      await tester.pump();

      expect(quickAddTapped, isTrue);
    });

    testWidgets('FoodEntryModal renders prominent, styled Scan Nutrition Label card',
        (WidgetTester tester) async {
      final FakeNutritionLabelImageSource imageSource = FakeNutritionLabelImageSource(
        image: const NutritionLabelImage(
          bytes: <int>[1, 2, 3],
          mimeType: 'image/jpeg',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodEntryModal(
                nutritionLabelImageSource: imageSource,
                hasConfiguredApiKey: true,
                onParseNutritionLabel: (NutritionLabelImage img, {String? hint}) async {
                  return const ParseResult(
                    mealLabel: 'Greek Yogurt',
                    calories: 130,
                    confidence: 0.95,
                    proteinG: 15,
                    carbsG: 6,
                    fatG: 0,
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Verify prominent Scan Nutrition Label card elements
      expect(find.byKey(const Key('scanNutritionLabelButton')), findsOneWidget);
      expect(find.text('Scan nutrition label'), findsOneWidget);
      expect(find.text('AI Vision'), findsOneWidget);
      expect(
        find.text('Take photo or choose from gallery to auto-fill macros'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.document_scanner_rounded), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);

      // Tap scan button to trigger photo picker sheet
      await tester.tap(find.byKey(const Key('scanNutritionLabelButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scanFromCameraOption')), findsOneWidget);
      expect(find.byKey(const Key('scanFromGalleryOption')), findsOneWidget);

      // Select camera option and verify scan completes and updates card UI
      await tester.tap(find.byKey(const Key('scanFromCameraOption')));
      await tester.pumpAndSettle();

      expect(find.text('Greek Yogurt'), findsOneWidget);
      expect(find.text('130'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Auto-filled from photo • Tap to re-scan'), findsOneWidget);
      expect(find.byKey(const Key('nutritionLabelScanSuccess')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}
