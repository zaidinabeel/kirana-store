import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    if (Platform.isAndroid) {
      // Android apps cannot use the phone's own SQLite; sqlite3_flutter_libs bundles one.
      // This workaround is needed for it to load on Android 6 and older.
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      // Android has no writable /tmp; give SQLite the app's cache folder.
      sqlite3.tempDirectory = (await getTemporaryDirectory()).path;
    }
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'kirana_store.sqlite'));
    // Runs SQLite on a background isolate so the screen never freezes.
    return NativeDatabase.createInBackground(file);
  });
}

QueryExecutor openInMemory() {
  return NativeDatabase.memory();
}
