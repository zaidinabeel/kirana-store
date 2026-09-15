import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:kirana_store/core/money/money_utils.dart';

void main() {
  group('Billing Calculation Engine Tests', () {
    test('Calculates multi-item cart with mixed GST rates on GST bill', () {
      final items = [
        LineItemInput(
          rate: Decimal.parse('10.0'), // ₹10 Parle-G
          qty: Decimal.parse('2'),      // 2 packets -> ₹20
          gstRate: Decimal.parse('18.0'), // 18% GST -> ₹3.60
        ),
        LineItemInput(
          rate: Decimal.parse('245.0'), // ₹245 Atta
          qty: Decimal.parse('1'),       // 1 bag -> ₹245
          gstRate: Decimal.parse('0.0'),   // 0% GST -> ₹0
        ),
      ];

      final result = MoneyUtils.calculateInvoice(items: items, isGstInvoice: true);

      expect(result.subtotal.toString(), equals('265')); // 20 + 245
      expect(result.totalTax.toString(), equals('3.6')); // 3.60
      expect(result.cgst.toString(), equals('1.8'));
      expect(result.sgst.toString(), equals('1.8'));
      expect(result.rawTotal.toString(), equals('268.6'));
      expect(result.total.toString(), equals('269')); // 268.60 rounded half up to 269
      expect(result.roundOff.toString(), equals('0.4'));
    });

    test('Toggling Non-GST removes all taxes immediately', () {
      final items = [
        LineItemInput(
          rate: Decimal.parse('100.0'),
          qty: Decimal.parse('1'),
          gstRate: Decimal.parse('18.0'),
        ),
      ];

      final result = MoneyUtils.calculateInvoice(items: items, isGstInvoice: false);
      expect(result.subtotal.toString(), equals('100'));
      expect(result.totalTax, equals(Decimal.zero));
      expect(result.total.toString(), equals('100'));
    });

    test('Calculates overall bill discount correctly', () {
      final items = [
        LineItemInput(
          rate: Decimal.parse('500.0'),
          qty: Decimal.parse('1'),
          gstRate: Decimal.zero,
        ),
      ];

      final result = MoneyUtils.calculateInvoice(
        items: items,
        isGstInvoice: false,
        overallDiscount: Decimal.fromInt(50),
      );

      expect(result.subtotal.toString(), equals('500'));
      expect(result.discount.toString(), equals('50'));
      expect(result.total.toString(), equals('450'));
    });
  });
}
