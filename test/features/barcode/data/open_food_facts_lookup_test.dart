import 'dart:convert';

import 'package:ez_macro_2/features/barcode/data/open_food_facts_lookup.dart';
import 'package:ez_macro_2/features/barcode/domain/product_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _nutellaPayload() {
  return <String, dynamic>{
    'code': '3017620422003',
    'status': 1,
    'product': <String, dynamic>{
      'code': '3017620422003',
      'product_name': 'Nutella',
      'brands': 'Ferrero, Nutella',
      'serving_size': '15 g',
      'serving_quantity': 15,
      'nutriments': <String, dynamic>{
        'energy-kcal_100g': 539,
        'energy-kcal_serving': 81,
        'proteins_100g': 6.3,
        'proteins_serving': 0.95,
        'carbohydrates_100g': 57.5,
        'carbohydrates_serving': 8.6,
        'fat_100g': 30.9,
        'fat_serving': 4.6,
        'saturated-fat_100g': 10.6,
        'saturated-fat_serving': 1.6,
        'fiber_100g': 3.4,
        'sugars_100g': 56.3,
        'sugars_serving': 8.4,
        'sodium_100g': 0.042,
        'salt_100g': 0.107,
      },
    },
  };
}

void main() {
  group('OpenFoodFactsProductParser', () {
    test('parses per-serving nutrition when serving data exists', () {
      final ProductInfo? product =
          OpenFoodFactsProductParser.parse(jsonEncode(_nutellaPayload()));

      expect(product, isNotNull);
      expect(product!.barcode, '3017620422003');
      expect(product.name, 'Nutella');
      expect(product.brand, 'Ferrero');
      expect(product.calories, 81);
      expect(product.proteinG, 1);
      expect(product.carbsG, 9);
      expect(product.fatG, 5);
      expect(product.saturatedFatG, 2);
      // No fiber_serving value: scaled from per-100g (3.4 * 15 / 100 = 0.5).
      expect(product.fiberG, 1);
      expect(product.sugarsG, 8);
      expect(product.sodiumMg, 6);
      expect(product.portionSize, 15);
      expect(product.portionUnit, 'g');
      expect(product.hasNutrition, isTrue);
    });

    test('falls back to per-100g values without serving data', () {
      final Map<String, dynamic> payload = <String, dynamic>{
        'code': '7622210449283',
        'status': 1,
        'product': <String, dynamic>{
          'product_name': 'Oreo',
          'nutriments': <String, dynamic>{
            'energy-kcal_100g': 480,
            'proteins_100g': 4.8,
            'carbohydrates_100g': 67.0,
            'fat_100g': 21.0,
            'saturated-fat_100g': 10.0,
            'fiber_100g': 2.5,
            'sugars_100g': 38.0,
            'salt_100g': 0.58,
          },
        },
      };

      final ProductInfo? product =
          OpenFoodFactsProductParser.parse(jsonEncode(payload));

      expect(product, isNotNull);
      expect(product!.calories, 480);
      expect(product.proteinG, 5);
      expect(product.carbsG, 67);
      expect(product.fatG, 21);
      expect(product.portionSize, 100);
      expect(product.portionUnit, 'g');
      // No sodium: derived from salt (0.58 g salt * 400 = 232 mg sodium).
      expect(product.sodiumMg, 232);
    });

    test('converts kJ energy to kcal', () {
      final Map<String, dynamic> payload = <String, dynamic>{
        'status': 1,
        'product': <String, dynamic>{
          'product_name': 'Energy Drink',
          'nutriments': <String, dynamic>{
            'energy_100g': 2100,
          },
        },
      };

      final ProductInfo? product =
          OpenFoodFactsProductParser.parse(jsonEncode(payload));

      expect(product, isNotNull);
      expect(product!.calories, 502);
    });

    test('scales per-100g energy to the serving when serving kcal missing', () {
      final Map<String, dynamic> payload = <String, dynamic>{
        'status': 1,
        'product': <String, dynamic>{
          'product_name': 'Granola Bar',
          'serving_quantity': 40,
          'nutriments': <String, dynamic>{
            'energy-kcal_100g': 450,
          },
        },
      };

      final ProductInfo? product =
          OpenFoodFactsProductParser.parse(jsonEncode(payload));

      expect(product, isNotNull);
      expect(product!.calories, 180);
      expect(product.portionSize, 40);
    });

    test('returns null for unknown products and invalid payloads', () {
      expect(
        OpenFoodFactsProductParser.parse(
          jsonEncode(<String, dynamic>{'status': 0}),
        ),
        isNull,
      );
      expect(OpenFoodFactsProductParser.parse('not json'), isNull);
      expect(OpenFoodFactsProductParser.parse(''), isNull);
    });

    test('extracts units from serving text', () {
      final Map<String, dynamic> payload = <String, dynamic>{
        'status': 1,
        'product': <String, dynamic>{
          'product_name': 'Yogurt Pot',
          'serving_size': '150 g pot',
          'serving_quantity': 150,
          'nutriments': <String, dynamic>{
            'energy-kcal_serving': 90,
          },
        },
      };

      final ProductInfo? product =
          OpenFoodFactsProductParser.parse(jsonEncode(payload));

      expect(product, isNotNull);
      expect(product!.portionUnit, 'g');
    });
  });

  group('OpenFoodFactsBarcodeLookup', () {
    test('fetches and parses a known barcode', () async {
      Uri? requestedUri;
      final MockClient mockClient = MockClient((http.Request request) async {
        requestedUri = request.url;
        return http.Response(jsonEncode(_nutellaPayload()), 200);
      });

      final OpenFoodFactsBarcodeLookup lookup = OpenFoodFactsBarcodeLookup(
        client: mockClient,
      );
      final ProductInfo? product = await lookup.lookup('3017620422003');

      expect(product, isNotNull);
      expect(product!.name, 'Nutella');
      expect(requestedUri, isNotNull);
      expect(requestedUri!.path, contains('/api/v2/product/3017620422003'));
      expect(requestedUri!.queryParameters['fields'], contains('nutriments'));
    });

    test('returns null for unknown barcodes (status 0)', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, dynamic>{'status': 0}), 200);
      });

      final OpenFoodFactsBarcodeLookup lookup = OpenFoodFactsBarcodeLookup(
        client: mockClient,
      );
      expect(await lookup.lookup('0000000000000'), isNull);
    });

    test('returns null on HTTP errors and network failures', () async {
      final MockClient errorClient = MockClient((http.Request request) async {
        return http.Response('server error', 500);
      });
      expect(
        await OpenFoodFactsBarcodeLookup(client: errorClient).lookup('123'),
        isNull,
      );

      final MockClient throwingClient = MockClient((http.Request request) async {
        throw Exception('network down');
      });
      expect(
        await OpenFoodFactsBarcodeLookup(client: throwingClient).lookup('123'),
        isNull,
      );
    });

    test('rejects empty and non-barcode input without a network call', () async {
      bool called = false;
      final MockClient mockClient = MockClient((http.Request request) async {
        called = true;
        return http.Response('{}', 200);
      });

      final OpenFoodFactsBarcodeLookup lookup = OpenFoodFactsBarcodeLookup(
        client: mockClient,
      );
      expect(await lookup.lookup(''), isNull);
      expect(await lookup.lookup('   '), isNull);
      expect(await lookup.lookup('not a barcode!'), isNull);
      expect(called, isFalse);
    });
  });
}
