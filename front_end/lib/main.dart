import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api_config.dart';
import 'models/category.dart';
import 'models/transaction_type.dart';
import 'models/transactions.dart';
import 'providers/data_providers.dart';
import 'providers/session.dart';
import 'screens/add_edit_transaction_screen.dart';
import 'screens/budgets_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'services/budget_notification_service.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/theme_x.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BudgetNotificationService.instance.initialize();
  runApp(const ProviderScope(child: PennyApp()));
}

class PennyApp extends ConsumerWidget {
  const PennyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themeProvider); // name from your theme_provider.dart
    return MaterialApp(
      title: 'Penny',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: preference.mode,
      home: const _AppRoot(),
    );
  }
}

/// Reacts to session state: a spinner while checking for a stored token,
/// the Login screen if signed out, the tabbed shell if signed in.
class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    switch (session.status) {
      case SessionStatus.bootstrapping:
        return Scaffold(
          backgroundColor: context.colors.surface,
          body: const Center(child: CircularProgressIndicator()),
        );
      case SessionStatus.signedOut:
        return LoginScreen(
          initialError: session.error,
          onSignIn: ({required email, required password}) =>
              ref.read(sessionProvider.notifier).login(email: email, password: password),
        );
      case SessionStatus.signedIn:
        return const _AppShell();
    }
  }
}

/// The authenticated app: four tabs kept alive in an IndexedStack,
/// switched with a Material NavigationBar.
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _HomeTab(
        onViewBudgets: () => setState(() => _index = 1),
      ),
      const _BudgetsTab(),
      const _ReportsTab(),
      const _SettingsTab(),
    ];

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: IndexedStack(
        index: _index,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: context.colors.surface,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_rounded), label: 'Overview'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded), label: 'Budgets'),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_rounded), label: 'Reports'),
          NavigationDestination(
              icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

/// Shared loading/error handling so each tab doesn't repeat it.
Widget _asyncBody<T>(
  BuildContext context,
  AsyncValue<T> value, {
  required Widget Function(T data) data,
}) {
  return value.when(
    data: data,
    loading: () => Scaffold(
      backgroundColor: context.colors.surface,
      body: const Center(child: CircularProgressIndicator()),
    ),
    error: (error, stack) => Scaffold(
      backgroundColor: context.colors.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Couldn\'t load data.\n$error\n$stack',
            style: context.text.bodyMedium?.copyWith(color: context.colors.error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

Future<void> _openAddEditTransaction(
  BuildContext context,
  WidgetRef ref, {
  Transaction? existing,
}) async {
  final categoriesState = ref.read(categoriesProvider);
  final categories = categoriesState.asData?.value ?? const <Category>[];

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => AddEditTransactionScreen(
        categories: categories,
        existing: existing,
        onCreate: (data) => ref.read(transactionsProvider.notifier).create(data),
        onUpdate: (id, data) =>
            ref.read(transactionsProvider.notifier).update(id, data),
        onDelete: existing == null
            ? null
            : (id) => ref.read(transactionsProvider.notifier).delete(id),
      ),
    ),
  );
}

class _HomeTab extends ConsumerWidget {
  final VoidCallback onViewBudgets;

  const _HomeTab({
    required this.onViewBudgets,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesState = ref.watch(categoriesProvider);
    final transactionsState = ref.watch(transactionsProvider);
    final budgetsState = ref.watch(budgetsProvider);

    return _asyncBody(
      context,
      categoriesState,
      data: (categories) => _asyncBody(
        context,
        transactionsState,
        data: (transactions) => _asyncBody(
          context,
          budgetsState,
          data: (budgetEntries) => DashboardScreen(
            categories: categories,
            transactions: transactions,
            budgetEntries: budgetEntries,
            onAddTransaction: () => _openAddEditTransaction(context, ref),
            onTransactionTap: (t) => _openAddEditTransaction(context, ref, existing: t),
            onViewBudgets: onViewBudgets,
          ),
        ),
      ),
    );
  }
}

class _BudgetsTab extends ConsumerWidget {
  const _BudgetsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesState = ref.watch(categoriesProvider);
    final budgetsState = ref.watch(budgetsProvider);

    return _asyncBody(context, categoriesState, data: (categories) {
      return _asyncBody(context, budgetsState, data: (entries) {
        final expenseCategories =
            categories.where((c) => c.type == TransactionType.expense).toList();
        return BudgetsScreen(
          entries: entries,
          expenseCategories: expenseCategories,
          onCreate: (data) => ref.read(budgetsProvider.notifier).create(data),
          onDelete: (id) => ref.read(budgetsProvider.notifier).delete(id),
        );
      });
    });
  }
}

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesState = ref.watch(categoriesProvider);
    final transactionsState = ref.watch(transactionsProvider);

    return _asyncBody(context, categoriesState, data: (categories) {
      return _asyncBody(context, transactionsState, data: (transactions) {
        return ReportsScreen(transactions: transactions, categories: categories);
      });
    });
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    if (user == null) {
      return Scaffold(
        backgroundColor: context.colors.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return SettingsScreen(
      user: user,
      // NOTE: the login screen's "Server" field isn't wired to
      // ApiConfig.baseUrl yet — ApiConfig is a static/global value, so a
      // custom server address typed at login doesn't actually change
      // which host requests go to. Shown here for visibility; making it
      // dynamic is a reasonable follow-up (turn ApiConfig into an
      // instance stored alongside the token, read at ApiClient creation).
      serverAddress: ApiConfig.baseUrl,
      onSignOut: () => ref.read(sessionProvider.notifier).signOut(),
      onNotificationsChanged: () =>
          ref.read(budgetsProvider.notifier).refresh(),
      onManageCategories: () {
        final categories =
            ref.read(categoriesProvider).asData?.value ?? const <Category>[];
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CategoriesScreen(
              categories: categories,
              onCreate: (data) => ref.read(categoriesProvider.notifier).create(data),
              onDelete: (id) => ref.read(categoriesProvider.notifier).delete(id),
            ),
          ),
        );
      },
    );
  }
}