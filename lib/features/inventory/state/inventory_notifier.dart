import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/db/app_database.dart';
import '../domain/product_model.dart';

enum InventoryFilter { all, lowStock, packed, loose }

class InventoryState {
  final List<ProductWithCategory> products;
  final List<Category> categories;
  final String searchQuery;
  final String? selectedCategoryId;
  final InventoryFilter filter;
  final bool isLoading;
  final String? errorMessage;

  InventoryState({
    this.products = const [],
    this.categories = const [],
    this.searchQuery = '',
    this.selectedCategoryId,
    this.filter = InventoryFilter.all,
    this.isLoading = false,
    this.errorMessage,
  });

  List<ProductWithCategory> get filteredProducts {
    return products.where((item) {
      final p = item.product;
      // Filter by active
      if (!p.isActive) return false;

      // Filter by category
      if (selectedCategoryId != null && p.categoryId != selectedCategoryId) {
        return false;
      }

      // Filter by type / stock
      if (filter == InventoryFilter.lowStock && p.stockQty > p.reorderLevel) {
        return false;
      }
      if (filter == InventoryFilter.packed && p.itemType != 'packed') {
        return false;
      }
      if (filter == InventoryFilter.loose && p.itemType != 'loose') {
        return false;
      }

      // Filter by search query (bilingual + barcode)
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        final matchEn = p.nameEn.toLowerCase().contains(q);
        final matchHi = p.nameHi != null && p.nameHi!.toLowerCase().contains(q);
        final matchBarcode = p.barcode != null && p.barcode!.toLowerCase().contains(q);
        if (!matchEn && !matchHi && !matchBarcode) return false;
      }

      return true;
    }).toList();
  }

  int get lowStockCount =>
      products.where((p) => p.product.isActive && p.product.stockQty <= p.product.reorderLevel).length;

  InventoryState copyWith({
    List<ProductWithCategory>? products,
    List<Category>? categories,
    String? searchQuery,
    String? selectedCategoryId,
    InventoryFilter? filter,
    bool? isLoading,
    String? errorMessage,
    bool clearCategory = false,
  }) {
    return InventoryState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId: clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final inventoryProvider = StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  final db = ref.watch(databaseProvider);
  return InventoryNotifier(db);
});

class InventoryNotifier extends StateNotifier<InventoryState> {
  final AppDatabase db;

  InventoryNotifier(this.db) : super(InventoryState()) {
    loadCatalog();
  }

  Future<void> loadCatalog() async {
    state = state.copyWith(isLoading: true);
    try {
      final catList = await db.select(db.categories).get();
      final prodList = await (db.select(db.products)..where((p) => p.isActive.equals(true))).get();

      final categoryMap = {for (var c in catList) c.id: c};

      final items = prodList.map((p) {
        return ProductWithCategory(
          product: p,
          category: p.categoryId != null ? categoryMap[p.categoryId] : null,
        );
      }).toList();

      state = state.copyWith(
        products: items,
        categories: catList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(InventoryFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setSelectedCategory(String? categoryId) {
    if (state.selectedCategoryId == categoryId) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategoryId: categoryId);
    }
  }

  Future<String?> saveProduct({
    String? id,
    String? barcode,
    required String nameEn,
    String? nameHi,
    String? categoryId,
    required String itemType, // 'packed' | 'loose'
    required String unit,
    required double price,
    double? mrp,
    double gstRate = 0.0,
    String? hsnCode,
    double stockQty = 0.0,
    double reorderLevel = 0.0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanBarcode = (barcode != null && barcode.trim().isNotEmpty) ? barcode.trim() : null;

    // Validate barcode uniqueness
    if (cleanBarcode != null) {
      final existing = await (db.select(db.products)
        ..where((p) => p.barcode.equals(cleanBarcode) & p.isActive.equals(true)))
        .getSingleOrNull();

      if (existing != null && existing.id != id) {
        return 'Barcode "$cleanBarcode" is already used by "${existing.nameEn}". Please edit that item or use a different barcode.';
      }
    }

    try {
      if (id == null) {
        // Create new
        final newId = const Uuid().v4();
        await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: newId,
            barcode: Value(cleanBarcode),
            nameEn: nameEn.trim(),
            nameHi: Value(nameHi?.trim()),
            categoryId: Value(categoryId),
            itemType: itemType,
            unit: unit,
            price: price,
            mrp: Value(mrp),
            gstRate: Value(gstRate),
            hsnCode: Value(hsnCode?.trim()),
            stockQty: Value(stockQty),
            reorderLevel: Value(reorderLevel),
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Add initial stock ledger entry if stock > 0
        if (stockQty > 0) {
          await db.into(db.stockLedger).insert(
            StockLedgerCompanion.insert(
              id: const Uuid().v4(),
              productId: newId,
              changeQty: stockQty,
              reason: 'adjustment',
              balanceAfter: stockQty,
              createdAt: now,
            ),
          );
        }
      } else {
        // Update existing
        await (db.update(db.products)..where((p) => p.id.equals(id))).write(
          ProductsCompanion(
            barcode: Value(cleanBarcode),
            nameEn: Value(nameEn.trim()),
            nameHi: Value(nameHi?.trim()),
            categoryId: Value(categoryId),
            itemType: Value(itemType),
            unit: Value(unit),
            price: Value(price),
            mrp: Value(mrp),
            gstRate: Value(gstRate),
            hsnCode: Value(hsnCode?.trim()),
            stockQty: Value(stockQty),
            reorderLevel: Value(reorderLevel),
            updatedAt: Value(now),
          ),
        );
      }

      await loadCatalog();
      return null; // success
    } catch (e) {
      return 'Failed to save product: $e';
    }
  }

  Future<void> adjustStock(String productId, double deltaQty, String reason) async {
    final product = await (db.select(db.products)..where((p) => p.id.equals(productId))).getSingleOrNull();
    if (product == null) return;

    final newStock = product.stockQty + deltaQty;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction(() async {
      await db.into(db.stockLedger).insert(
        StockLedgerCompanion.insert(
          id: const Uuid().v4(),
          productId: productId,
          changeQty: deltaQty,
          reason: reason,
          balanceAfter: newStock,
          createdAt: now,
        ),
      );

      await (db.update(db.products)..where((p) => p.id.equals(productId))).write(
        ProductsCompanion(
          stockQty: Value(newStock),
          updatedAt: Value(now),
        ),
      );
    });

    await loadCatalog();
  }

  Future<void> softDeleteProduct(String productId) async {
    await (db.update(db.products)..where((p) => p.id.equals(productId))).write(
      ProductsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    await loadCatalog();
  }
}
