import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLanguage { en, hi }

final localeProvider = StateNotifierProvider<LocaleNotifier, AppLanguage>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<AppLanguage> {
  LocaleNotifier() : super(AppLanguage.en);

  void toggleLanguage() {
    state = state == AppLanguage.en ? AppLanguage.hi : AppLanguage.en;
  }

  void setLanguage(AppLanguage language) {
    state = language;
  }
}

class AppStrings {
  // Navigation & Core Chrome
  static String appTitle(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'किराना स्टोर' : 'Kirana Store';

  static String dashboard(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'डैशबोर्ड' : 'Dashboard';

  static String billing(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'बिलिंग (नया बिल)' : 'Billing';

  static String inventory(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'स्टॉक / इन्वेंटरी' : 'Inventory';

  static String khata(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'खाता (उधार रजिस्टर)' : 'Khata Ledger';

  static String settings(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'सेटिंग्स' : 'Settings';

  // Dashboard
  static String todaySales(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'आज की कुल बिक्री' : "Today's Sales";

  static String billsCount(AppLanguage lang, int count) =>
      lang == AppLanguage.hi ? '$count बिल बने' : '$count Bills';

  static String quickActions(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'त्वरित कार्य' : 'Quick Actions';

  static String newBillAction(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'नया बिल बनाएं' : 'New Bill';

  static String addStockAction(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'स्टॉक जोड़ें / स्कैन' : 'Add Stock';

  static String viewKhataAction(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'खाता रजिस्टर' : 'View Khata';

  static String lowStockAlert(AppLanguage lang, int count) =>
      lang == AppLanguage.hi ? 'कम स्टॉक चेतावनी ($count सामान)' : 'Low Stock Alert ($count items)';

  static String restockNow(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'अभी मंगवाएं' : 'Restock';

  static String recentBills(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'हाल के बिल' : 'Recent Bills';

  // Inventory
  static String searchProducts(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'सामान या बारकोड खोजें...' : 'Search items or scan barcode...';

  static String allItems(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'सभी' : 'All';

  static String packedItems(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'पैक्ड सामान' : 'Packed';

  static String looseItems(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'खुला सामान' : 'Loose';

  static String lowStockFilter(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'कम स्टॉक' : 'Low Stock';

  static String addProduct(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'नया सामान जोड़ें' : 'Add Product';

  static String editProduct(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'सामान बदलें' : 'Edit Product';

  static String productNameEn(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'अंग्रेज़ी में नाम' : 'Product Name (English)';

  static String productNameHi(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'हिंदी में नाम' : 'Product Name (Hindi)';

  static String barcode(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'बारकोड' : 'Barcode';

  static String scanBarcode(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'बारकोड स्कैन करें' : 'Scan Barcode';

  static String category(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'वर्ग / श्रेणी' : 'Category';

  static String itemType(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'सामान का प्रकार' : 'Item Type';

  static String unit(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'इकाई (Unit)' : 'Unit';

  static String sellingPrice(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'बिक्री मूल्य (₹)' : 'Selling Price (₹)';

  static String mrp(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'एम.आर.पी (MRP ₹)' : 'MRP (₹)';

  static String gstRate(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'जीएसटी दर (% GST)' : 'GST Rate (%)';

  static String hsnCode(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'एचएसएन कोड (HSN)' : 'HSN Code';

  static String stockQuantity(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'उपलब्ध स्टॉक' : 'Current Stock';

  static String reorderLevel(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'चेतावनी सीमा (Reorder Level)' : 'Low Stock Alert Level';

  // Billing
  static String cart(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'बिल कार्ट' : 'Billing Cart';

  static String emptyCartTitle(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'कार्ट खाली है' : 'Cart is Empty';

  static String emptyCartSubtitle(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'सामान जोड़ने के लिए स्कैन करें या नीचे से चुनें' : 'Scan barcode or select items below to add';

  static String selectCustomer(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'ग्राहक चुनें (वैकल्पिक)' : 'Select Customer (Optional)';

  static String gstInvoice(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'जीएसटी बिल' : 'GST Invoice';

  static String nonGstBill(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'कच्चा / साधारण बिल' : 'Standard Bill';

  static String subtotal(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'कुल योग' : 'Subtotal';

  static String discount(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'छूट / डिस्काउंट' : 'Discount';

  static String roundOff(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'राउंड ऑफ' : 'Round Off';

  static String grandTotal(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'कुल देय राशि' : 'Grand Total';

  static String finalizeSale(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'बिल पक्का करें' : 'Finalize Sale';

  static String reverseQtyPrompt(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'रुपये के हिसाब से वजन निकालें (उदा. ₹50 की चीनी)' : 'Calculate weight by amount (e.g. ₹50 sugar)';

  static String enterAmount(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'रुपये डालें' : 'Enter ₹ Amount';

  static String derivedWeight(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'निकाला गया वजन' : 'Derived Weight';

  // Payment Modes
  static String paymentMode(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'भुगतान का तरीका' : 'Payment Mode';

  static String cash(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'नकद (Cash)' : 'Cash';

  static String upi(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'यूपीआई (UPI / QR)' : 'UPI';

  static String card(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'कार्ड (Card)' : 'Card';

  static String credit(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'उधार (Khata)' : 'Credit (Khata)';

  static String split(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'मिक्स / स्प्लिट' : 'Split Payment';

  // Khata
  static String totalOutstanding(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'मार्केट में कुल बकाया' : 'Total Market Due';

  static String searchCustomer(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'ग्राहक का नाम या फोन नंबर खोजें...' : 'Search customer by name or phone...';

  static String addCustomer(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'नया ग्राहक जोड़ें' : 'Add Customer';

  static String customerName(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'ग्राहक का नाम' : 'Customer Name';

  static String phone(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'मोबाइल नंबर' : 'Phone Number';

  static String address(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'पता (वैकल्पिक)' : 'Address (Optional)';

  static String openingBalance(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'पुरानी बकाया राशि' : 'Opening Due Balance (₹)';

  static String collectPayment(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'रुपये जमा करें' : 'Collect Payment';

  static String shareStatement(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'खाता स्टेटमेंट भेजें' : 'Share Statement';

  static String sendReminder(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'व्हाट्सएप तगादा भेजें' : 'Send WhatsApp Reminder';

  static String ledgerHistory(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'लेन-देन इतिहास' : 'Ledger History';

  // Printing & Receipt
  static String receiptPreview(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'रसीद प्रिव्यू' : 'Receipt Preview';

  static String printReceipt(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'थर्मल प्रिंट निकालें' : 'Print Receipt';

  static String sharePdf(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'पीडीएफ शेयर करें' : 'Share PDF / Bill';

  static String voidBill(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'बिल रद्द करें (Void)' : 'Void Invoice';

  static String voidConfirm(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'क्या आप सच में यह बिल रद्द करना चाहते हैं? इससे स्टॉक और खाता अपने आप वापस हो जाएगा।' : 'Are you sure you want to void this invoice? Stock and customer ledger will be automatically reversed.';

  // Actions & Buttons
  static String save(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'सुरक्षित करें' : 'Save';

  static String cancel(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'रद्द करें' : 'Cancel';

  static String confirm(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'पुष्टि करें' : 'Confirm';

  static String delete(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'हटाएं' : 'Delete';

  static String apply(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'लागू करें' : 'Apply';

  static String success(AppLanguage lang) =>
      lang == AppLanguage.hi ? 'सफल रहा!' : 'Success!';
}
