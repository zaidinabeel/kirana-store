import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../db/app_database.dart';
import '../settings/shop_profile.dart';

/// Phone backups of the shop database.
///
/// * Automatic: once a day a copy is written to `Documents/KiranaStore/Backups`
///   in phone storage, which stays even if the app is uninstalled.
/// * Manual: "Backup now" + share to WhatsApp / Google Drive.
/// * Restore: pick a backup file; the current data is backed up first.
/// Bumped whenever a backup is written so screens showing backup status refresh.
final backupTickProvider = StateProvider<int>((ref) => 0);

class BackupService {
  static const dbFileName = 'kirana_store.sqlite';
  static const _prefix = 'kirana_backup_';
  static const keepLatest = 10;
  static const autoBackupEvery = Duration(hours: 20);

  /// Tables a file must contain to be accepted as a shop backup.
  static const requiredTables = {'products', 'invoices', 'customers', 'settings'};

  static Future<File> liveDatabaseFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, dbFileName));
  }

  /// Backup folder the shopkeeper can see in the phone's Files app.
  static Future<Directory> backupDirectory() async {
    if (Platform.isAndroid) {
      // Android 11+ lets apps create their own files in Documents without any permission.
      final shared = Directory('/storage/emulated/0/Documents/KiranaStore/Backups');
      if (await _isWritable(shared)) return shared;
      // Android 10 and older need the storage permission for this folder.
      try {
        if ((await Permission.storage.request()).isGranted && await _isWritable(shared)) return shared;
      } catch (_) {}
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory(p.join(ext.path, 'Backups'));
        if (await _isWritable(dir)) return dir;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'Backups'));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<bool> _isWritable(Directory dir) async {
    try {
      await dir.create(recursive: true);
      final probe = File(p.join(dir.path, '.write_test'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Writes a consistent copy of the open database (SQLite `VACUUM INTO`).
  static Future<File> createBackup(AppDatabase db, {Directory? into, DateTime? now}) async {
    final dir = into ?? await backupDirectory();
    await dir.create(recursive: true);
    final stamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now ?? DateTime.now());
    final target = File(p.join(dir.path, '$_prefix$stamp.sqlite'));
    if (await target.exists()) await target.delete();

    await db.customStatement('VACUUM INTO ?', [target.path]);
    await db.upsertSettings({SettingKeys.lastBackupAt: '${(now ?? DateTime.now()).millisecondsSinceEpoch}'});
    await pruneOldBackups(dir);
    return target;
  }

  /// Makes a backup if the last one is older than [autoBackupEvery]. Never throws.
  static Future<File?> autoBackupIfDue(AppDatabase db, {Directory? into, DateTime? now}) async {
    try {
      final settings = await db.getAllSettings();
      final last = int.tryParse(settings[SettingKeys.lastBackupAt] ?? '');
      final current = now ?? DateTime.now();
      if (last != null && current.difference(DateTime.fromMillisecondsSinceEpoch(last)) < autoBackupEvery) {
        return null;
      }
      return await createBackup(db, into: into, now: current);
    } catch (_) {
      return null;
    }
  }

  static Future<List<File>> listBackups([Directory? dir]) async {
    final d = dir ?? await backupDirectory();
    if (!await d.exists()) return [];
    final files = await d
        .list()
        .where((e) => e is File && p.basename(e.path).startsWith(_prefix) && e.path.endsWith('.sqlite'))
        .cast<File>()
        .toList();
    files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path))); // newest first
    return files;
  }

  static Future<void> pruneOldBackups(Directory dir, {int keep = keepLatest}) async {
    final files = await listBackups(dir);
    for (final f in files.skip(keep)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  /// Returns null when [file] is a valid shop backup, otherwise a Hindi error message.
  static String? validateBackup(File file) {
    if (!file.existsSync()) return 'फ़ाइल नहीं मिली';
    try {
      final header = file.openSync()..setPositionSync(0);
      final magic = String.fromCharCodes(header.readSync(15));
      header.closeSync();
      if (magic != 'SQLite format 3') return 'यह बैकअप फ़ाइल नहीं है';

      final conn = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
      try {
        final rows = conn.select("SELECT name FROM sqlite_master WHERE type = 'table'");
        final tables = rows.map((r) => r['name'] as String).toSet();
        if (!tables.containsAll(requiredTables)) return 'यह इस ऐप का बैकअप नहीं है';
      } finally {
        conn.dispose();
      }
      return null;
    } catch (_) {
      return 'बैकअप फ़ाइल खराब है, खुल नहीं रही';
    }
  }

  /// Replaces the live database with [backup].
  ///
  /// A safety backup of the current data is written first. [db] is closed by this
  /// call; the caller must open a fresh database afterwards (invalidate the provider).
  static Future<File> restore({
    required File backup,
    required AppDatabase db,
    File? liveFile,
    Directory? safetyDir,
  }) async {
    final error = validateBackup(backup);
    if (error != null) throw BackupException(error);

    final live = liveFile ?? await liveDatabaseFile();
    // Copy the chosen file first: it may live inside a temp/picker folder.
    final staged = await backup.copy('${live.path}.restore');

    final safety = await createBackup(db, into: safetyDir);
    await db.close();

    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('${live.path}$suffix');
      if (await f.exists()) await f.delete();
    }
    await staged.rename(live.path);
    return safety;
  }
}

class BackupException implements Exception {
  final String message;
  BackupException(this.message);
  @override
  String toString() => message;
}
