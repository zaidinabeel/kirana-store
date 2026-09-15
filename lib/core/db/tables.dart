import 'package:drift/drift.dart';

/// Categories Table
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get nameEn => text()();
  TextColumn get nameHi => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Products Table (Unified packed & loose)
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get barcode => text().nullable().customConstraint('UNIQUE')();
  TextColumn get nameEn => text()();
  TextColumn get nameHi => text().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get itemType => text()(); // 'packed' | 'loose'
  TextColumn get unit => text()();     // 'piece', 'kg', 'gm', 'litre', 'ml', 'box'
  RealColumn get price => real()();    // Stored as decimal-compatible real
  RealColumn get mrp => real().nullable()();
  RealColumn get gstRate => real().withDefault(const Constant(0.0))();
  TextColumn get hsnCode => text().nullable()();
  RealColumn get stockQty => real().withDefault(const Constant(0.0))();
  RealColumn get reorderLevel => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get imagePath => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Customers Table
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable().customConstraint('UNIQUE')();
  TextColumn get address => text().nullable()();
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Invoices Table
class Invoices extends Table {
  TextColumn get id => text()();
  IntColumn get invoiceNo => integer()();
  TextColumn get financialYear => text()(); // e.g. '2026-27'
  TextColumn get invoiceType => text()();   // 'gst' | 'non_gst'
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get cgst => real().withDefault(const Constant(0.0))();
  RealColumn get sgst => real().withDefault(const Constant(0.0))();
  RealColumn get igst => real().withDefault(const Constant(0.0))();
  RealColumn get roundOff => real().withDefault(const Constant(0.0))();
  RealColumn get total => real()();
  TextColumn get paymentMode => text()();   // 'cash'|'upi'|'card'|'credit'|'split'
  RealColumn get amountPaid => real()();
  RealColumn get amountDue => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('active'))(); // 'active' | 'void'
  IntColumn get createdAt => integer()();
  IntColumn get printedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Invoice Line Items (Frozen snapshot at time of sale)
class InvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text().references(Invoices, #id)();
  TextColumn get productId => text().nullable().references(Products, #id)();
  TextColumn get nameSnapshot => text()();
  TextColumn get hsnSnapshot => text().nullable()();
  RealColumn get qty => real()();
  TextColumn get unit => text()();
  RealColumn get rate => real()();
  RealColumn get gstRateSnapshot => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get lineTotal => real()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stock Movement Audit Trail
class StockLedger extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get changeQty => real()(); // Negative for sale, positive for purchase/adjustment/void
  TextColumn get reason => text()();    // 'purchase'|'sale'|'adjustment'|'return'|'void'
  TextColumn get refId => text().nullable()(); // invoiceId or purchaseId
  RealColumn get balanceAfter => real()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Customer Payments (Khata Collections / Refunds)
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get invoiceId => text().nullable().references(Invoices, #id)();
  RealColumn get amount => real()();
  TextColumn get mode => text()();      // 'cash' | 'upi'
  TextColumn get type => text()();      // 'collection' | 'refund'
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Suppliers
class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Purchases
class Purchases extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  TextColumn get invoiceNo => text().nullable()();
  RealColumn get total => real()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Purchase Line Items
class PurchaseItems extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseId => text().references(Purchases, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get qty => real()();
  RealColumn get costPrice => real()();

  @override
  Set<Column> get primaryKey => {id};
}

/// App Settings (Key-Value)
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
