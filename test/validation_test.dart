import 'package:flutter_test/flutter_test.dart';
import 'package:kirana_store/core/validation/validators.dart';
import 'package:kirana_store/core/validation/formatters.dart';
import 'package:flutter/services.dart';

void main() {
  group('Validators Suite', () {
    test('mobileNumber validates 10-digit Indian numbers and prefixes', () {
      expect(Validators.mobileNumber('9876543210'), isNull);
      expect(Validators.mobileNumber('+919876543210'), isNull);
      expect(Validators.mobileNumber('09876543210'), isNull);
      expect(Validators.mobileNumber('6123456789'), isNull);
      expect(Validators.mobileNumber(''), equals('Mobile number is required'));
      expect(Validators.mobileNumber('', isRequired: false), isNull);
      expect(Validators.mobileNumber('1234567890'), equals('Enter a valid 10-digit Indian mobile number (starts with 6-9)'));
      expect(Validators.mobileNumber('98765'), equals('Enter a valid 10-digit Indian mobile number (starts with 6-9)'));
      expect(Validators.mobileNumber('987654321012345'), equals('Enter a valid 10-digit Indian mobile number (starts with 6-9)'));
    });

    test('cleanMobileNumber standardizes numbers', () {
      expect(Validators.cleanMobileNumber('+91 98765-43210'), equals('9876543210'));
      expect(Validators.cleanMobileNumber('09876543210'), equals('9876543210'));
      expect(Validators.cleanMobileNumber('9876543210'), equals('9876543210'));
    });

    test('gstin validates 15-character standard GSTIN pattern', () {
      expect(Validators.gstin('07AAAAA0000A1Z5'), isNull);
      expect(Validators.gstin('27ABCDE1234F2Z5'), isNull);
      expect(Validators.gstin(''), isNull); // Optional
      expect(Validators.gstin('07AAAAA0000A1Z'), equals('GSTIN must be exactly 15 characters'));
      expect(Validators.gstin('07AAAAA0000A1Z55'), equals('GSTIN must be exactly 15 characters'));
      expect(Validators.gstin('99AAAAA0000A1Z5'), equals('Invalid GST state code (01-38)'));
      expect(Validators.gstin('07123450000A1Z5'), equals('Characters 3-7 must be PAN letters (A-Z)'));
      expect(Validators.gstin('07AAAAA0000A1A5'), equals('14th character of GSTIN must be "Z"'));
    });

    test('hsnCode validates 2-8 digit codes', () {
      expect(Validators.hsnCode('1101'), isNull);
      expect(Validators.hsnCode('04012000'), isNull);
      expect(Validators.hsnCode(''), isNull); // Optional
      expect(Validators.hsnCode('1'), equals('HSN code must be 2 to 8 digits'));
      expect(Validators.hsnCode('123456789'), equals('HSN code must be 2 to 8 digits'));
      expect(Validators.hsnCode('11A1'), equals('HSN code must contain only digits'));
    });

    test('barcode validates 8-18 digit formats', () {
      expect(Validators.barcode('8901030383448'), isNull);
      expect(Validators.barcode('12345678'), isNull);
      expect(Validators.barcode('', isRequired: true), equals('Barcode is required'));
      expect(Validators.barcode('', isRequired: false), isNull);
      expect(Validators.barcode('12345'), equals('Barcode must be between 8 and 18 digits'));
      expect(Validators.barcode('89010303834489999999'), equals('Barcode must be between 8 and 18 digits'));
      expect(Validators.barcode('890103038A448'), equals('Barcode must contain only digits'));
    });

    test('productNameEn and productNameHi validation', () {
      expect(Validators.productNameEn('Atta 5kg'), isNull);
      expect(Validators.productNameEn(''), equals('English product name is required'));
      expect(Validators.productNameEn('A'), equals('Product name must be at least 2 characters'));

      expect(Validators.productNameHi('आटा ५ किग्रा'), isNull);
      expect(Validators.productNameHi(''), isNull); // Optional
    });

    test('customerName validation', () {
      expect(Validators.customerName('Rajesh Gupta'), isNull);
      expect(Validators.customerName(''), equals('Customer name is required'));
      expect(Validators.customerName('R'), equals('Customer name must be at least 2 characters'));
    });

    test('pinCode validation', () {
      expect(Validators.pinCode('201001'), isNull);
      expect(Validators.pinCode(''), isNull); // Optional
      expect(Validators.pinCode('011001'), equals('Invalid Indian PIN code (must start with 1-9)'));
      expect(Validators.pinCode('20100'), equals('PIN code must be exactly 6 digits'));
    });

    test('staffPasscode validation', () {
      expect(Validators.staffPasscode('1234'), isNull);
      expect(Validators.staffPasscode('123456'), isNull);
      expect(Validators.staffPasscode('123'), equals('Staff passcode must be 4 or 6 digits'));
    });

    test('price validation', () {
      expect(Validators.price('100.50'), isNull);
      expect(Validators.price('0'), equals('Selling Price must be greater than ₹0'));
      expect(Validators.price('-5'), equals('Selling Price must be greater than ₹0'));
      expect(Validators.price('abc'), equals('Enter a valid Selling Price'));
      expect(Validators.price(''), equals('Selling Price is required'));
      expect(Validators.price('', isRequired: false), isNull);
      expect(Validators.price('10000000'), equals('Selling Price cannot exceed ₹99,99,999'));
    });

    test('packedQuantity and looseQuantity validation', () {
      expect(Validators.packedQuantity('5'), isNull);
      expect(Validators.packedQuantity('5.5'), equals('Packed items must have whole number quantity'));
      expect(Validators.packedQuantity('0'), equals('Stock Quantity must be greater than 0'));

      expect(Validators.looseQuantity('0.250'), isNull);
      expect(Validators.looseQuantity('0.0001'), equals('Loose items support up to 3 decimal places'));
      expect(Validators.looseQuantity('0'), equals('Stock Quantity must be greater than 0'));
    });

    test('discountAmount validation', () {
      expect(Validators.discountAmount('10', grandTotal: 100), isNull);
      expect(Validators.discountAmount('150', grandTotal: 100), equals('Discount cannot exceed bill total (₹100.00)'));
      expect(Validators.discountAmount('-5', grandTotal: 100), equals('Discount cannot be negative'));
    });
  });

  group('TextInputFormatters Suite', () {
    test('DecimalInputFormatter restricts decimals and rejects invalid characters', () {
      final formatter = DecimalInputFormatter(2);
      
      final res1 = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '12.34'),
      );
      expect(res1.text, equals('12.34'));

      final res2 = formatter.formatEditUpdate(
        const TextEditingValue(text: '12.34'),
        const TextEditingValue(text: '12.345'),
      );
      expect(res2.text, equals('12.34')); // 3rd decimal blocked

      final res3 = formatter.formatEditUpdate(
        const TextEditingValue(text: '12.3'),
        const TextEditingValue(text: '12.3.4'),
      );
      expect(res3.text, equals('12.3')); // Multiple dots blocked

      final res4 = formatter.formatEditUpdate(
        const TextEditingValue(text: '12'),
        const TextEditingValue(text: '12a'),
      );
      expect(res4.text, equals('12')); // Alphabetic blocked
    });

    test('WholeNumberInputFormatter blocks decimals and enforces max', () {
      final formatter = WholeNumberInputFormatter(100);

      final res1 = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '50'),
      );
      expect(res1.text, equals('50'));

      final res2 = formatter.formatEditUpdate(
        const TextEditingValue(text: '50'),
        const TextEditingValue(text: '50.5'),
      );
      expect(res2.text, equals('50')); // Dot blocked

      final res3 = formatter.formatEditUpdate(
        const TextEditingValue(text: '50'),
        const TextEditingValue(text: '500'),
      );
      expect(res3.text, equals('50')); // Exceeds max 100 blocked
    });

    test('DigitsOnlyFormatter restricts length and only accepts digits', () {
      final formatter = DigitsOnlyFormatter(5);

      final res1 = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '12345'),
      );
      expect(res1.text, equals('12345'));

      final res2 = formatter.formatEditUpdate(
        const TextEditingValue(text: '12345'),
        const TextEditingValue(text: '123456'),
      );
      expect(res2.text, equals('12345')); // Over length blocked

      final res3 = formatter.formatEditUpdate(
        const TextEditingValue(text: '12'),
        const TextEditingValue(text: '12x'),
      );
      expect(res3.text, equals('12')); // Non-digit blocked
    });

    test('UppercaseInputFormatter and AlphanumericUppercaseFormatter', () {
      final upper = UppercaseInputFormatter();
      final resUpper = upper.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: 'hello'),
      );
      expect(resUpper.text, equals('HELLO'));

      final alphaUpper = AlphanumericUppercaseFormatter(5);
      final resAlpha = alphaUpper.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: 'a1-b2'),
      );
      expect(resAlpha.text, equals('A1B2')); // Hyphen stripped, capitalized
    });
  });
}
