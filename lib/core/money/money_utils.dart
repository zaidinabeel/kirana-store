import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Financial computation engine strictly using [Decimal].
/// Eliminates IEEE 754 floating point imprecision in billing, taxes, and weight math.
class MoneyUtils {
  MoneyUtils._();

  static final _indianCurrencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final _quantityFormat = NumberFormat('#,##0.###', 'en_IN');

  /// Parse double/string/num safely into Decimal
  static Decimal parse(dynamic val) {
    if (val == null) return Decimal.zero;
    if (val is Decimal) return val;
    if (val is num) return Decimal.parse(val.toString());
    if (val is String) {
      final clean = val.replaceAll('₹', '').replaceAll(',', '').trim();
      if (clean.isEmpty) return Decimal.zero;
      return Decimal.tryParse(clean) ?? Decimal.zero;
    }
    return Decimal.zero;
  }

  /// Format Decimal to Indian Currency String (e.g. ₹1,450.50)
  static String formatCurrency(Decimal amount) {
    return _indianCurrencyFormat.format(amount.toDouble());
  }

  /// Format Decimal to Indian Currency without symbol (e.g. 1,450.50)
  static String formatAmount(Decimal amount) {
    return NumberFormat('#,##,##0.00', 'en_IN').format(amount.toDouble());
  }

  /// Format Quantity with appropriate unit precision (e.g. 1.250 kg or 5 piece)
  static String formatQuantity(Decimal qty, String unit) {
    if (unit.toLowerCase() == 'piece' || unit.toLowerCase() == 'box') {
      return '${qty.toBigInt()} $unit';
    }
    return '${_quantityFormat.format(qty.toDouble())} $unit';
  }

  /// Compute line item total: (rate * qty) - discount
  static Decimal computeLineTotal({
    required Decimal rate,
    required Decimal qty,
    Decimal? discount,
  }) {
    final d = discount ?? Decimal.zero;
    final subtotal = rate * qty;
    final total = subtotal - d;
    return total < Decimal.zero ? Decimal.zero : total;
  }

  /// Calculate GST components for a line item
  static GstBreakdown computeLineGst({
    required Decimal taxableAmount,
    required Decimal gstRatePercent,
    required bool isGstInvoice,
    bool isInterState = false,
  }) {
    if (!isGstInvoice || gstRatePercent <= Decimal.zero) {
      return GstBreakdown.zero();
    }

    final hundred = Decimal.fromInt(100);
    final two = Decimal.fromInt(2);
    
    // Tax = (taxableAmount * gstRate) / 100
    final gstAmount = ((taxableAmount * gstRatePercent) / hundred).toDecimal(scaleOnInfinitePrecision: 4);

    if (isInterState) {
      return GstBreakdown(
        cgst: Decimal.zero,
        sgst: Decimal.zero,
        igst: gstAmount,
        totalTax: gstAmount,
      );
    } else {
      final halfTax = (gstAmount / two).toDecimal(scaleOnInfinitePrecision: 4);
      return GstBreakdown(
        cgst: halfTax,
        sgst: halfTax,
        igst: Decimal.zero,
        totalTax: gstAmount,
      );
    }
  }

  /// Reverse quantity calculation for loose items:
  /// e.g. Customer asks for "₹50 of sugar" at ₹42/kg -> qty = 50 / 42 = 1.190 kg
  static Decimal calculateReverseQuantity({
    required Decimal targetRupeeAmount,
    required Decimal pricePerUnit,
  }) {
    if (pricePerUnit <= Decimal.zero || targetRupeeAmount <= Decimal.zero) {
      return Decimal.zero;
    }

    // Precise division to 3 decimal places (grams level)
    final quotient = (targetRupeeAmount / pricePerUnit).toDecimal(
      scaleOnInfinitePrecision: 3,
    );
    return quotient;
  }

  /// Calculate full invoice totals, applying round-half-up to the nearest integer rupee
  /// only at the very final total, storing round_off explicitly.
  static InvoiceCalculationResult calculateInvoice({
    required List<LineItemInput> items,
    required bool isGstInvoice,
    Decimal? overallDiscount,
    bool isInterState = false,
  }) {
    Decimal subtotal = Decimal.zero;
    Decimal totalCgst = Decimal.zero;
    Decimal totalSgst = Decimal.zero;
    Decimal totalIgst = Decimal.zero;

    for (final item in items) {
      final lineSubtotal = computeLineTotal(
        rate: item.rate,
        qty: item.qty,
        discount: item.discount,
      );
      subtotal += lineSubtotal;

      final gst = computeLineGst(
        taxableAmount: lineSubtotal,
        gstRatePercent: item.gstRate,
        isGstInvoice: isGstInvoice,
        isInterState: isInterState,
      );

      totalCgst += gst.cgst;
      totalSgst += gst.sgst;
      totalIgst += gst.igst;
    }

    final billDiscount = overallDiscount ?? Decimal.zero;
    final totalTax = totalCgst + totalSgst + totalIgst;
    final rawTotal = (subtotal + totalTax) - billDiscount;

    // Round half up to nearest integer rupee
    final finalRoundedTotal = rawTotal.round();
    final roundOff = finalRoundedTotal - rawTotal;

    return InvoiceCalculationResult(
      subtotal: subtotal,
      discount: billDiscount,
      cgst: totalCgst,
      sgst: totalSgst,
      igst: totalIgst,
      totalTax: totalTax,
      rawTotal: rawTotal,
      roundOff: roundOff,
      total: finalRoundedTotal,
    );
  }
}

class LineItemInput {
  final Decimal rate;
  final Decimal qty;
  final Decimal gstRate;
  final Decimal discount;

  LineItemInput({
    required this.rate,
    required this.qty,
    required this.gstRate,
    Decimal? discount,
  }) : discount = discount ?? Decimal.zero;
}

class GstBreakdown {
  final Decimal cgst;
  final Decimal sgst;
  final Decimal igst;
  final Decimal totalTax;

  const GstBreakdown({
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.totalTax,
  });

  factory GstBreakdown.zero() => GstBreakdown(
    cgst: Decimal.zero,
    sgst: Decimal.zero,
    igst: Decimal.zero,
    totalTax: Decimal.zero,
  );
}

class InvoiceCalculationResult {
  final Decimal subtotal;
  final Decimal discount;
  final Decimal cgst;
  final Decimal sgst;
  final Decimal igst;
  final Decimal totalTax;
  final Decimal rawTotal;
  final Decimal roundOff;
  final Decimal total;

  InvoiceCalculationResult({
    required this.subtotal,
    required this.discount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.totalTax,
    required this.rawTotal,
    required this.roundOff,
    required this.total,
  });
}
