import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/budget_notification_service.dart';
import '../core/theme/theme_x.dart';

/// Settings screen.
///
/// Uses the same Material 3 structure and card styling as BudgetsScreen.
/// Only settings supported by the current app/backend are actionable.
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

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final enabled = await BudgetNotificationService.instance.isEnabled();
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = enabled;
        _notificationsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _notificationsLoading = false);
    }
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    setState(() => _notificationsLoading = true);

    try {
      final allowed =
          await BudgetNotificationService.instance.setEnabled(enabled);
      if (!mounted) return;

      setState(() {
        _notificationsEnabled = allowed && enabled;
        _notificationsLoading = false;
      });

      if (allowed && enabled) {
        widget.onNotificationsChanged();
      }

      if (enabled && !allowed) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Notifications are off'),
            content: const Text(
              'Allow notifications for Penny in your phone settings '
              'to receive budget alerts.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _notificationsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update notification settings.')),
      );
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(
          'You will need your password to sign back in to '
          '${widget.serverAddress}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) widget.onSignOut();
  }

  String get _initials {
    final parts = widget.user.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: context.colors.surface,
            scrolledUnderElevation: 0,
            title: const Text('Settings'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileCard(
                    fullName: widget.user.fullName,
                    email: widget.user.email,
                    initials: _initials,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Member since '
                    '${_monthNames[widget.user.createdAt.month - 1]} '
                    '${widget.user.createdAt.year}',
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: 28),

                  const _SectionLabel('Server'),
                  _SettingsGroup(
                    rows: [
                      _SettingsRow(
                        label: 'Connected to',
                        subtitle: widget.serverAddress,
                        icon: Icons.dns_rounded,
                        onTap: widget.onChangeServer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const _SectionLabel('Manage'),
                  _SettingsGroup(
                    rows: [
                      _SettingsRow(
                        label: 'Categories',
                        subtitle: 'Manage income and expense categories',
                        icon: Icons.category_rounded,
                        onTap: widget.onManageCategories,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const _SectionLabel('Alerts'),
                  _SettingsGroup(
                    rows: [
                      _SettingsRow(
                        label: 'Budget notifications',
                        subtitle:
                            'Notify when a budget threshold is reached',
                        icon: Icons.notifications_active_rounded,
                        trailing: _notificationsLoading
                            ? SizedBox(
                                width: 42,
                                height: 24,
                                child: Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.colors.primary,
                                    ),
                                  ),
                                ),
                              )
                            : Switch.adaptive(
                                value: _notificationsEnabled,
                                activeTrackColor: context.colors.primary,
                                onChanged: _setNotificationsEnabled,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const _SectionLabel('Data'),
                  _SettingsGroup(
                    rows: const [
                      _SettingsRow(
                        label: 'Export as CSV',
                        subtitle: 'Save your transactions to a file',
                        icon: Icons.file_upload_outlined,
                        trailingText: 'Coming soon',
                        enabled: false,
                      ),
                      _SettingsRow(
                        label: 'Import from CSV',
                        subtitle: 'Import transactions from a file',
                        icon: Icons.file_download_outlined,
                        trailingText: 'Coming soon',
                        enabled: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const _SectionLabel('Assistant'),
                  _SettingsGroup(
                    rows: const [
                      _SettingsRow(
                        label: 'AI Assistant',
                        subtitle: 'Get insights into your finances',
                        icon: Icons.auto_awesome_rounded,
                        trailingText: 'Coming soon',
                        enabled: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const _SectionLabel('About'),
                  _SettingsGroup(
                    rows: const [
                      _SettingsRow(
                        label: 'Version',
                        subtitle: 'Penny personal finance',
                        icon: Icons.info_outline_rounded,
                        trailingText: '0.1.0',
                        enabled: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Penny runs on your own hardware.\n'
                      'No accounts, no cloud, no per-query costs.',
                      style: context.text.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            context.colors.errorContainer.withValues(alpha: 0.3),
                        foregroundColor: context.colors.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _confirmSignOut,
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(fontWeight: FontWeight.w600),
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: context.text.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: context.text.bodyMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
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
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: context.colors.onSurfaceVariant,
        ),
      ),
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              Divider(
                height: 1,
                indent: 48,
                color: context.colors.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final String? trailingText;
  final Widget? trailing;
  final bool enabled;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.label,
    required this.icon,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? context.colors.onSurface
        : context.colors.onSurfaceVariant;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 17,
              color: enabled
                  ? context.colors.primary
                  : context.colors.outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (trailingText != null)
            Text(
              trailingText!,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          if (enabled && onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.colors.outline,
            ),
          ],
        ],
      ),
    );

    if (!enabled || onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
