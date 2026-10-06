import 'package:flutter/material.dart';

import '../core/theme/theme_x.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Login screen for Penny.
///
/// Penny is self-hosted for a small trusted group (~5 users), so this
/// screen includes a collapsed "Server" field for pointing the app at a
/// household's own instance.
class LoginScreen extends StatefulWidget {
  /// Returns an error message on failure, or null on sucess. The app root
  /// reacts to the session provider and swaps to the authenticated shell.
  final Future<String?> Function({
    required String email,
    required String password,
  })
  onSignIn;

  final String? initialError;

  const LoginScreen({super.key, required this.onSignIn, this.initialError});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverController = TextEditingController(text: 'tailscale-host:8000');

  // TODO: remove the prefilled dev credentials before sharing a build.
  final _usernameController = TextEditingController(text: 'test@example.com');
  final _passwordController = TextEditingController(text: 'TestPassword123!');

  bool _showServerField = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _errorText = widget.initialError;
    _loadLastEmail();
  }

  Future<void> _loadLastEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('last_email');
      if (email != null && mounted && _usernameController.text.isEmpty) {
        _usernameController.text = email;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _errorText = 'Enter your username and password.');
      return;
    }
    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    final error = await widget.onSignIn(
      email: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorText = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 3),
                        const _Wordmark(),
                        const SizedBox(height: 6),
                        Text(
                          'Your ledger. Your server.',
                          textAlign: TextAlign.center,
                          style: context.text.labelMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(flex: 3),
                        if (_errorText != null) ...[
                          _ErrorBanner(message: _errorText!),
                          const SizedBox(height: 16),
                        ],
                        _LedgerField(
                          label: 'Username',
                          controller: _usernameController,
                          placeholder: 'phil',
                          keyboardType: TextInputType.text,
                        ),
                        const SizedBox(height: 14),
                        _LedgerField(
                          label: 'Password',
                          controller: _passwordController,
                          placeholder: '••••••••',
                          obscureText: _obscurePassword,
                          suffix: IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => _showServerField = !_showServerField,
                            ),
                            icon: Icon(
                              _showServerField
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 16,
                            ),
                            label: const Text('Server'),
                            style: TextButton.styleFrom(
                              foregroundColor: context.colors.onSurfaceVariant,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 180),
                          crossFadeState: _showServerField
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          firstChild: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _LedgerField(
                              label: 'Server address',
                              controller: _serverController,
                              placeholder: '100.x.x.x:8000',
                              keyboardType: TextInputType.url,
                            ),
                          ),
                          secondChild: const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : _handleSignIn,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.colors.onPrimary,
                                    ),
                                  )
                                : Text(
                                    'Sign In',
                                    style: context.text.bodyMedium?.copyWith(
                                      color: context.colors.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const Spacer(flex: 4),
                        Text(
                          'Penny runs on your own hardware.\n'
                          'No acounts, no cloud, no per-query costs.',
                          textAlign: TextAlign.center,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            '1¢',
            style: context.text.titleMedium?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.colors.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Penny',
          textAlign: TextAlign.center,
          style: context.text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _LedgerField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String placeholder;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;

  const _LedgerField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          style: context.text.bodyMedium,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: context.text.bodyMedium?.copyWith(
              color: context.colors.outline,
            ),
            suffixIcon: suffix,
            filled: true,
            fillColor: context.colors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: border(context.colors.outlineVariant),
            focusedBorder: border(context.colors.primary, 1.5),
            border: border(context.colors.outlineVariant),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.finance.expense.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.finance.expense.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: context.finance.expense),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.text.bodyMedium?.copyWith(
                color: context.finance.expense,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
