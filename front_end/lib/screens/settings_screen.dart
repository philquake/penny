import 'package:flutter/cupertino.dart';
import '../models/user.dart';
import '../services/budget_notification_service.dart';
import 'package:flutter/material.dart';

/// Settings screen.
///
/// Deliberately scoped to what the backend actually supports today:
/// the signed-in user's own profile (from UserOut), the server this
/// device points at, and sign out. No household member list or admin
/// tools — there's no endpoint for that yet (only signup/login exist).
/// The AI Assistant row is shown but disabled as a signpost for Phase 5,
/// not a fake feature.
class SettingsScreen extends StatefulWidget {
  final User user;
  final String serverAddress;
  final VoidCallback onSignOut;
  final VoidCallback? onChangeServer;
  final VoidCallback onManageCategories;
  final VoidCallback onNotificationsChanged;

  const SettingsScreen({
    super.key,
    required this.user,
    required this.serverAddress,
    required this.onSignOut,
    required this.onManageCategories,
    required this.onNotificationsChanged,
    this.onChangeServer,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  bool _notificationsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    final enabled = await BudgetNotificationService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _notificationsLoading = false;
    });
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    setState(() => _notificationsLoading = true);
    final allowed = await BudgetNotificationService.instance.setEnabled(enabled);
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = allowed && enabled;
      _notificationsLoading = false;
    });
    if (allowed && enabled) widget.onNotificationsChanged();
    if (enabled && !allowed) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Notifications are off'),
          content: const Text(
            'Allow notifications for Penny in your phone settings to receive budget alerts.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sign out?'),
        content: Text('You\'ll need your password to sign back in to ${widget.serverAddress}.'),
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

    if (confirmed == true) widget.onSignOut();
  }

  String get _initials {
    final parts = widget.user.fullName.trim().split(RegExp(r'\s+'));
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return CupertinoPageScaffold(
      backgroundColor: colors.surface,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: colors.surface,
            border: null,
            largeTitle: const Text('Settings'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileCard(fullName: widget.user.fullName, email: widget.user.email, initials: _initials),
                  const SizedBox(height: 8),
                  Text(
                    'Member since ${_monthNames[widget.user.createdAt.month - 1]} ${widget.user.createdAt.year}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel('Server'),
                  _SettingsGroup(rows: [
                    _SettingsRow(
                      label: 'Connected to',
                      value: widget.serverAddress,
                      icon: CupertinoIcons.wifi,
                      onTap: widget.onChangeServer,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _SectionLabel('Manage'),
                  _SettingsGroup(rows: [
                    _SettingsRow(
                      label: 'Categories',
                      icon: CupertinoIcons.square_grid_2x2,
                      onTap: widget.onManageCategories,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _SectionLabel('Alerts'),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.bell,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Budget notifications', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14)),
                              Text('Notify when a budget threshold is reached', style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: _notificationsEnabled,
                          activeTrackColor: colors.primary,
                          onChanged: _notificationsLoading
                              ? null
                              : _setNotificationsEnabled,
                        ),
                      ],
                    ),
                  ),
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
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: colors.errorContainer.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      onPressed: () => _confirmSignOut(context),
                      child: Text(
                        'Sign Out',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.error,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(email, style: theme.textTheme.bodySmall),
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 0.4)),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<_SettingsRow> rows;
  const _SettingsGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const Divider(indent: 48),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: enabled ? colors.primary : colors.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: enabled ? colors.onSurface : colors.outline,
              ),
            ),
          ),
          if (value != null) ...[
            Text(value!, style: theme.textTheme.bodySmall),
            const SizedBox(width: 6),
          ],
          if (trailingText != null)
            Text(trailingText!, style: theme.textTheme.bodySmall),
          if (enabled && onTap != null) ...[
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_right,
                size: 14, color: colors.outline),
          ],
        ],
      ),
    );

    if (!enabled || onTap == null) return content;

    return CupertinoButton(padding: EdgeInsets.zero, onPressed: onTap, child: content);
  }
}