import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirana_store/core/db/app_database.dart';
import 'package:kirana_store/core/db/seed_data.dart';
import 'package:kirana_store/core/printing/printer_service.dart';
import 'package:kirana_store/core/settings/shop_profile.dart';
import 'package:kirana_store/features/billing/presentation/widgets/receipt_widget.dart';
import 'package:kirana_store/features/inventory/domain/product_model.dart';

const _sharma = ShopProfile(
  nameEn: 'Sharma General Store',
  nameHi: 'शर्मा जनरल स्टोर',
  addressEn: '12 Station Road, Meerut',
  phone: '9876543210',
  gstin: '09ABCDE1234F1Z5',
  upiId: 'sharma@okaxis',
  footerEn: 'Visit again',
  paperWidth: PaperWidth.mm80,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('ShopProfile model', () {
    test('toMap/fromMap round-trips every field', () {
      final restored = ShopProfile.fromMap(_sharma.toMap());
      expect(restored.toMap(), equals(_sharma.toMap()));
      expect(restored.paperWidth, PaperWidth.mm80);
    });

    test('Hindi display falls back to English when Hindi is blank', () {
      expect(_sharma.displayName(true), 'शर्मा जनरल स्टोर');
      expect(_sharma.displayAddress(true), '12 Station Road, Meerut');
      expect(_sharma.displayFooter(true), 'Visit again');
    });

    test('Empty profile still has a printable shop name', () {
      expect(ShopProfile.empty.displayName(false), isNotEmpty);
    });
  });

  group('Settings persistence', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.inMemory());
    tearDown(() => db.close());

    test('upsertSettings inserts then overwrites values', () async {
      await db.upsertSettings({'shop_name': 'A', 'gstin': 'X'});
      await db.upsertSettings({'shop_name': 'B'});
      expect(await db.getAllSettings(), {'shop_name': 'B', 'gstin': 'X'});
    });

    test('Seeding never overwrites a saved shop profile', () async {
      await db.upsertSettings(_sharma.toMap());
      await SeedData.populate(db);
      final profile = ShopProfile.fromMap(await db.getAllSettings());
      expect(profile.nameEn, 'Sharma General Store');
      expect(profile.upiId, 'sharma@okaxis');
    });

    test('Profile saved through the provider is read back by a fresh app session', () async {
      final first = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      await first.read(shopProfileProvider.future);
      await first.read(shopProfileProvider.notifier).save(_sharma);
      first.dispose();

      final second = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      final loaded = await second.read(shopProfileProvider.future);
      expect(loaded.toMap(), equals(_sharma.toMap()));

      // The printer picks up the saved paper width.
      expect(second.read(printerProvider).paperWidth, PaperWidth.mm80);
      second.dispose();
    });
  });

  testWidgets('Receipt prints the saved shop details, not sample data', (tester) async {
    final invoice = Invoice(
      id: 'inv-1',
      invoiceNo: 7,
      financialYear: '2026-27',
      invoiceType: 'gst',
      subtotal: 100,
      discount: 0,
      cgst: 0,
      sgst: 0,
      igst: 0,
      roundOff: 0,
      total: 100,
      paymentMode: 'cash',
      amountPaid: 100,
      amountDue: 0,
      status: 'active',
      createdAt: DateTime(2026, 11, 21).millisecondsSinceEpoch,
    );

    await tester.pumpWidget(MaterialApp(
      home: SingleChildScrollView(
        child: ReceiptWidget(invoice: invoice, items: const [], shop: _sharma),
      ),
    ));

    expect(find.text('Sharma General Store'), findsOneWidget);
    expect(find.text('GSTIN: 09ABCDE1234F1Z5'), findsOneWidget);
    expect(find.textContaining('9876543210'), findsOneWidget);
    expect(find.textContaining('Gupta'), findsNothing);
  });

  testWidgets('Receipt hides whatever is switched off', (tester) async {
    final invoice = Invoice(
      id: 'inv-2',
      invoiceNo: 8,
      financialYear: '2026-27',
      invoiceType: 'gst',
      subtotal: 100,
      discount: 0,
      cgst: 2.5,
      sgst: 2.5,
      igst: 0,
      roundOff: 0,
      total: 105,
      paymentMode: 'cash',
      amountPaid: 105,
      amountDue: 0,
      status: 'active',
      createdAt: DateTime(2026, 11, 21).millisecondsSinceEpoch,
    );
    final shop = _sharma.copyWith(
      receipt: const ReceiptOptions(
        showPhone: false,
        showGstin: false,
        showAddress: false,
        showTaxDetails: false,
        showPaymentDetails: false,
        showFooter: false,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: SingleChildScrollView(child: ReceiptWidget(invoice: invoice, items: const [], shop: shop)),
    ));

    expect(find.text('Sharma General Store'), findsOneWidget);
    expect(find.textContaining('09ABCDE1234F1Z5'), findsNothing);
    expect(find.textContaining('9876543210'), findsNothing);
    expect(find.textContaining('Station Road'), findsNothing);
    expect(find.textContaining('CGST'), findsNothing);
    expect(find.textContaining('Payment Mode'), findsNothing);
    expect(find.text('Visit again'), findsNothing);
  });

  test('Receipt options default sensibly and round-trip', () {
    const defaults = ReceiptOptions();
    expect(defaults.showGstin, isTrue);
    expect(defaults.autoPrint, isFalse);
    const custom = ReceiptOptions(showBarcode: true, autoPrint: true, showCustomer: false);
    final back = ReceiptOptions.fromMap(custom.toMap());
    expect(back.toMap(), custom.toMap());
    // Missing keys fall back to defaults (older saved data).
    expect(ReceiptOptions.fromMap(const {}).toMap(), defaults.toMap());
  });
}
