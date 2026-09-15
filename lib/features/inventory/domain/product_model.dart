import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/seed_data.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.inMemory();
  // Auto-seed initial catalog
  SeedData.populate(db);
  return db;
});

class ProductWithCategory {
  final Product product;
  final Category? category;

  ProductWithCategory({
    required this.product,
    this.category,
  });
}
