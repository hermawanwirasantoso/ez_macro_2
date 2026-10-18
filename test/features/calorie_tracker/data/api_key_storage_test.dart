import 'package:ez_macro_2/features/calorie_tracker/data/api_key_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiKeyStorage factory constructors', () {
    test('ApiKeyStorage.create() returns SecureApiKeyStorage', () {
      final storage = ApiKeyStorage.create();
      expect(storage, isA<SecureApiKeyStorage>());
    });

    test('ApiKeyStorage.secure() returns SecureApiKeyStorage', () {
      final storage = ApiKeyStorage.secure();
      expect(storage, isA<SecureApiKeyStorage>());
    });

    test('ApiKeyStorage.inMemory() returns InMemoryApiKeyStorage', () async {
      final storage = ApiKeyStorage.inMemory('preset_key');
      expect(storage, isA<InMemoryApiKeyStorage>());
      expect(await storage.getApiKey(), 'preset_key');
    });
  });

  group('InMemoryApiKeyStorage', () {
    test('initializes empty or with default value', () async {
      final storage1 = InMemoryApiKeyStorage();
      expect(await storage1.getApiKey(), isNull);
      expect(await storage1.hasApiKey(), isFalse);

      final storage2 = InMemoryApiKeyStorage('test_key');
      expect(await storage2.getApiKey(), 'test_key');
      expect(await storage2.hasApiKey(), isTrue);
    });

    test('saves and trims API key', () async {
      final storage = InMemoryApiKeyStorage();
      await storage.saveApiKey('  AIzaSy123456  ');

      expect(await storage.getApiKey(), 'AIzaSy123456');
      expect(await storage.hasApiKey(), isTrue);
    });

    test('clears API key', () async {
      final storage = InMemoryApiKeyStorage('initial_key');
      expect(await storage.hasApiKey(), isTrue);

      await storage.clearApiKey();
      expect(await storage.getApiKey(), isNull);
      expect(await storage.hasApiKey(), isFalse);
    });

    test('saving empty string clears API key', () async {
      final storage = InMemoryApiKeyStorage('initial_key');
      await storage.saveApiKey('   ');
      expect(await storage.getApiKey(), isNull);
      expect(await storage.hasApiKey(), isFalse);
    });

    test('saves, reads, and clears QwenCloud backup API key independently', () async {
      final storage = InMemoryApiKeyStorage('gemini_key');
      expect(await storage.hasQwenApiKey(), isFalse);

      await storage.saveQwenApiKey('  sk-qwen-backup  ');
      expect(await storage.getQwenApiKey(), 'sk-qwen-backup');
      expect(await storage.hasQwenApiKey(), isTrue);
      expect(await storage.getApiKey(), 'gemini_key');

      await storage.clearQwenApiKey();
      expect(await storage.getQwenApiKey(), isNull);
      expect(await storage.hasQwenApiKey(), isFalse);
      expect(await storage.getApiKey(), 'gemini_key');
    });

    test('saves, reads, and clears Claude API key independently', () async {
      final storage = InMemoryApiKeyStorage('gemini_key', 'sk-qwen');
      expect(await storage.hasClaudeApiKey(), isFalse);

      await storage.saveClaudeApiKey('  sk-ant-claude-key  ');
      expect(await storage.getClaudeApiKey(), 'sk-ant-claude-key');
      expect(await storage.hasClaudeApiKey(), isTrue);

      await storage.clearClaudeApiKey();
      expect(await storage.getClaudeApiKey(), isNull);
      expect(await storage.hasClaudeApiKey(), isFalse);
      expect(await storage.getApiKey(), 'gemini_key');
      expect(await storage.getQwenApiKey(), 'sk-qwen');
    });
  });

  group('SecureApiKeyStorage with mock storage', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test('saves, reads, and clears API key safely', () async {
      final storage = SecureApiKeyStorage(
        storageKey: 'test_secure_key',
        secureStorage: const FlutterSecureStorage(),
      );

      expect(await storage.getApiKey(), isNull);
      expect(await storage.hasApiKey(), isFalse);

      await storage.saveApiKey('AIzaSySecureKey987');
      expect(await storage.getApiKey(), 'AIzaSySecureKey987');
      expect(await storage.hasApiKey(), isTrue);

      await storage.clearApiKey();
      expect(await storage.getApiKey(), isNull);
      expect(await storage.hasApiKey(), isFalse);
    });

    test('stores Claude key under its own secure storage entry', () async {
      final storage = SecureApiKeyStorage(
        storageKey: 'test_gemini_key',
        claudeStorageKey: 'test_claude_key',
        secureStorage: const FlutterSecureStorage(),
      );

      await storage.saveClaudeApiKey('sk-ant-secure-claude');
      expect(await storage.getClaudeApiKey(), 'sk-ant-secure-claude');
      expect(await storage.getApiKey(), isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'test_claude_key'),
        'sk-ant-secure-claude',
      );

      await storage.clearClaudeApiKey();
      expect(await storage.hasClaudeApiKey(), isFalse);
      expect(
        await const FlutterSecureStorage().read(key: 'test_claude_key'),
        isNull,
      );
    });

    test('retains key in session cache when secure storage throws an exception', () async {
      final storage = SecureApiKeyStorage(
        storageKey: 'test_failing_storage_key',
        secureStorage: const _FailingSecureStorage(),
      );

      expect(await storage.getApiKey(), isNull);
      expect(await storage.hasApiKey(), isFalse);

      // saveApiKey should not throw even if native secure storage fails
      await storage.saveApiKey('  AIzaSyFallbackKey123  ');
      expect(await storage.getApiKey(), 'AIzaSyFallbackKey123');
      expect(await storage.hasApiKey(), isTrue);

      // clearApiKey should clear session fallback without throwing
      await storage.clearApiKey();
      expect(await storage.getApiKey(), isNull);
      expect(await storage.hasApiKey(), isFalse);
    });
  });
}

class _FailingSecureStorage extends FlutterSecureStorage {
  const _FailingSecureStorage();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('No implementation found for method read');
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('No implementation found for method write');
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('No implementation found for method delete');
  }
}
