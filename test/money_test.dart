import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:kirana_store/core/money/money_utils.dart';

void main() {
  group('MoneyUtils Financial Engine Tests', () {
    test('Decimal parsing is exact without IEEE 754 float drift', () {
      final val1 = MoneyUtils.parse('45.50');
      final val2 = MoneyUtils.parse('0.10');
      final sum = val1 + val2;
      expect(sum.toString(), equals('45.6'));
    });

    test('Reverse quantity derivation for loose items (₹50 of sugar at ₹42/kg)', () {
      final derivedQty = MoneyUtils.calculateReverseQuantity(
        targetRupeeAmount: Decimal.fromInt(50),
        pricePerUnit: Decimal.fromInt(42),
      );
      // 50 / 42 = 1.19047... -> rounded to 3 decimals = 1.190
      expect(derivedQty.toString(), equals('1.19'));
    });

    test('GST calculation split into equal CGST and SGST', () {
      final gst = MoneyUtils.computeLineGst(
        taxableAmount: Decimal.fromInt(100),
        gstRatePercent: Decimal.fromInt(18),
        isGstInvoice: true,
      );

      expect(gst.totalTax.toString(), equals('18'));
      expect(gst.cgst.toString(), equals('9'));
      expect(gst.sgst.toString(), equals('9'));
      expect(gst.igst.toString(), equals('0'));
    });

    test('Non-GST invoice returns zero tax regardless of item GST rate', () {
      final gst = MoneyUtils.computeLineGst(
        taxableAmount: Decimal.fromInt(100),
        gstRatePercent: Decimal.fromInt(18),
        isGstInvoice: false,
      );

      expect(gst.totalTax, equals(Decimal.zero));
      expect(gst.cgst, equals(Decimal.zero));
      expect(gst.sgst, equals(Decimal.zero));
    });

    test('Round-half-up applied explicitly at invoice level and round_off stored', () {
      final items = [
        LineItemInput(
          rate: Decimal.parse('33.33'),
          qty: Decimal.parse('1'),
          gstRate: Decimal.zero,
        ),
      ];

      final result = MoneyUtils.calculateInvoice(items: items, isGstInvoice: false);
      expect(result.subtotal.toString(), equals('33.33'));
      expect(result.total.toString(), equals('33')); // 33.33 rounded to 33
      expect(result.roundOff.toString(), equals('-0.33')); // 33 - 33.33 = -0.33
    });
  });
}
