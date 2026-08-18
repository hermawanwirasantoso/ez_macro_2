import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api_key_storage.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet allowing users to input, view status of, and securely store
/// their Google AI Studio (Gemini) API key.
class ApiKeyModal extends StatefulWidget {
  const ApiKeyModal({
    super.key,
    ApiKeyStorage? storage,
    this.currentKey,
    this.envKey,
  }) : storage = storage ?? const SecureApiKeyStorage();

  final ApiKeyStorage storage;
  final String? currentKey;
  final String? envKey;

  /// Displays the modal bottom sheet and returns the updated API key (or empty string if cleared),
  /// or null if dismissed without modification.
  static Future<String?> show(
    BuildContext context, {
    ApiKeyStorage? storage,
    String? currentKey,
    String? envKey,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => ApiKeyModal(
        storage: storage ?? const SecureApiKeyStorage(),
        currentKey: currentKey,
        envKey: envKey,
      ),
    );
  }

  @override
  State<ApiKeyModal> createState() => _ApiKeyModalState();
}

class _ApiKeyModalState extends State<ApiKeyModal> {
  late final TextEditingController _keyController;
  bool _obscureText = true;
  bool _isSaving = false;
  String? _savedKey;

  @override
  void initState() {
    super.initState();
    _savedKey = widget.currentKey;
    _keyController = TextEditingController(text: widget.currentKey ?? '');
    _loadStoredKey();
  }

  Future<void> _loadStoredKey() async {
    final String? stored = await widget.storage.getApiKey();
    if (mounted && stored != null && stored.isNotEmpty) {
      setState(() {
        _savedKey = stored;
        if (_keyController.text.isEmpty) {
          _keyController.text = stored;
        }
      });
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  String _maskApiKey(String key) {
    if (key.length <= 6) {
      return '••••••••';
    }
    final String suffix = key.substring(key.length - 4);
    return '••••••••$suffix';
  }

  Future<void> _handlePaste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      final String pasted = data.text!.trim();
      setState(() {
        _keyController.text = pasted;
        _keyController.selection = TextSelection.fromPosition(
          TextPosition(offset: pasted.length),
        );
      });
    }
  }

  Future<void> _handleSave() async {
    final String inputKey = _keyController.text.trim();
    if (inputKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an API key or tap Remove to clear.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.storage.saveApiKey(inputKey);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(inputKey);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key securely saved! AI logging is active.'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save API key safely: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleClear() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await widget.storage.clearApiKey();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop('');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key removed from secure storage.'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove API key: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasCustomKey = _savedKey != null && _savedKey!.isNotEmpty;
    final bool hasEnvKey =
        !hasCustomKey && (widget.envKey != null && widget.envKey!.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Drag Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Modal Title & Subtitle Header
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.key_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Google AI API Key',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Saved securely on your device keychain',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Current Storage Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: hasCustomKey
                    ? AppColors.success.withValues(alpha: 0.12)
                    : hasEnvKey
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasCustomKey
                      ? AppColors.success.withValues(alpha: 0.3)
                      : hasEnvKey
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    hasCustomKey
                        ? Icons.lock_rounded
                        : hasEnvKey
                            ? Icons.verified_user_rounded
                            : Icons.info_outline_rounded,
                    size: 18,
                    color: hasCustomKey
                        ? AppColors.success
                        : hasEnvKey
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasCustomKey
                          ? 'Active Secure Key: ${_maskApiKey(_savedKey!)}'
                          : hasEnvKey
                              ? 'Environment fallback key is currently active'
                              : 'No API key configured (using local estimates)',
                      key: const Key('apiKeyStatusText'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: hasCustomKey
                            ? (isDark ? Colors.greenAccent : Colors.green[800])
                            : hasEnvKey
                                ? (isDark ? Colors.indigoAccent : Colors.indigo[800])
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Text Input Field
            TextField(
              key: const Key('apiKeyInputField'),
              controller: _keyController,
              obscureText: _obscureText,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Google AI Studio (Gemini) Key',
                hintText: 'AIzaSy...',
                prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      key: const Key('pasteApiKeyButton'),
                      icon: const Icon(Icons.paste_rounded, size: 20),
                      tooltip: 'Paste from clipboard',
                      onPressed: _handlePaste,
                    ),
                    IconButton(
                      key: const Key('toggleApiKeyVisibilityButton'),
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      tooltip: _obscureText ? 'Show key' : 'Hide key',
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ],
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Info Card with Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.blue.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.blue.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: AppColors.streak,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Get a free Gemini API key from Google AI Studio at aistudio.google.com. Your key is stored locally with hardware-backed encryption.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons
            Row(
              children: <Widget>[
                if (hasCustomKey) ...<Widget>[
                  OutlinedButton.icon(
                    key: const Key('clearApiKeyButton'),
                    onPressed: _isSaving ? null : _handleClear,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('saveApiKeyButton'),
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save API Key',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                key: const Key('cancelApiKeyButton'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
