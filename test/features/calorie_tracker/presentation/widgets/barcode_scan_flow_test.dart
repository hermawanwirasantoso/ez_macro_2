import 'package:ez_macro_2/features/barcode/data/barcode_scanner_source.dart';
import 'package:ez_macro_2/features/barcode/data/fake_barcode_lookup.dart';
import 'package:ez_macro_2/features/barcode/domain/barcode_lookup.dart';
import 'package:ez_macro_2/features/barcode/domain/product_info.dart';
import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/food_entry_modal.dart';
import 'package:ez_macro_2/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _scrollIntoView(WidgetTester tester, Finder finder, {double delta = 50}) async {
  if (tester.any(finder)) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    return;
  }
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

ProductInfo _oreoProduct() {
  return const ProductInfo(
    barcode: '7622210449283',
    name: 'Oreo',
    brand: 'Mondelez',
    calories: 160,
    proteinG: 1,
    carbsG: 25,
    fatG: 7,
    saturatedFatG: 3,
    fiberG: 1,
    sugarsG: 14,
    sodiumMg: 135,
    portionSize: 34,
    portionUnit: 'g',
  );
}

Widget buildTestHost(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  group('Barcode scan in FoodEntryModal', () {
    testWidgets('fills food details from a scanned barcode lookup',
        (WidgetTester tester) async {
      final FakeBarcodeScannerSource scanner =
          FakeBarcodeScannerSource(barcode: '7622210449283');
      final FakeBarcodeLookup lookup = FakeBarcodeLookup(
        products: <String, ProductInfo>{'7622210449283': _oreoProduct()},
      );

      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            barcodeScannerSource: scanner,
            onLookupBarcode: lookup.lookup,
          ),
        ),
      );

      final Finder scanButton = find.byKey(const Key('scanBarcodeButton'));
      await _scrollIntoView(tester, scanButton);
      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(scanner.scanCount, 1);
      expect(lookup.requestedBarcodes, <String>['7622210449283']);
      expect(
        tester.widget<TextField>(find.byKey(const Key('mealLabelField'))).controller?.text,
        'Oreo',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('caloriesField'))).controller?.text,
        '160',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('proteinField'))).controller?.text,
        '1',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('carbsField'))).controller?.text,
        '25',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('fatField'))).controller?.text,
        '7',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('portionInputField'))).controller?.text,
        '34',
      );
      expect(find.byKey(const Key('portionSelectorCard')), findsOneWidget);
      expect(find.text('Base: 34 g'), findsOneWidget);
      expect(find.byKey(const Key('barcodeScanSuccess')), findsOneWidget);
    });

    testWidgets('shows an error when the product is unknown',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            barcodeScannerSource: FakeBarcodeScannerSource(barcode: '999'),
            onLookupBarcode: BarcodeLookup.fake().lookup,
          ),
        ),
      );

      final Finder scanButton = find.byKey(const Key('scanBarcodeButton'));
      await _scrollIntoView(tester, scanButton);
      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No nutrition data found for barcode 999. Try scanning the nutrition label instead.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('barcodeScanSuccess')), findsNothing);
    });

    testWidgets('reports when the scan is cancelled', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            barcodeScannerSource: FakeBarcodeScannerSource(),
            onLookupBarcode: BarcodeLookup.fake().lookup,
          ),
        ),
      );

      final Finder scanButton = find.byKey(const Key('scanBarcodeButton'));
      await _scrollIntoView(tester, scanButton);
      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Scan cancelled. No barcode was detected.'),
        findsOneWidget,
      );
    });

    testWidgets('reports lookup failures gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            barcodeScannerSource: FakeBarcodeScannerSource(barcode: '123'),
            onLookupBarcode:
                BarcodeLookup.fake(error: Exception('offline')).lookup,
          ),
        ),
      );

      final Finder scanButton = find.byKey(const Key('scanBarcodeButton'));
      await _scrollIntoView(tester, scanButton);
      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not look up this barcode. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('barcode button is hidden on the edit modal',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            barcodeScannerSource: FakeBarcodeScannerSource(barcode: '123'),
            onLookupBarcode: BarcodeLookup.fake().lookup,
            initialEntry: FoodLogEntry(
              mealLabel: 'Existing Snack',
              calories: 200,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('scanBarcodeButton')), findsNothing);
    });
  });

  group('Barcode scan end-to-end', () {
    testWidgets('user scans a barcode and logs the product',
        (WidgetTester tester) async {
      final CalorieStorage storage = CalorieStorage.inMemory();

      await tester.pumpWidget(
        MacroTrackerApp(
          calorieStorage: storage,
          barcodeScannerSource:
              FakeBarcodeScannerSource(barcode: '7622210449283'),
          barcodeLookup: BarcodeLookup.fake(
            products: <String, ProductInfo>{'7622210449283': _oreoProduct()},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder quickAddBtn = find.byKey(const Key('openQuickAddButton'));
      await _scrollIntoView(tester, quickAddBtn);
      await tester.tap(quickAddBtn);
      await tester.pumpAndSettle();

      final Finder scanButton = find.byKey(const Key('scanBarcodeButton'));
      await _scrollIntoView(tester, scanButton);
      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(find.text('Base: 34 g'), findsOneWidget);

      final Finder saveButton = find.byKey(const Key('saveEntryButton'));
      await _scrollIntoView(tester, saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      await _scrollIntoView(
        tester,
        find.byKey(const Key('caloriesConsumedText')),
        delta: -50,
      );
      expect(find.text('160 / 2200 kcal'), findsOneWidget);

      final Finder entryText = find.text('Oreo - 160 kcal Barcode');
      await _scrollIntoView(tester, entryText);
      expect(entryText, findsOneWidget);

      final DailyLog? today = await storage.loadDayLog(DateTime.now());
      expect(today, isNotNull);
      expect(today!.entries, hasLength(1));
      expect(today.entries.single.sourceLabel, 'Barcode');
      expect(today.entries.single.calories, 160);
    });
  });
}
