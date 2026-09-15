import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:kirana_store/core/money/money_utils.dart';

void main() {
  group('Khata Running Balance Logic Tests', () {
    test('Calculates balance from opening balance + credit bills - payments', () {
      Decimal openingBalance = Decimal.parse('500.0');
      Decimal creditInvoice1 = Decimal.parse('350.0');
      Decimal creditInvoice2 = Decimal.parse('150.0');
      Decimal paymentReceived = Decimal.parse('600.0');

      Decimal currentBalance = openingBalance + creditInvoice1 + creditInvoice2 - paymentReceived;

      // 500 + 350 + 150 = 1000 - 600 = 400
      expect(currentBalance.toString(), equals('400'));
      expect(MoneyUtils.formatCurrency(currentBalance), equals('₹400.00'));
    });

    test('Zero balance customer when payment equals credit due', () {
      Decimal due = Decimal.parse('750.50');
      Decimal paid = Decimal.parse('750.50');
      Decimal netBalance = due - paid;
      expect(netBalance, equals(Decimal.zero));
    });
  });
}
