import 'package:flutter/cupertino.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

/// Settings screen.
///
/// Deliberately scoped to what the backend actually supports today:
/// the signed-in user's own profile (from UserOut), the server this
/// device points at, and sign out. No household member list or admin
/// tools — there's no endpoint for that yet (only signup/login exist).
/// The AI Assistant row is shown but disabled as a signpost for Phase 5,
/// not a fake feature.
class SettingsScreen extends StatelessWidget {
  final User user;
  final String serverAddress;
  final VoidCallback onSignOut;
  final VoidCallback? onChangeServer;
  final VoidCallback onManageCategories;

  const SettingsScreen({
    super.key,
    required this.user,
    required this.serverAddress,
    required this.onSignOut,
    required this.onManageCategories,
    this.onChangeServer,
  });

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sign out?'),
        content: Text('You\'ll need your password to sign back in to $serverAddress.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sign Out'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) onSignOut();
  }

  String get _initials {
    final parts = user.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.paper,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: AppColors.paper,
            border: null,
            largeTitle: const Text('Settings'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileCard(fullName: user.fullName, email: user.email, initials: _initials),
                  const SizedBox(height: 8),
                  Text(
                    'Member since ${_monthNames[user.createdAt.month - 1]} ${user.createdAt.year}',
                    style: AppType.caption,
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel('Server'),
                  _SettingsGroup(rows: [
                    _SettingsRow(
                      label: 'Connected to',
                      value: serverAddress,
                      icon: CupertinoIcons.wifi,
                      onTap: onChangeServer,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _SectionLabel('Manage'),
                  _SettingsGroup(rows: [
                    _SettingsRow(
                      label: 'Categories',
                      icon: CupertinoIcons.square_grid_2x2,
                      onTap: onManageCategories,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _SectionLabel('Data'),
                  _SettingsGroup(rows: [
                    _SettingsRow(
                      label: 'Export as CSV',
                      icon: CupertinoIcons.square_arrow_up,
                      trailingText: 'Coming soon',
                      enabled: false,
                    ),
                    _SettingsRow(
                      label: 'Import from CSV',
                      icon: CupertinoIcons.square_arrow_down,
                      trailingText: 'Coming soon',
                      enabled: false,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _SectionLabel('Assistant'),
                  _SettingsGroup(rows: [
                    _SettingsRow(
                      label: 'AI Assistant',
                      icon: CupertinoIcons.sparkles,
                      trailingText: 'Coming soon',
                      enabled: false,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _SectionLabel('About'),
                  _SettingsGroup(rows: const [
                    _SettingsRow(
                      label: 'Version',
                      icon: CupertinoIcons.info_circle,
                      trailingText: '0.1.0',
                      enabled: false,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Penny runs on your own hardware.\nNo accounts, no cloud, no per-query costs.',
                      style: AppType.caption,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: AppColors.rust.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      onPressed: () => _confirmSignOut(context),
                      child: Text(
                        'Sign Out',
                        style: AppType.body.copyWith(
                          color: AppColors.rust,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String fullName;
  final String email;
  final String initials;

  const _ProfileCard({
    required this.fullName,
    required this.email,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
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
              initials,
              style: AppType.amount(
                size: 18,
                weight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName,
                    style: AppType.body.copyWith(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(email, style: AppType.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text.toUpperCase(),
          style: AppType.caption.copyWith(letterSpacing: 0.4)),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<_SettingsRow> rows;
  const _SettingsGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const LedgerDivider(indent: 48),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final String? trailingText;
  final bool enabled;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.label,
    required this.icon,
    this.value,
    this.trailingText,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: enabled ? AppColors.copperDark : AppColors.slateLight),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppType.body.copyWith(
                fontSize: 14,
                color: enabled ? AppColors.ink : AppColors.slateLight,
              ),
            ),
          ),
          if (value != null) ...[
            Text(value!, style: AppType.caption),
            const SizedBox(width: 6),
          ],
          if (trailingText != null)
            Text(trailingText!, style: AppType.caption),
          if (enabled && onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppColors.slateLight),
          ],
        ],
      ),
    );

    if (!enabled || onTap == null) return content;

    return CupertinoButton(padding: EdgeInsets.zero, onPressed: onTap, child: content);
  }
}