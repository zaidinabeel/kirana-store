import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirana_store/core/backup/backup_service.dart';
import 'package:kirana_store/core/db/app_database.dart';
import 'package:path/path.dart' as p;

Future<void> _addProduct(AppDatabase db, String id, String name) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return db.into(db.products).insert(ProductsCompanion.insert(
        id: id,
        nameEn: name,
        itemType: 'packed',
        unit: 'piece',
        price: 10,
        stockQty: const Value(5),
        createdAt: now,
        updatedAt: now,
      ));
}

Future<List<String>> _names(File dbFile) async {
  final db = AppDatabase(NativeDatabase(dbFile));
  final rows = await db.select(db.products).get();
  await db.close();
  return rows.map((r) => r.nameEn).toList()..sort();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  late File liveFile;
  late Directory backups;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kirana_backup_test');
    liveFile = File(p.join(tmp.path, 'kirana_store.sqlite'));
    backups = Directory(p.join(tmp.path, 'Backups'));
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('backup is a valid copy that restore brings back', () async {
    final db = AppDatabase(NativeDatabase(liveFile));
    await _addProduct(db, 'p1', 'Maggi');
    final backup = await BackupService.createBackup(db, into: backups);
    expect(BackupService.validateBackup(backup), isNull);

    // Shop keeps working after the backup...
    await _addProduct(db, 'p2', 'Parle-G');

    // ...then restores the old backup.
    final safety = await BackupService.restore(backup: backup, db: db, liveFile: liveFile, safetyDir: backups);
    expect(await _names(liveFile), ['Maggi']);
    // The data from just before the restore is kept as a safety backup.
    expect(await _names(safety), ['Maggi', 'Parle-G']);
  });

  test('rejects files that are not shop backups', () async {
    final text = File(p.join(tmp.path, 'photo.jpg'))..writeAsStringSync('not a database');
    expect(BackupService.validateBackup(text), isNotNull);
    expect(BackupService.validateBackup(File(p.join(tmp.path, 'missing.sqlite'))), isNotNull);

    // A real SQLite file from some other app.
    final other = NativeDatabase(File(p.join(tmp.path, 'other.sqlite')));
    final otherDb = AppDatabase(other);
    await otherDb.customStatement('CREATE TABLE IF NOT EXISTS unrelated (x INTEGER)');
    await otherDb.customStatement('DROP TABLE products');
    await otherDb.close();
    expect(BackupService.validateBackup(File(p.join(tmp.path, 'other.sqlite'))), isNotNull);
  });

  test('restore refuses a bad file and leaves the live data alone', () async {
    final db = AppDatabase(NativeDatabase(liveFile));
    await _addProduct(db, 'p1', 'Maggi');
    final bad = File(p.join(tmp.path, 'bad.sqlite'))..writeAsStringSync('junk');
    await expectLater(
      BackupService.restore(backup: bad, db: db, liveFile: liveFile, safetyDir: backups),
      throwsA(isA<BackupException>()),
    );
    expect((await db.select(db.products).get()).length, 1);
    await db.close();
  });

  test('automatic backup runs once a day', () async {
    final db = AppDatabase(NativeDatabase(liveFile));
    final day1 = DateTime(2026, 11, 21, 9);
    expect(await BackupService.autoBackupIfDue(db, into: backups, now: day1), isNotNull);
    expect(await BackupService.autoBackupIfDue(db, into: backups, now: day1.add(const Duration(hours: 3))), isNull);
    expect(await BackupService.autoBackupIfDue(db, into: backups, now: day1.add(const Duration(days: 1))), isNotNull);
    expect((await BackupService.listBackups(backups)).length, 2);
    await db.close();
  });

  test('only the newest backups are kept', () async {
    final db = AppDatabase(NativeDatabase(liveFile));
    final start = DateTime(2026, 1, 1);
    for (var i = 0; i < BackupService.keepLatest + 3; i++) {
      await BackupService.createBackup(db, into: backups, now: start.add(Duration(days: i)));
    }
    final kept = await BackupService.listBackups(backups);
    expect(kept.length, BackupService.keepLatest);
    expect(p.basename(kept.first.path), contains('2026-01-13'));
    await db.close();
  });
}
