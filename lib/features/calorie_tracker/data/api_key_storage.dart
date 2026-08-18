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
    FlutterSecureStorage? secureStorage,
  }) = SecureApiKeyStorage;

  /// Factory for creating an [InMemoryApiKeyStorage].
  factory ApiKeyStorage.inMemory([String? initialApiKey]) = InMemoryApiKeyStorage;

  Future<String?> getApiKey();
  Future<void> saveApiKey(String apiKey);
  Future<void> clearApiKey();
  Future<bool> hasApiKey();
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
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? _defaultStorage;

  static const String _defaultStorageKey = 'ez_macro_google_ai_api_key';

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Shared in-memory session fallback cache indexed by storageKey.
  static final Map<String, String> _memoryFallbacks = <String, String>{};

  final String storageKey;
  final FlutterSecureStorage _secureStorage;

  @override
  Future<String?> getApiKey() async {
    try {
      final String? key = await _secureStorage.read(key: storageKey);
      if (key != null && key.trim().isNotEmpty) {
        _memoryFallbacks[storageKey] = key.trim();
        return key.trim();
      }
    } catch (e) {
      _debugLog('Failed to read API key from secure storage (using fallback): $e');
    }

    final String? fallback = _memoryFallbacks[storageKey];
    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback.trim();
    }
    return null;
  }

  @override
  Future<void> saveApiKey(String apiKey) async {
    final String trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await clearApiKey();
      return;
    }

    _memoryFallbacks[storageKey] = trimmed;

    try {
      await _secureStorage.write(key: storageKey, value: trimmed);
    } catch (e) {
      _debugLog('Failed to write API key to secure storage, preserved in session cache: $e');
    }
  }

  @override
  Future<void> clearApiKey() async {
    _memoryFallbacks.remove(storageKey);
    try {
      await _secureStorage.delete(key: storageKey);
    } catch (e) {
      _debugLog('Failed to delete API key from secure storage: $e');
    }
  }

  @override
  Future<bool> hasApiKey() async {
    final String? key = await getApiKey();
    return key != null && key.isNotEmpty;
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
  InMemoryApiKeyStorage([this._storedApiKey]);

  String? _storedApiKey;

  @override
  Future<String?> getApiKey() async {
    if (_storedApiKey == null || _storedApiKey!.trim().isEmpty) {
      return null;
    }
    return _storedApiKey!.trim();
  }

  @override
  Future<void> saveApiKey(String apiKey) async {
    final String trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      _storedApiKey = null;
    } else {
      _storedApiKey = trimmed;
    }
  }

  @override
  Future<void> clearApiKey() async {
    _storedApiKey = null;
  }

  @override
  Future<bool> hasApiKey() async {
    return _storedApiKey != null && _storedApiKey!.trim().isNotEmpty;
  }
}
