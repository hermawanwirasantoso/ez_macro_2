import 'package:ez_macro_2/features/calorie_tracker/data/api_key_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/api_key_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiKeyModal', () {
    testWidgets('renders initial modal state with empty key', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, storage: storage),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Google AI API Key'), findsOneWidget);
      expect(find.byKey(const Key('apiKeyInputField')), findsOneWidget);
      expect(find.byKey(const Key('saveApiKeyButton')), findsOneWidget);
      expect(find.byKey(const Key('clearApiKeyButton')), findsNothing);
      expect(find.text('No API key configured (using local estimates)'), findsOneWidget);
    });

    testWidgets('displays masked active key and remove button when key exists', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage('AIzaSySecretKey1234');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(
                  context,
                  storage: storage,
                  currentKey: 'AIzaSySecretKey1234',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Active Secure Key: ••••••••1234'), findsOneWidget);
      expect(find.byKey(const Key('clearApiKeyButton')), findsOneWidget);
    });

    testWidgets('saves new API key into storage and returns key on pop', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage();
      String? returnedKey;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedKey = await ApiKeyModal.show(context, storage: storage);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('apiKeyInputField')),
        'AIzaSyNewKey5678',
      );
      await tester.tap(find.byKey(const Key('saveApiKeyButton')));
      await tester.pumpAndSettle();

      expect(returnedKey, 'AIzaSyNewKey5678');
      expect(await storage.getApiKey(), 'AIzaSyNewKey5678');
      expect(find.text('API key securely saved! AI logging is active.'), findsOneWidget);
    });

    testWidgets('clears API key from storage on remove button tap', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage('AIzaSyExistingKey');
      String? returnedKey;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedKey = await ApiKeyModal.show(
                    context,
                    storage: storage,
                    currentKey: 'AIzaSyExistingKey',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('clearApiKeyButton')));
      await tester.pumpAndSettle();

      expect(returnedKey, '');
      expect(await storage.getApiKey(), isNull);
      expect(find.text('API key removed from secure storage.'), findsOneWidget);
    });

    testWidgets('toggles visibility of key input', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, storage: storage),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final TextField fieldInitial = tester.widget<TextField>(
        find.byKey(const Key('apiKeyInputField')),
      );
      expect(fieldInitial.obscureText, isTrue);

      await tester.tap(find.byKey(const Key('toggleApiKeyVisibilityButton')));
      await tester.pumpAndSettle();

      final TextField fieldToggled = tester.widget<TextField>(
        find.byKey(const Key('apiKeyInputField')),
      );
      expect(fieldToggled.obscureText, isFalse);
    });
    testWidgets('displays environment key status banner when envKey is present and no custom key', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(
                  context,
                  storage: storage,
                  envKey: 'AIzaSyEnvKeyFallback',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.text('Environment fallback key is currently active'),
        findsOneWidget,
      );
    });

    testWidgets('shows warning snackbar when attempting to save empty text', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, storage: storage),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveApiKeyButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter an API key or tap Remove to clear.'),
        findsOneWidget,
      );
      expect(await storage.getApiKey(), isNull);
    });

    testWidgets('cancel button closes modal without saving', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage();
      String? returnedKey = 'sentinel';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedKey = await ApiKeyModal.show(context, storage: storage);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('apiKeyInputField')),
        'AIzaSyDiscardedKey',
      );
      await tester.tap(find.byKey(const Key('cancelApiKeyButton')));
      await tester.pumpAndSettle();

      expect(returnedKey, isNull);
      expect(await storage.getApiKey(), isNull);
    });

    testWidgets('renders properly when storage is omitted or null', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, storage: null),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Google AI API Key'), findsOneWidget);
      expect(find.byKey(const Key('apiKeyInputField')), findsOneWidget);
    });
  });
}
