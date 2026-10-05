import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/screens/dashboard_screen.dart';

void main() {
  testWidgets('shows overview and expenses options in the dashboard menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          categories: const [],
          transactions: const [],
          budgetEntries: const [],
          onAddTransaction: () {},
          onViewBudgets: () {},
          onViewTransactions: () {},
        ),
      ),
    );

    expect(find.text('Overview'), findsNWidgets(2));
    expect(find.text('Expenses'), findsOneWidget);
  });
}
