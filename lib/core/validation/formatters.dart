import 'package:flutter/services.dart';

/// Formatter that restricts input to a decimal number with capped decimal places.
/// Blocks: multiple decimal points, negative signs, double leading zeros, excess decimals.
class DecimalInputFormatter extends TextInputFormatter {
  final int maxDecimalPlaces;
  final bool allowZero;

  DecimalInputFormatter([
    this.maxDecimalPlaces = 2,
    this.allowZero = true,
  ]);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Disallow negative sign or commas
    if (text.contains('-') || text.contains(',')) return oldValue;

    // Disallow multiple decimal points
    if (text.indexOf('.') != text.lastIndexOf('.')) return oldValue;

    // Reject double leading zeros like "00" unless it starts with "0."
    if (text.length > 1 && text.startsWith('00') && !text.startsWith('0.')) {
      return oldValue;
    }

    // Single zero is allowed if allowZero is true
    if (text == '0' && allowZero) return newValue;

    // Validate structure: digits with optional decimal point and max N decimal places
    final pattern = RegExp(r'^\d*\.?\d{0,' + maxDecimalPlaces.toString() + r'}$');
    if (!pattern.hasMatch(text)) {
      return oldValue;
    }

    return newValue;
  }
}

/// Strict positive integer only formatter for packed-item quantities.
/// Blocks: 0 as first digit, decimal points, negative signs, non-digits, and enforces maxValue.
class WholeNumberInputFormatter extends TextInputFormatter {
  final int maxValue;

  WholeNumberInputFormatter([this.maxValue = 99999]);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Must be positive whole integer without leading zero
    if (!RegExp(r'^[1-9]\d*$').hasMatch(newValue.text)) {
      return oldValue;
    }

    final val = int.tryParse(newValue.text);
    if (val == null || val > maxValue) {
      return oldValue;
    }

    return newValue;
  }
}

/// Digits-only formatter for phone, PIN, HSN, barcode fields with a strict max length.
class DigitsOnlyFormatter extends TextInputFormatter {
  final int maxLength;

  DigitsOnlyFormatter(this.maxLength);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digitsOnly.length > maxLength
        ? digitsOnly.substring(0, maxLength)
        : digitsOnly;

    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }
}

/// Force-uppercase formatter applied live as the user types (e.g. GSTIN, PAN, SKU).
class UppercaseInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Alphanumeric uppercase formatter with length capping for GSTIN/HSN/SKU.
class AlphanumericUppercaseFormatter extends TextInputFormatter {
  final int maxLength;

  AlphanumericUppercaseFormatter(this.maxLength);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final alphanumeric = newValue.text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final capped = alphanumeric.length > maxLength
        ? alphanumeric.substring(0, maxLength)
        : alphanumeric;

    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }
}
