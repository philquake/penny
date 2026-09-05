import 'package:flutter/cupertino.dart';
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
import 'screens/transactions_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: PennyApp()));
}

class PennyApp extends StatelessWidget {
  const PennyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Penny',
      theme: AppTheme.cupertino,
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
        return const CupertinoPageScaffold(
          backgroundColor: AppColors.paper,
          child: Center(child: CupertinoActivityIndicator()),
        );
      case SessionStatus.signedOut:
        return LoginScreen(
          onSignIn: ({required email, required password}) =>
              ref.read(sessionProvider.notifier).login(email: email, password: password),
        );
      case SessionStatus.signedIn:
        return const _AppShell();
    }
  }
}

/// The authenticated app: five tabs, each its own CupertinoTabView so
/// pushed screens (Add/Edit Transaction, Categories) get their own
/// navigation stack per tab, matching standard iOS tab bar behavior.
class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: AppColors.paper,
        activeColor: AppColors.copper,
        inactiveColor: AppColors.slateLight,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.house), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.list_bullet), label: 'Transactions'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chart_bar_alt_fill), label: 'Budgets'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.graph_circle), label: 'Reports'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.settings), label: 'Settings'),
        ],
      ),
      tabBuilder: (context, index) {
        final tabs = [
          const _HomeTab(),
          const _TransactionsTab(),
          const _BudgetsTab(),
          const _ReportsTab(),
          const _SettingsTab(),
        ];
        return CupertinoTabView(builder: (context) => tabs[index]);
      },
    );
  }
}

/// Shared loading/error handling so each tab doesn't repeat it.
Widget _asyncBody<T>(
  AsyncValue<T> value, {
  required Widget Function(T data) data,
}) {
  return value.when(
    data: data,
    loading: () => const CupertinoPageScaffold(
      backgroundColor: AppColors.paper,
      child: Center(child: CupertinoActivityIndicator()),
    ),
    error: (error, stack) => CupertinoPageScaffold(
      backgroundColor: AppColors.paper,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Couldn\'t load data.\n$error',
            style: AppType.body.copyWith(color: AppColors.rust),
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
    CupertinoPageRoute(
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
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesState = ref.watch(categoriesProvider);
    final transactionsState = ref.watch(transactionsProvider);
    final budgetsState = ref.watch(budgetsProvider);

    return _asyncBody(categoriesState, data: (categories) {
      return _asyncBody(transactionsState, data: (transactions) {
        return _asyncBody(budgetsState, data: (budgetEntries) {
          return DashboardScreen(
            categories: categories,
            transactions: transactions,
            budgetEntries: budgetEntries,
            onAddTransaction: () => _openAddEditTransaction(context, ref),
            onViewBudgets: () {
              // Switching tabs programmatically isn't wired here to keep
              // this straightforward — the Budgets tab is one tap away.
            },
            onViewTransactions: () {
              // Same as above — see note on onViewBudgets.
            },
          );
        });
      });
    });
  }
}

class _TransactionsTab extends ConsumerWidget {
  const _TransactionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesState = ref.watch(categoriesProvider);
    final transactionsState = ref.watch(transactionsProvider);

    return _asyncBody(categoriesState, data: (categories) {
      return _asyncBody(transactionsState, data: (transactions) {
        return TransactionsScreen(
          transactions: transactions,
          categories: categories,
          onTransactionTap: (transaction) =>
              _openAddEditTransaction(context, ref, existing: transaction),
        );
      });
    });
  }
}

class _BudgetsTab extends ConsumerWidget {
  const _BudgetsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesState = ref.watch(categoriesProvider);
    final budgetsState = ref.watch(budgetsProvider);

    return _asyncBody(categoriesState, data: (categories) {
      return _asyncBody(budgetsState, data: (entries) {
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

    return _asyncBody(categoriesState, data: (categories) {
      return _asyncBody(transactionsState, data: (transactions) {
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
      return const CupertinoPageScaffold(
        backgroundColor: AppColors.paper,
        child: Center(child: CupertinoActivityIndicator()),
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
      onManageCategories: () {
        final categories =
            ref.read(categoriesProvider).asData?.value ?? const <Category>[];
        Navigator.of(context).push(
          CupertinoPageRoute(
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