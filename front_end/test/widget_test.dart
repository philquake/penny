import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:penny/screens/login_screen.dart';

void main() {
  testWidgets('login screen shows credentials and server settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: LoginScreen(
          onSignIn: ({required email, required password}) async => null,
        ),
      ),
    );

    expect(find.text('Penny'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    await tester.tap(find.text('Server'));
    await tester.pumpAndSettle();

    expect(find.text('Server address'), findsOneWidget);
  });
}
