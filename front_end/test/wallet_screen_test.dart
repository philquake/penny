import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/debt.dart';
import 'package:penny/models/transaction_type.dart';
import 'package:penny/models/transactions.dart';
import 'package:penny/screens/wallet_screen.dart';

void main() {
  testWidgets('wallet totals debt and shows savings goal progress', (
    tester,
  ) async {
    final now = DateTime.now();

    await tester.pumpWidget(
      MaterialApp(
        home: WalletScreen(
          debts: const [
            Debt(
              id: 1,
              name: 'Visa',
              kind: DebtKind.creditCard,
              balance: '1000.00',
              apr: '24',
              minimumPayment: '25',
              creditLimit: '5000',
              utilizationPercent: '20',
              nextDueDate: null,
              monthlyInterestEstimate: '20.00',
            ),
          ],
          transactions: [
            Transaction(
              id: 1,
              userId: 1,
              categoryId: 1,
              amount: '250.00',
              type: TransactionType.savings,
              description: null,
              transactionDate: now,
              createdAt: now,
            ),
          ],
          savingsGoal: 1000,
          onSetGoal: (_) async {},
          onOpenDebts: () {},
        ),
      ),
    );

    expect(find.text('\$1000.00'), findsOneWidget); // debt card
    expect(find.text('\$250.00'), findsOneWidget); // savings card
    expect(find.text('25%'), findsOneWidget); // goal progress
  });
}