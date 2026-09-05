import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Login screen for Penny.
///
/// Penny is self-hosted for a small trusted group (~5 users), so this
/// screen includes a collapsed "Server" field for pointing the app at a
/// household's own instance — most users never touch it, but it's real
/// functionality this app needs, not decoration.
class LoginScreen extends StatefulWidget {
  /// Returns an error message on failure, or null on success. The screen
  /// doesn't navigate itself — the app root reacts to the session
  /// provider's state changing and swaps to the authenticated shell.
  final Future<String?> Function({
    required String email,
    required String password,
  }) onSignIn;

  const LoginScreen({super.key, required this.onSignIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverController = TextEditingController(text: 'tailscale-host:8000');
  // final _usernameController = TextEditingController();
  // final _passwordController = TextEditingController();
  final _usernameController = TextEditingController(
  text: 'test@example.com',
);

final _passwordController = TextEditingController(
  text: 'TestPassword123!',
);
  

  bool _showServerField = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorText;

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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.paper,
      child: SafeArea(
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
                        _Wordmark(),
                        const SizedBox(height: 6),
                        Text(
                          'Your ledger. Your server.',
                          textAlign: TextAlign.center,
                          style: AppType.label,
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
                          textCapitalization: TextCapitalization.none,
                        ),
                        const SizedBox(height: 14),
                        _LedgerField(
                          label: 'Password',
                          controller: _passwordController,
                          placeholder: '••••••••',
                          obscureText: _obscurePassword,
                          suffix: CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            child: Icon(
                              _obscurePassword
                                  ? CupertinoIcons.eye
                                  : CupertinoIcons.eye_slash,
                              size: 18,
                              color: AppColors.slate,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () =>
                              setState(() => _showServerField = !_showServerField),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showServerField
                                    ? CupertinoIcons.chevron_down
                                    : CupertinoIcons.chevron_right,
                                size: 12,
                                color: AppColors.slate,
                              ),
                              const SizedBox(width: 6),
                              Text('Server', style: AppType.label),
                            ],
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
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            color: AppColors.copper,
                            borderRadius: BorderRadius.circular(8),
                            onPressed: _isSubmitting ? null : _handleSignIn,
                            child: _isSubmitting
                                ? const CupertinoActivityIndicator(
                                    color: CupertinoColors.white)
                                : Text(
                                    'Sign In',
                                    style: AppType.body.copyWith(
                                      color: CupertinoColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const Spacer(flex: 4),
                        Text(
                          'Penny runs on your own hardware.\nNo accounts, no cloud, no per-query costs.',
                          textAlign: TextAlign.center,
                          style: AppType.caption,
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
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.copper,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            '1¢',
            style: AppType.amount(
              size: 20,
              weight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('Penny', style: AppType.wordmark, textAlign: TextAlign.center),
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
  final TextCapitalization textCapitalization;
  final Widget? suffix;

  const _LedgerField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.label),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          suffix: suffix,
          suffixMode: OverlayVisibilityMode.always,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          style: AppType.body,
          placeholderStyle: AppType.body.copyWith(color: AppColors.slateLight),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.hairline),
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
        color: AppColors.rust.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.rust.withValues(alpha:0.25)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle,
              size: 16, color: AppColors.rust),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppType.body.copyWith(color: AppColors.rust, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}