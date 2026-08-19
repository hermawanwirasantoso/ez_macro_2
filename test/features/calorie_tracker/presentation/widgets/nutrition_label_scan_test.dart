import 'package:ez_macro_2/features/calorie_tracker/data/nutrition_label_image_source.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/nutrition_label_image.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/parse_result.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/food_entry_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestHost(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('Nutrition label scan', () {
    testWidgets('fills food details from a scanned nutrition facts photo',
        (WidgetTester tester) async {
      final FakeNutritionLabelImageSource imageSource =
          FakeNutritionLabelImageSource(
        image: const NutritionLabelImage(
          bytes: <int>[9, 8, 7],
          mimeType: 'image/jpeg',
        ),
      );

      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            nutritionLabelImageSource: imageSource,
            hasConfiguredApiKey: true,
            onParseNutritionLabel: (NutritionLabelImage image, {String? hint}) async {
              expect(image.bytes, <int>[9, 8, 7]);
              return const ParseResult(
                mealLabel: 'Oat Milk',
                calories: 120,
                confidence: 0.94,
                proteinG: 3,
                carbsG: 16,
                fatG: 5,
              );
            },
          ),
        ),
      );

      expect(find.byKey(const Key('scanNutritionLabelButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('scanNutritionLabelButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('scanFromGalleryOption')));
      await tester.pumpAndSettle();

      expect(imageSource.pickCount, 1);
      expect(imageSource.lastSource, NutritionLabelPickSource.gallery);
      expect(
        tester.widget<TextField>(find.byKey(const Key('mealLabelField'))).controller?.text,
        'Oat Milk',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('caloriesField'))).controller?.text,
        '120',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('proteinField'))).controller?.text,
        '3',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('carbsField'))).controller?.text,
        '16',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('fatField'))).controller?.text,
        '5',
      );
      expect(find.textContaining('Label scanned'), findsOneWidget);
    });

    testWidgets('asks for an API key when scanning without one configured',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            nutritionLabelImageSource: FakeNutritionLabelImageSource(
              image: const NutritionLabelImage(bytes: <int>[1]),
            ),
            hasConfiguredApiKey: false,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('scanNutritionLabelButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('Add a Google AI key to scan nutrition labels.'),
        findsOneWidget,
      );
    });

    testWidgets('shows an error when the label cannot be read',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            nutritionLabelImageSource: FakeNutritionLabelImageSource(
              image: const NutritionLabelImage(bytes: <int>[1, 2, 3]),
            ),
            hasConfiguredApiKey: true,
            onParseNutritionLabel: (NutritionLabelImage image, {String? hint}) async {
              return null;
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('scanNutritionLabelButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scanFromCameraOption')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not read this nutrition label. Try a clearer photo of the facts panel.',
        ),
        findsOneWidget,
      );
    });
  });
}
