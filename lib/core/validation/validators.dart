import 'package:decimal/decimal.dart';

/// Centralized validation rules for all user input fields.
/// Returns null if the value is valid, or a user-friendly error string if invalid.
class Validators {
  Validators._();

  /// Validates Indian 10-digit mobile number.
  /// Handles prefixes like '+91', '91', '0' and whitespace/dashes.
  static String? mobileNumber(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Mobile number is required' : null;
    }
    final cleaned = cleanMobileNumber(value);
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return 'Enter a valid 10-digit Indian mobile number (starts with 6-9)';
    }
    return null;
  }

  /// Clean mobile number for DB storage (returns standard 10 digits)
  static String cleanMobileNumber(String value) {
    return value.replaceAll(RegExp(r'[\s\-]'), '').replaceFirst(RegExp(r'^(\+91|91|0)'), '').trim();
  }

  /// Validates optional email address according to RFC 5322 pattern.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final pattern = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!pattern.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validates 15-character Indian GSTIN format.
  /// Example: 07AAAAA0000A1Z5
  static String? gstin(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'GSTIN is required for GST-registered shops' : null;
    }
    final clean = value.trim().toUpperCase();
    if (clean.length != 15) {
      return 'GSTIN must be exactly 15 characters';
    }
    final stateCode = int.tryParse(clean.substring(0, 2));
    if (stateCode == null || stateCode < 1 || stateCode > 38) {
      return 'Invalid GST state code (01-38)';
    }
    if (!RegExp(r'^[A-Z]{5}$').hasMatch(clean.substring(2, 7))) {
      return 'Characters 3-7 must be PAN letters (A-Z)';
    }
    if (clean[13] != 'Z') {
      return '14th character of GSTIN must be "Z"';
    }
    final pattern = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}Z[A-Z\d]{1}$');
    if (!pattern.hasMatch(clean)) {
      return 'Enter a valid 15-character GSTIN (e.g. 07AAAAA0000A1Z5)';
    }
    return null;
  }

  /// Validates Indian HSN code (2 to 8 digits).
  static String? hsnCode(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'HSN code is required' : null;
    }
    final clean = value.trim();
    if (!RegExp(r'^\d+$').hasMatch(clean)) {
      return 'HSN code must contain only digits';
    }
    if (clean.length < 2 || clean.length > 8) {
      return 'HSN code must be 2 to 8 digits';
    }
    return null;
  }

  /// Validates standard product barcode (8 to 18 digits).
  static String? barcode(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Barcode is required' : null;
    }
    final clean = value.trim();
    if (!RegExp(r'^\d+$').hasMatch(clean)) {
      return 'Barcode must contain only digits';
    }
    if (clean.length < 8 || clean.length > 18) {
      return 'Barcode must be between 8 and 18 digits';
    }
    return null;
  }

  /// Validates English product name (2 to 100 chars, allowed chars).
  static String? productNameEn(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'English product name is required';
    }
    final clean = value.trim();
    if (clean.length < 2) {
      return 'Product name must be at least 2 characters';
    }
    if (clean.length > 100) {
      return 'Product name cannot exceed 100 characters';
    }
    return null;
  }

  /// Validates Hindi product name (Devanagari script + common punctuation).
  /// Optional field (falls back to English name if left empty).
  static String? productNameHi(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final clean = value.trim();
    if (clean.length > 100) {
      return 'Hindi name cannot exceed 100 characters';
    }
    return null;
  }

  /// Validates customer name (2 to 60 chars).
  static String? customerName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Customer name is required';
    }
    final clean = value.trim();
    if (clean.length < 2) {
      return 'Customer name must be at least 2 characters';
    }
    if (clean.length > 60) {
      return 'Customer name cannot exceed 60 characters';
    }
    return null;
  }

  /// Validates 6-digit Indian Postal PIN code.
  static String? pinCode(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final clean = value.trim();
    if (clean.length != 6) {
      return 'PIN code must be exactly 6 digits';
    }
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(clean)) {
      return 'Invalid Indian PIN code (must start with 1-9)';
    }
    return null;
  }

  /// Validates 4 or 6 digit numeric staff passcode.
  static String? staffPasscode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Staff PIN is required';
    }
    final clean = value.trim();
    if (clean.length != 4 && clean.length != 6) {
      return 'Staff passcode must be 4 or 6 digits';
    }
    if (!RegExp(r'^\d+$').hasMatch(clean)) {
      return 'Staff passcode must contain only digits';
    }
    return null;
  }

  /// Validates monetary price (selling price or MRP).
  /// Must be strictly positive (> 0), with at most 2 decimal places.
  static String? price(String? value, {bool allowZero = false, bool isRequired = true, String fieldName = 'Selling Price'}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? '$fieldName is required' : null;
    }
    final clean = value.replaceAll('₹', '').replaceAll(',', '').trim();
    final parsed = Decimal.tryParse(clean);
    if (parsed == null) {
      return 'Enter a valid $fieldName';
    }
    if (parsed > Decimal.fromInt(9999999)) {
      return '$fieldName cannot exceed ₹99,99,999';
    }
    if (!allowZero && parsed <= Decimal.zero) {
      return '$fieldName must be greater than ₹0';
    }
    if (allowZero && parsed < Decimal.zero) {
      return '$fieldName cannot be negative';
    }
    return null;
  }

  /// Validates quantity for packed items (positive whole integer).
  static String? packedQuantity(String? value, {bool isRequired = true, String fieldName = 'Stock Quantity'}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? '$fieldName is required' : null;
    }
    final clean = value.trim();
    if (clean.contains('.')) {
      return 'Packed items must have whole number quantity';
    }
    final parsed = int.tryParse(clean);
    if (parsed == null || parsed <= 0) {
      return '$fieldName must be greater than 0';
    }
    return null;
  }

  /// Validates quantity for loose items (positive decimal with up to 3 decimal places).
  static String? looseQuantity(String? value, {bool isRequired = true, String fieldName = 'Stock Quantity'}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? '$fieldName is required' : null;
    }
    final clean = value.trim();
    if (clean.contains('.')) {
      final decs = clean.split('.')[1];
      if (decs.length > 3) {
        return 'Loose items support up to 3 decimal places';
      }
    }
    final parsed = Decimal.tryParse(clean);
    if (parsed == null || parsed <= Decimal.zero) {
      return '$fieldName must be greater than 0';
    }
    return null;
  }

  /// Validates discount amount against maximum allowed subtotal.
  static String? discountAmount(String? value, {required double grandTotal}) {
    if (value == null || value.trim().isEmpty) return null;
    final clean = value.replaceAll('₹', '').replaceAll(',', '').trim();
    final parsed = double.tryParse(clean);
    if (parsed == null || parsed < 0) {
      return 'Discount cannot be negative';
    }
    if (parsed > grandTotal) {
      return 'Discount cannot exceed bill total (₹${grandTotal.toStringAsFixed(2)})';
    }
    return null;
  }
}
