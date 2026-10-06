import 'package:flutter_test/flutter_test.dart';
import 'package:penny/services/receipt_parser.dart';

void main() {
  group('ReceiptTextParser', () {
    test(
      'extracts merchant, amount and date from a gift receipt style scan',
      () {
        const data = '''
FRESH MART
123 Main St
Date: 08/14/2026

BREAD 3.49
MILK 4.19
BANANAS 2.25
TAX 1.31
TOTAL 11.24
''';

        final result = ReceiptTextParser.parse(data);

        expect(result.merchant, 'FRESH MART');
        expect(result.amount, '11.24');
        expect(result.date, DateTime(2026, 8, 14));
      },
    );

    test('falls back to the last money value when total is not labeled', () {
      const data = '''
WHOLEFOODS
Apples 3.50
Coffee 8.99
Bagels 4.75
45.24
''';

      final result = ReceiptTextParser.parse(data);

      expect(result.merchant, 'WHOLEFOODS');
      expect(result.amount, '45.24');
      expect(result.date, isNull);
    });
  });
}
