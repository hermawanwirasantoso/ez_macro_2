import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api_key_storage.dart';
import '../theme/app_theme.dart';

class ApiKeyModalResult {
  const ApiKeyModalResult({
    this.geminiKey,
    this.qwenKey,
    this.claudeKey,
  });

  final String? geminiKey;
  final String? qwenKey;
  final String? claudeKey;
}

/// Modal bottom sheet allowing users to input, view status of, and securely store
/// a Claude API key (primary) plus optional Google AI Studio (Gemini) and
/// QwenCloud backup keys.
///
/// Saved keys are never loaded back into the text fields; only a masked suffix
/// is shown, so a stored key can't be revealed or copied out of the app.
class ApiKeyModal extends StatefulWidget {
  const ApiKeyModal({
    super.key,
    ApiKeyStorage? storage,
    this.currentKey,
    this.envKey,
    this.currentQwenKey,
    this.envQwenKey,
    this.currentClaudeKey,
    this.envClaudeKey,
  }) : storage = storage ?? const SecureApiKeyStorage();

  /// Prefix shared by Anthropic API keys, used to catch keys pasted into the
  /// wrong field before they're sent to the wrong provider.
  static const String claudeKeyPrefix = 'sk-ant-';

  final ApiKeyStorage storage;
  final String? currentKey;
  final String? envKey;
  final String? currentQwenKey;
  final String? envQwenKey;
  final String? currentClaudeKey;
  final String? envClaudeKey;

  /// Displays the modal bottom sheet and returns the updated keys,
  /// or null if dismissed without modification.
  static Future<ApiKeyModalResult?> show(
    BuildContext context, {
    ApiKeyStorage? storage,
    String? currentKey,
    String? envKey,
    String? currentQwenKey,
    String? envQwenKey,
    String? currentClaudeKey,
    String? envClaudeKey,
  }) {
    return showModalBottomSheet<ApiKeyModalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => ApiKeyModal(
        storage: storage ?? const SecureApiKeyStorage(),
        currentKey: currentKey,
        envKey: envKey,
        currentQwenKey: currentQwenKey,
        envQwenKey: envQwenKey,
        currentClaudeKey: currentClaudeKey,
        envClaudeKey: envClaudeKey,
      ),
    );
  }

  @override
  State<ApiKeyModal> createState() => _ApiKeyModalState();
}

class _ApiKeyModalState extends State<ApiKeyModal> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _qwenKeyController = TextEditingController();
  final TextEditingController _claudeKeyController = TextEditingController();
  bool _obscureText = true;
  bool _obscureQwenText = true;
  bool _obscureClaudeText = true;
  bool _isSaving = false;
  String? _savedKey;
  String? _savedQwenKey;
  String? _savedClaudeKey;

  @override
  void initState() {
    super.initState();
    _savedKey = widget.currentKey;
    _savedQwenKey = widget.currentQwenKey;
    _savedClaudeKey = widget.currentClaudeKey;
    _loadStoredKeys();
  }

  Future<void> _loadStoredKeys() async {
    final String? stored = await widget.storage.getApiKey();
    final String? storedQwen = await widget.storage.getQwenApiKey();
    final String? storedClaude = await widget.storage.getClaudeApiKey();
    if (!mounted) {
      return;
    }
    setState(() {
      if (stored != null && stored.isNotEmpty) {
        _savedKey = stored;
      }
      if (storedQwen != null && storedQwen.isNotEmpty) {
        _savedQwenKey = storedQwen;
      }
      if (storedClaude != null && storedClaude.isNotEmpty) {
        _savedClaudeKey = storedClaude;
      }
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _qwenKeyController.dispose();
    _claudeKeyController.dispose();
    super.dispose();
  }

  String _maskApiKey(String key) {
    if (key.length <= 6) {
      return '••••••••';
    }
    final String suffix = key.substring(key.length - 4);
    return '••••••••$suffix';
  }

  Future<void> _handlePaste(TextEditingController controller) async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      final String pasted = data.text!.trim();
      setState(() {
        controller.text = pasted;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: pasted.length),
        );
      });
    }
  }

  Future<ApiKeyModalResult> _currentResult() async {
    return ApiKeyModalResult(
      geminiKey: await widget.storage.getApiKey(),
      qwenKey: await widget.storage.getQwenApiKey(),
      claudeKey: await widget.storage.getClaudeApiKey(),
    );
  }

  Future<void> _handleSave() async {
    final String claudeInputKey = _claudeKeyController.text.trim();
    final String inputKey = _keyController.text.trim();
    final String qwenInputKey = _qwenKeyController.text.trim();
    if (claudeInputKey.isEmpty && inputKey.isEmpty && qwenInputKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an API key or tap Remove to clear.'),
        ),
      );
      return;
    }

    if (claudeInputKey.isNotEmpty &&
        !claudeInputKey.startsWith(ApiKeyModal.claudeKeyPrefix)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That doesn\'t look like a Claude API key. Claude keys start with "${ApiKeyModal.claudeKeyPrefix}".',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (claudeInputKey.isNotEmpty) {
        await widget.storage.saveClaudeApiKey(claudeInputKey);
      }
      if (inputKey.isNotEmpty) {
        await widget.storage.saveApiKey(inputKey);
      }
      if (qwenInputKey.isNotEmpty) {
        await widget.storage.saveQwenApiKey(qwenInputKey);
      }
      if (!mounted) {
        return;
      }
      final ApiKeyModalResult result = await _currentResult();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
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

  Future<void> _handleClear({
    required Future<void> Function() clear,
    required String successMessage,
    required String failureMessage,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await clear();
      if (!mounted) {
        return;
      }
      final ApiKeyModalResult result = await _currentResult();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
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
          content: Text('$failureMessage: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleClearClaude() => _handleClear(
        clear: widget.storage.clearClaudeApiKey,
        successMessage: 'Claude API key removed from secure storage.',
        failureMessage: 'Failed to remove Claude API key',
      );

  Future<void> _handleClearGemini() => _handleClear(
        clear: widget.storage.clearApiKey,
        successMessage: 'Gemini key removed from secure storage.',
        failureMessage: 'Failed to remove Gemini key',
      );

  Future<void> _handleClearQwen() => _handleClear(
        clear: widget.storage.clearQwenApiKey,
        successMessage: 'QwenCloud backup key removed from secure storage.',
        failureMessage: 'Failed to remove backup API key',
      );

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasCustomClaudeKey =
        _savedClaudeKey != null && _savedClaudeKey!.isNotEmpty;
    final bool hasEnvClaudeKey = !hasCustomClaudeKey &&
        (widget.envClaudeKey != null && widget.envClaudeKey!.isNotEmpty);
    final bool hasCustomKey = _savedKey != null && _savedKey!.isNotEmpty;
    final bool hasEnvKey =
        !hasCustomKey && (widget.envKey != null && widget.envKey!.isNotEmpty);
    final bool hasCustomQwenKey =
        _savedQwenKey != null && _savedQwenKey!.isNotEmpty;
    final bool hasEnvQwenKey = !hasCustomQwenKey &&
        (widget.envQwenKey != null && widget.envQwenKey!.isNotEmpty);
    final bool hasAnyKey = hasCustomClaudeKey ||
        hasEnvClaudeKey ||
        hasCustomKey ||
        hasEnvKey ||
        hasCustomQwenKey ||
        hasEnvQwenKey;

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
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[AppColors.primary, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
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
                        'AI API Keys',
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
                        'Claude first, Gemini and QwenCloud as backups',
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
            _buildStatusBanner(
              isDark: isDark,
              hasCustomKey: hasCustomClaudeKey,
              hasEnvKey: hasEnvClaudeKey,
              statusKey: const Key('claudeApiKeyStatusText'),
              customText: hasCustomClaudeKey
                  ? 'Claude Secure Key: ${_maskApiKey(_savedClaudeKey!)}'
                  : '',
              envText: 'Claude environment key is currently active',
              emptyText: hasAnyKey
                  ? 'Claude not configured (backups may still run)'
                  : 'No API key configured (using local estimates)',
            ),
            const SizedBox(height: 14),
            _buildKeyField(
              isDark: isDark,
              fieldKey: const Key('claudeApiKeyInputField'),
              controller: _claudeKeyController,
              obscureText: _obscureClaudeText,
              labelText: 'Claude (Anthropic) API Key',
              hintText: hasCustomClaudeKey
                  ? 'Saved. Enter a new key to replace it'
                  : '${ApiKeyModal.claudeKeyPrefix}...',
              pasteKey: const Key('pasteClaudeApiKeyButton'),
              visibilityKey: const Key('toggleClaudeApiKeyVisibilityButton'),
              onPaste: () => _handlePaste(_claudeKeyController),
              onToggleVisibility: () {
                setState(() {
                  _obscureClaudeText = !_obscureClaudeText;
                });
              },
            ),
            const SizedBox(height: 18),
            _buildStatusBanner(
              isDark: isDark,
              hasCustomKey: hasCustomKey,
              hasEnvKey: hasEnvKey,
              statusKey: const Key('apiKeyStatusText'),
              customText: hasCustomKey
                  ? 'Gemini Secure Key: ${_maskApiKey(_savedKey!)}'
                  : '',
              envText: 'Gemini environment key is currently active',
              emptyText: 'No Gemini backup key configured',
            ),
            const SizedBox(height: 14),
            _buildKeyField(
              isDark: isDark,
              fieldKey: const Key('apiKeyInputField'),
              controller: _keyController,
              obscureText: _obscureText,
              labelText: 'Google AI Studio (Gemini) Backup Key',
              hintText: hasCustomKey
                  ? 'Saved. Enter a new key to replace it'
                  : 'AIzaSy...',
              pasteKey: const Key('pasteApiKeyButton'),
              visibilityKey: const Key('toggleApiKeyVisibilityButton'),
              onPaste: () => _handlePaste(_keyController),
              onToggleVisibility: () {
                setState(() {
                  _obscureText = !_obscureText;
                });
              },
            ),
            const SizedBox(height: 18),
            _buildStatusBanner(
              isDark: isDark,
              hasCustomKey: hasCustomQwenKey,
              hasEnvKey: hasEnvQwenKey,
              statusKey: const Key('qwenApiKeyStatusText'),
              customText: hasCustomQwenKey
                  ? 'Backup Secure Key: ${_maskApiKey(_savedQwenKey!)}'
                  : '',
              envText: 'QwenCloud environment backup key is currently active',
              emptyText: 'No QwenCloud backup key configured',
            ),
            const SizedBox(height: 14),
            _buildKeyField(
              isDark: isDark,
              fieldKey: const Key('qwenApiKeyInputField'),
              controller: _qwenKeyController,
              obscureText: _obscureQwenText,
              labelText: 'QwenCloud (DeepSeek V4.1) Backup Key',
              hintText: hasCustomQwenKey
                  ? 'Saved. Enter a new key to replace it'
                  : 'sk-...',
              pasteKey: const Key('pasteQwenApiKeyButton'),
              visibilityKey: const Key('toggleQwenApiKeyVisibilityButton'),
              onPaste: () => _handlePaste(_qwenKeyController),
              onToggleVisibility: () {
                setState(() {
                  _obscureQwenText = !_obscureQwenText;
                });
              },
            ),
            const SizedBox(height: 14),
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
                      'Claude is tried first. If it fails, Gemini and then QwenCloud DeepSeek V4.1 are used as backups. Get a Claude key from platform.claude.com, a Gemini key from aistudio.google.com, and a QwenCloud key from home.qwencloud.com/api-keys. Keys are kept in this device\'s secure keychain/keystore and are only sent to their own provider.',
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
            if (hasCustomClaudeKey || hasCustomKey || hasCustomQwenKey) ...<Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  if (hasCustomClaudeKey)
                    _buildRemoveButton(
                      buttonKey: const Key('clearClaudeApiKeyButton'),
                      onPressed: _handleClearClaude,
                      icon: Icons.delete_outline_rounded,
                      label: 'Remove Claude',
                    ),
                  if (hasCustomKey)
                    _buildRemoveButton(
                      buttonKey: const Key('clearApiKeyButton'),
                      onPressed: _handleClearGemini,
                      icon: Icons.backup_outlined,
                      label: 'Remove Gemini',
                    ),
                  if (hasCustomQwenKey)
                    _buildRemoveButton(
                      buttonKey: const Key('clearQwenApiKeyButton'),
                      onPressed: _handleClearQwen,
                      icon: Icons.backup_outlined,
                      label: 'Remove Qwen',
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
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

  Widget _buildRemoveButton({
    required Key buttonKey,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return OutlinedButton.icon(
      key: buttonKey,
      onPressed: _isSaving ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(
          color: AppColors.error.withValues(alpha: 0.5),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildStatusBanner({
    required bool isDark,
    required bool hasCustomKey,
    required bool hasEnvKey,
    required Key statusKey,
    required String customText,
    required String envText,
    required String emptyText,
  }) {
    return Container(
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
                  ? customText
                  : hasEnvKey
                      ? envText
                      : emptyText,
              key: statusKey,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: hasCustomKey
                    ? (isDark ? AppColors.brandGlow : AppColors.primaryDark)
                    : hasEnvKey
                        ? AppColors.brandText(isDark)
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyField({
    required bool isDark,
    required Key fieldKey,
    required TextEditingController controller,
    required bool obscureText,
    required String labelText,
    required String hintText,
    required Key pasteKey,
    required Key visibilityKey,
    required VoidCallback onPaste,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: false,
      // Keep secrets out of keyboard learning/history (Android incognito IME).
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              key: pasteKey,
              icon: const Icon(Icons.paste_rounded, size: 20),
              tooltip: 'Paste from clipboard',
              onPressed: onPaste,
            ),
            IconButton(
              key: visibilityKey,
              icon: Icon(
                obscureText
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
              tooltip: obscureText ? 'Show key' : 'Hide key',
              onPressed: onToggleVisibility,
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
    );
  }
}
