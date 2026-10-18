import 'package:ez_macro_2/features/calorie_tracker/data/api_key_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/api_key_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The key sheet is taller than the default test viewport; scroll buttons
/// into view before tapping them.
Future<void> _tapInSheet(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

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

      expect(find.text('AI API Keys'), findsOneWidget);
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

      expect(find.text('Gemini Secure Key: ••••••••1234'), findsOneWidget);
      expect(find.byKey(const Key('clearApiKeyButton')), findsOneWidget);
    });

    testWidgets('saves new API key into storage and returns key on pop', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage();
      ApiKeyModalResult? returnedKeys;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedKeys = await ApiKeyModal.show(context, storage: storage);
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
      await _tapInSheet(tester, find.byKey(const Key('saveApiKeyButton')));
      await tester.pumpAndSettle();

      expect(returnedKeys?.geminiKey, 'AIzaSyNewKey5678');
      expect(await storage.getApiKey(), 'AIzaSyNewKey5678');
      expect(find.text('API key securely saved! AI logging is active.'), findsOneWidget);
    });

    testWidgets('clears API key from storage on remove button tap', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage('AIzaSyExistingKey');
      ApiKeyModalResult? returnedKeys;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedKeys = await ApiKeyModal.show(
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

      await _tapInSheet(tester, find.byKey(const Key('clearApiKeyButton')));
      await tester.pumpAndSettle();

      expect(returnedKeys, isNotNull);
      expect(returnedKeys?.geminiKey, isNull);
      expect(await storage.getApiKey(), isNull);
      expect(find.text('Gemini key removed from secure storage.'), findsOneWidget);
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
        find.text('Gemini environment key is currently active'),
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

      await _tapInSheet(tester, find.byKey(const Key('saveApiKeyButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter an API key or tap Remove to clear.'),
        findsOneWidget,
      );
      expect(await storage.getApiKey(), isNull);
    });

    testWidgets('cancel button closes modal without saving', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage();
      ApiKeyModalResult? returnedKeys = const ApiKeyModalResult(geminiKey: 'sentinel');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedKeys = await ApiKeyModal.show(context, storage: storage);
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
      final Finder cancelButton = find.byKey(const Key('cancelApiKeyButton'));
      await tester.ensureVisible(cancelButton);
      await tester.pumpAndSettle();
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(returnedKeys, isNull);
      expect(await storage.getApiKey(), isNull);
    });

    testWidgets('saves QwenCloud backup key independently of Gemini', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage();
      ApiKeyModalResult? returnedKeys;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedKeys = await ApiKeyModal.show(context, storage: storage);
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
        find.byKey(const Key('qwenApiKeyInputField')),
        'sk-qwenBackup1234',
      );
      await _tapInSheet(tester, find.byKey(const Key('saveApiKeyButton')));
      await tester.pumpAndSettle();

      expect(returnedKeys?.qwenKey, 'sk-qwenBackup1234');
      expect(await storage.getQwenApiKey(), 'sk-qwenBackup1234');
      expect(await storage.getApiKey(), isNull);
    });

    testWidgets('saves Claude key as the primary key', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage();
      ApiKeyModalResult? returnedKeys;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedKeys = await ApiKeyModal.show(context, storage: storage);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final TextField claudeField = tester.widget<TextField>(
        find.byKey(const Key('claudeApiKeyInputField')),
      );
      expect(claudeField.obscureText, isTrue);
      expect(claudeField.enableIMEPersonalizedLearning, isFalse);

      await tester.enterText(
        find.byKey(const Key('claudeApiKeyInputField')),
        '  sk-ant-api03-claudeKey9876  ',
      );
      await _tapInSheet(tester, find.byKey(const Key('saveApiKeyButton')));
      await tester.pumpAndSettle();

      expect(returnedKeys?.claudeKey, 'sk-ant-api03-claudeKey9876');
      expect(await storage.getClaudeApiKey(), 'sk-ant-api03-claudeKey9876');
      expect(await storage.getApiKey(), isNull);
      expect(await storage.getQwenApiKey(), isNull);
    });

    testWidgets('rejects a non-Claude key in the Claude field', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage();
      ApiKeyModalResult? returnedKeys;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedKeys = await ApiKeyModal.show(context, storage: storage);
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
        find.byKey(const Key('claudeApiKeyInputField')),
        'AIzaSyWrongField',
      );
      await _tapInSheet(tester, find.byKey(const Key('saveApiKeyButton')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'That doesn\'t look like a Claude API key. Claude keys start with "sk-ant-".',
        ),
        findsOneWidget,
      );
      expect(find.text('AI API Keys'), findsOneWidget);
      expect(returnedKeys, isNull);
      expect(await storage.getClaudeApiKey(), isNull);
    });

    testWidgets('shows only a masked Claude key and never pre-fills it', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage(null, null, 'sk-ant-storedSecret4321');

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

      expect(find.text('Claude Secure Key: ••••••••4321'), findsOneWidget);
      final TextField claudeField = tester.widget<TextField>(
        find.byKey(const Key('claudeApiKeyInputField')),
      );
      expect(claudeField.controller!.text, isEmpty);
      expect(find.textContaining('storedSecret'), findsNothing);
      expect(find.byKey(const Key('clearClaudeApiKeyButton')), findsOneWidget);
    });

    testWidgets('removes the Claude key without touching backups', (WidgetTester tester) async {
      final storage = InMemoryApiKeyStorage('AIzaSyGemini', null, 'sk-ant-toRemove');
      ApiKeyModalResult? returnedKeys;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedKeys = await ApiKeyModal.show(context, storage: storage);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final Finder clearButton = find.byKey(const Key('clearClaudeApiKeyButton'));
      await tester.ensureVisible(clearButton);
      await tester.pumpAndSettle();
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(returnedKeys?.claudeKey, isNull);
      expect(returnedKeys?.geminiKey, 'AIzaSyGemini');
      expect(await storage.getClaudeApiKey(), isNull);
      expect(await storage.getApiKey(), 'AIzaSyGemini');
      expect(find.text('Claude API key removed from secure storage.'), findsOneWidget);
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

      expect(find.text('AI API Keys'), findsOneWidget);
      expect(find.byKey(const Key('apiKeyInputField')), findsOneWidget);
    });
  });
}
