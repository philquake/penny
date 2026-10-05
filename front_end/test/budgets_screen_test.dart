import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/budget.dart';
import 'package:penny/models/budget_entry.dart';
import 'package:penny/models/budget_period.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/transaction_type.dart';
import 'package:penny/screens/budgets_screen.dart';

void main() {
  testWidgets('shows the empty state when the last budget is removed', (
    tester,
  ) async {
    final entry = BudgetEntry(
      Budget(
        id: 1,
        userId: 1,
        categoryId: 1,
        amount: '100',
        period: BudgetPeriod.monthly,
        periodStart: DateTime(2026, 10, 1),
        periodEnd: DateTime(2026, 10, 31),
        alertThresholdPercent: 80,
      ),
      BudgetStatus(
        budgetId: 1,
        spentAmount: '0',
        remainingAmount: '100',
        percentageUsed: '0',
        status: 'normal',
        thresholdCrossed: false,
      ),
      Category(
        id: 1,
        userId: null,
        name: 'Food',
        type: TransactionType.expense,
        icon: null,
        isDefault: true,
        color: null,
      ),
    );

    Widget screen(List<BudgetEntry> entries) => MaterialApp(
      home: BudgetsScreen(
        entries: entries,
        expenseCategories: const [],
        onCreate: (_) {},
        onDelete: (_) {},
      ),
    );

    await tester.pumpWidget(screen([entry]));
    expect(find.text('No budgets yet'), findsNothing);

    await tester.pumpWidget(screen(const []));
    expect(find.text('No budgets yet'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Add Budget')).style?.color,
      Colors.white,
    );
  });
}
