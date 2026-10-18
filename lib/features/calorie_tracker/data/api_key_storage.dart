import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstract storage interface for securely storing and retrieving the API key.
abstract class ApiKeyStorage {
  const ApiKeyStorage();

  /// Default factory returning a [SecureApiKeyStorage] instance.
  factory ApiKeyStorage.create() => const SecureApiKeyStorage();

  /// Factory for creating a [SecureApiKeyStorage].
  factory ApiKeyStorage.secure({
    String storageKey,
    String qwenStorageKey,
    String claudeStorageKey,
    FlutterSecureStorage? secureStorage,
  }) = SecureApiKeyStorage;

  /// Factory for creating an [InMemoryApiKeyStorage].
  factory ApiKeyStorage.inMemory([
    String? initialApiKey,
    String? initialQwenApiKey,
    String? initialClaudeApiKey,
  ]) = InMemoryApiKeyStorage;

  Future<String?> getApiKey();
  Future<void> saveApiKey(String apiKey);
  Future<void> clearApiKey();
  Future<bool> hasApiKey();

  Future<String?> getQwenApiKey();
  Future<void> saveQwenApiKey(String apiKey);
  Future<void> clearQwenApiKey();
  Future<bool> hasQwenApiKey();

  Future<String?> getClaudeApiKey();
  Future<void> saveClaudeApiKey(String apiKey);
  Future<void> clearClaudeApiKey();
  Future<bool> hasClaudeApiKey();
}

/// Production implementation of [ApiKeyStorage] backed by [FlutterSecureStorage].
///
/// Features an in-memory session cache fallback so that if secure storage is
/// unavailable (such as during hot-reload sessions before a full rebuild or on
/// environments where secure keychain channel handlers are unlinked), the user
/// can still input and use their API key without crashes or disruptions.
class SecureApiKeyStorage implements ApiKeyStorage {
  const SecureApiKeyStorage({
    this.storageKey = _defaultStorageKey,
    this.qwenStorageKey = _defaultQwenStorageKey,
    this.claudeStorageKey = _defaultClaudeStorageKey,
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? _defaultStorage;

  static const String _defaultStorageKey = 'ez_macro_google_ai_api_key';
  static const String _defaultQwenStorageKey = 'ez_macro_qwencloud_api_key';
  static const String _defaultClaudeStorageKey = 'ez_macro_anthropic_api_key';

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Shared in-memory session fallback cache indexed by storageKey.
  static final Map<String, String> _memoryFallbacks = <String, String>{};

  final String storageKey;
  final String qwenStorageKey;
  final String claudeStorageKey;
  final FlutterSecureStorage _secureStorage;

  @override
  Future<String?> getApiKey() => _read(storageKey, 'API key');

  @override
  Future<void> saveApiKey(String apiKey) =>
      _write(storageKey, apiKey, 'API key');

  @override
  Future<void> clearApiKey() => _delete(storageKey, 'API key');

  @override
  Future<bool> hasApiKey() => _has(getApiKey());

  @override
  Future<String?> getQwenApiKey() => _read(qwenStorageKey, 'QwenCloud API key');

  @override
  Future<void> saveQwenApiKey(String apiKey) =>
      _write(qwenStorageKey, apiKey, 'QwenCloud API key');

  @override
  Future<void> clearQwenApiKey() =>
      _delete(qwenStorageKey, 'QwenCloud API key');

  @override
  Future<bool> hasQwenApiKey() => _has(getQwenApiKey());

  @override
  Future<String?> getClaudeApiKey() =>
      _read(claudeStorageKey, 'Claude API key');

  @override
  Future<void> saveClaudeApiKey(String apiKey) =>
      _write(claudeStorageKey, apiKey, 'Claude API key');

  @override
  Future<void> clearClaudeApiKey() =>
      _delete(claudeStorageKey, 'Claude API key');

  @override
  Future<bool> hasClaudeApiKey() => _has(getClaudeApiKey());

  Future<String?> _read(String key, String label) async {
    try {
      final String? value = await _secureStorage.read(key: key);
      if (value != null && value.trim().isNotEmpty) {
        _memoryFallbacks[key] = value.trim();
        return value.trim();
      }
    } catch (e) {
      _debugLog('Failed to read $label from secure storage (using fallback): $e');
    }

    final String? fallback = _memoryFallbacks[key];
    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback.trim();
    }
    return null;
  }

  Future<void> _write(String key, String value, String label) async {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _delete(key, label);
      return;
    }

    _memoryFallbacks[key] = trimmed;

    try {
      await _secureStorage.write(key: key, value: trimmed);
    } catch (e) {
      _debugLog(
        'Failed to write $label to secure storage, preserved in session cache: $e',
      );
    }
  }

  Future<void> _delete(String key, String label) async {
    _memoryFallbacks.remove(key);
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      _debugLog('Failed to delete $label from secure storage: $e');
    }
  }

  static Future<bool> _has(Future<String?> read) async {
    final String? value = await read;
    return value != null && value.isNotEmpty;
  }

  void _debugLog(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }
}

/// In-memory implementation of [ApiKeyStorage] for testing or ephemeral sessions.
class InMemoryApiKeyStorage implements ApiKeyStorage {
  InMemoryApiKeyStorage([
    this._storedApiKey,
    this._storedQwenApiKey,
    this._storedClaudeApiKey,
  ]);

  String? _storedApiKey;
  String? _storedQwenApiKey;
  String? _storedClaudeApiKey;

  @override
  Future<String?> getApiKey() async => _normalize(_storedApiKey);

  @override
  Future<void> saveApiKey(String apiKey) async {
    _storedApiKey = _normalize(apiKey);
  }

  @override
  Future<void> clearApiKey() async {
    _storedApiKey = null;
  }

  @override
  Future<bool> hasApiKey() async => _normalize(_storedApiKey) != null;

  @override
  Future<String?> getQwenApiKey() async => _normalize(_storedQwenApiKey);

  @override
  Future<void> saveQwenApiKey(String apiKey) async {
    _storedQwenApiKey = _normalize(apiKey);
  }

  @override
  Future<void> clearQwenApiKey() async {
    _storedQwenApiKey = null;
  }

  @override
  Future<bool> hasQwenApiKey() async => _normalize(_storedQwenApiKey) != null;

  @override
  Future<String?> getClaudeApiKey() async => _normalize(_storedClaudeApiKey);

  @override
  Future<void> saveClaudeApiKey(String apiKey) async {
    _storedClaudeApiKey = _normalize(apiKey);
  }

  @override
  Future<void> clearClaudeApiKey() async {
    _storedClaudeApiKey = null;
  }

  @override
  Future<bool> hasClaudeApiKey() async =>
      _normalize(_storedClaudeApiKey) != null;

  static String? _normalize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }
}
