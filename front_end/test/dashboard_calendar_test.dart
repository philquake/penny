import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/transaction_type.dart';
import 'package:penny/models/transactions.dart';
import 'package:penny/screens/dashboard_screen.dart';

void main() {
  testWidgets('dashboard shows an actionable empty budget state', (
    tester,
  ) async {
    var budgetsOpened = false;

    await tester.pumpWidget(
      CupertinoApp(
        home: DashboardScreen(
          categories: const [],
          transactions: const [],
          budgetEntries: const [],
          onAddTransaction: () {},
          onViewBudgets: () => budgetsOpened = true,
          onViewTransactions: () {},
        ),
      ),
    );

    expect(find.text('No budgets set yet'), findsOneWidget);
    expect(find.text('Create budget'), findsOneWidget);

    await tester.tap(find.text('Create budget'));
    expect(budgetsOpened, isTrue);
  });

  testWidgets('calendar totals expenses by day and excludes income', (
    tester,
  ) async {
    final today = DateTime.now();
    Transaction transaction(int id, String amount, TransactionType type) =>
        Transaction(
          id: id,
          userId: 1,
          categoryId: 1,
          amount: amount,
          type: type,
          description: null,
          transactionDate: today,
          createdAt: today,
        );

    await tester.pumpWidget(
      CupertinoApp(
        home: DashboardScreen(
          categories: const [],
          transactions: [
            transaction(1, '10.25', TransactionType.expense),
            transaction(2, '5.50', TransactionType.expense),
            transaction(3, '100.00', TransactionType.income),
          ],
          budgetEntries: const [],
          onAddTransaction: () {},
          onViewBudgets: () {},
          onViewTransactions: () {},
        ),
      ),
    );

    expect(find.text('Daily spending'), findsOneWidget);
    expect(find.text('\$15.75'), findsNWidgets(2));
  });
}
