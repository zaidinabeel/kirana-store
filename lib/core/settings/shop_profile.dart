import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/seed_data.dart';
import '../printing/paper_width.dart';
import '../../features/inventory/domain/product_model.dart';

/// Keys used in the `settings` key-value table.
class SettingKeys {
  static const shopName = 'shop_name';
  static const shopNameHi = 'shop_name_hi';
  static const shopAddress = 'shop_address';
  static const shopAddressHi = 'shop_address_hi';
  static const shopPhone = 'shop_phone';
  static const gstin = 'gstin';
  static const upiId = 'upi_id';
  static const billFooter = 'bill_footer';
  static const billFooterHi = 'bill_footer_hi';
  static const paperWidth = 'paper_width';

  // Receipt print toggles ('1' = on, '0' = off)
  static const showAddress = 'rcpt_show_address';
  static const showPhone = 'rcpt_show_phone';
  static const showGstin = 'rcpt_show_gstin';
  static const showCustomer = 'rcpt_show_customer';
  static const showTaxDetails = 'rcpt_show_tax';
  static const showPaymentDetails = 'rcpt_show_payment';
  static const showBarcode = 'rcpt_show_barcode';
  static const showFooter = 'rcpt_show_footer';
  static const autoPrint = 'rcpt_auto_print';

  // Non-profile app settings
  static const appLanguage = 'app_language';
  static const onboarded = 'onboarded';
  static const lastBackupAt = 'last_backup_at';
  static const printerMac = 'printer_mac';
  static const printerName = 'printer_name';
}

/// What gets printed on the receipt. Every item can be switched on/off in Settings.
class ReceiptOptions {
  final bool showAddress;
  final bool showPhone;
  final bool showGstin;
  final bool showCustomer;
  final bool showTaxDetails;
  final bool showPaymentDetails;
  final bool showBarcode;
  final bool showFooter;

  /// Print automatically as soon as a bill is saved.
  final bool autoPrint;

  const ReceiptOptions({
    this.showAddress = true,
    this.showPhone = true,
    this.showGstin = true,
    this.showCustomer = true,
    this.showTaxDetails = true,
    this.showPaymentDetails = true,
    this.showBarcode = false,
    this.showFooter = true,
    this.autoPrint = false,
  });

  static bool _flag(Map<String, String> m, String key, bool fallback) {
    final v = m[key];
    if (v == null) return fallback;
    return v == '1';
  }

  factory ReceiptOptions.fromMap(Map<String, String> m) {
    const d = ReceiptOptions();
    return ReceiptOptions(
      showAddress: _flag(m, SettingKeys.showAddress, d.showAddress),
      showPhone: _flag(m, SettingKeys.showPhone, d.showPhone),
      showGstin: _flag(m, SettingKeys.showGstin, d.showGstin),
      showCustomer: _flag(m, SettingKeys.showCustomer, d.showCustomer),
      showTaxDetails: _flag(m, SettingKeys.showTaxDetails, d.showTaxDetails),
      showPaymentDetails: _flag(m, SettingKeys.showPaymentDetails, d.showPaymentDetails),
      showBarcode: _flag(m, SettingKeys.showBarcode, d.showBarcode),
      showFooter: _flag(m, SettingKeys.showFooter, d.showFooter),
      autoPrint: _flag(m, SettingKeys.autoPrint, d.autoPrint),
    );
  }

  Map<String, String> toMap() {
    String b(bool v) => v ? '1' : '0';
    return {
      SettingKeys.showAddress: b(showAddress),
      SettingKeys.showPhone: b(showPhone),
      SettingKeys.showGstin: b(showGstin),
      SettingKeys.showCustomer: b(showCustomer),
      SettingKeys.showTaxDetails: b(showTaxDetails),
      SettingKeys.showPaymentDetails: b(showPaymentDetails),
      SettingKeys.showBarcode: b(showBarcode),
      SettingKeys.showFooter: b(showFooter),
      SettingKeys.autoPrint: b(autoPrint),
    };
  }

  ReceiptOptions copyWith({
    bool? showAddress,
    bool? showPhone,
    bool? showGstin,
    bool? showCustomer,
    bool? showTaxDetails,
    bool? showPaymentDetails,
    bool? showBarcode,
    bool? showFooter,
    bool? autoPrint,
  }) {
    return ReceiptOptions(
      showAddress: showAddress ?? this.showAddress,
      showPhone: showPhone ?? this.showPhone,
      showGstin: showGstin ?? this.showGstin,
      showCustomer: showCustomer ?? this.showCustomer,
      showTaxDetails: showTaxDetails ?? this.showTaxDetails,
      showPaymentDetails: showPaymentDetails ?? this.showPaymentDetails,
      showBarcode: showBarcode ?? this.showBarcode,
      showFooter: showFooter ?? this.showFooter,
      autoPrint: autoPrint ?? this.autoPrint,
    );
  }
}

/// Shop identity printed on receipts, shared bills and khata statements.
///
/// Hindi fields are optional; when blank the English value is used instead.
class ShopProfile {
  final String nameEn;
  final String nameHi;
  final String addressEn;
  final String addressHi;
  final String phone;
  final String gstin;
  final String upiId;
  final String footerEn;
  final String footerHi;
  final PaperWidth paperWidth;
  final ReceiptOptions receipt;

  const ShopProfile({
    this.nameEn = '',
    this.nameHi = '',
    this.addressEn = '',
    this.addressHi = '',
    this.phone = '',
    this.gstin = '',
    this.upiId = '',
    this.footerEn = '',
    this.footerHi = '',
    this.paperWidth = PaperWidth.mm58,
    this.receipt = const ReceiptOptions(),
  });

  static const empty = ShopProfile();

  String displayName(bool isHindi) => _pick(isHindi, nameHi, nameEn, fallback: isHindi ? 'मेरी दुकान' : 'My Kirana Store');
  String displayAddress(bool isHindi) => _pick(isHindi, addressHi, addressEn);
  String displayFooter(bool isHindi) => _pick(isHindi, footerHi, footerEn);

  static String _pick(bool isHindi, String hi, String en, {String fallback = ''}) {
    if (isHindi && hi.trim().isNotEmpty) return hi.trim();
    if (en.trim().isNotEmpty) return en.trim();
    if (hi.trim().isNotEmpty) return hi.trim();
    return fallback;
  }

  factory ShopProfile.fromMap(Map<String, String> map) {
    return ShopProfile(
      nameEn: map[SettingKeys.shopName] ?? '',
      nameHi: map[SettingKeys.shopNameHi] ?? '',
      addressEn: map[SettingKeys.shopAddress] ?? '',
      addressHi: map[SettingKeys.shopAddressHi] ?? '',
      phone: map[SettingKeys.shopPhone] ?? '',
      gstin: map[SettingKeys.gstin] ?? '',
      upiId: map[SettingKeys.upiId] ?? '',
      footerEn: map[SettingKeys.billFooter] ?? '',
      footerHi: map[SettingKeys.billFooterHi] ?? '',
      paperWidth: map[SettingKeys.paperWidth] == '80mm' ? PaperWidth.mm80 : PaperWidth.mm58,
      receipt: ReceiptOptions.fromMap(map),
    );
  }

  Map<String, String> toMap() => {
        SettingKeys.shopName: nameEn.trim(),
        SettingKeys.shopNameHi: nameHi.trim(),
        SettingKeys.shopAddress: addressEn.trim(),
        SettingKeys.shopAddressHi: addressHi.trim(),
        SettingKeys.shopPhone: phone.trim(),
        SettingKeys.gstin: gstin.trim().toUpperCase(),
        SettingKeys.upiId: upiId.trim(),
        SettingKeys.billFooter: footerEn.trim(),
        SettingKeys.billFooterHi: footerHi.trim(),
        SettingKeys.paperWidth: paperWidth == PaperWidth.mm80 ? '80mm' : '58mm',
        ...receipt.toMap(),
      };

  ShopProfile copyWith({
    String? nameEn,
    String? nameHi,
    String? addressEn,
    String? addressHi,
    String? phone,
    String? gstin,
    String? upiId,
    String? footerEn,
    String? footerHi,
    PaperWidth? paperWidth,
    ReceiptOptions? receipt,
  }) {
    return ShopProfile(
      nameEn: nameEn ?? this.nameEn,
      nameHi: nameHi ?? this.nameHi,
      addressEn: addressEn ?? this.addressEn,
      addressHi: addressHi ?? this.addressHi,
      phone: phone ?? this.phone,
      gstin: gstin ?? this.gstin,
      upiId: upiId ?? this.upiId,
      footerEn: footerEn ?? this.footerEn,
      footerHi: footerHi ?? this.footerHi,
      paperWidth: paperWidth ?? this.paperWidth,
      receipt: receipt ?? this.receipt,
    );
  }
}

final shopProfileProvider = AsyncNotifierProvider<ShopProfileNotifier, ShopProfile>(ShopProfileNotifier.new);

class ShopProfileNotifier extends AsyncNotifier<ShopProfile> {
  @override
  Future<ShopProfile> build() async {
    final db = ref.watch(databaseProvider);
    await SeedData.ensureSeeded(db);
    return ShopProfile.fromMap(await db.getAllSettings());
  }

  /// Persists the profile, then publishes it to all listeners.
  Future<void> save(ShopProfile profile) async {
    final db = ref.read(databaseProvider);
    await db.upsertSettings(profile.toMap());
    state = AsyncData(profile);
  }

  ShopProfile get _current => state.valueOrNull ?? ShopProfile.empty;

  Future<void> setPaperWidth(PaperWidth width) => save(_current.copyWith(paperWidth: width));

  Future<void> setReceiptOptions(ReceiptOptions options) => save(_current.copyWith(receipt: options));
}
