import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/seed_data.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  // On-disk database (app documents dir on native, IndexedDB/OPFS on web)
  // so sales, khata and settings survive app restarts.
  final db = AppDatabase();
  // Restore closes the database itself first, so ignore a second close.
  ref.onDispose(() => db.close().ignore());
  // Seed the sample catalog on first launch only (no-op once data exists).
  SeedData.ensureSeeded(db);
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
