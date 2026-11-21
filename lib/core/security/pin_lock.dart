import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 4-digit app lock.
///
/// The PIN (salted SHA-256) lives in its own small file, NOT in the shop
/// database, so it is never part of a backup. If the shopkeeper forgets the
/// PIN they can reinstall the app and restore the latest backup: all data
/// comes back, without the forgotten PIN.
class PinLockStore {
  static const fileName = 'app_lock.json';
  static const maxAttempts = 5;
  static const lockoutDuration = Duration(seconds: 30);

  final Future<Directory> Function() _dir;
  PinLockStore([Future<Directory> Function()? dir]) : _dir = dir ?? getApplicationSupportDirectory;

  Future<File> _file() async => File(p.join((await _dir()).path, fileName));

  static bool isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

  static String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    try {
      return await (await _file()).exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('PIN must be 4 digits');
    final rnd = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({'salt': salt, 'hash': _hash(pin, salt)}), flush: true);
  }

  Future<bool> verify(String pin) async {
    try {
      final file = await _file();
      if (!await file.exists()) return true;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _hash(pin, data['salt'] as String) == data['hash'];
    } catch (_) {
      return false;
    }
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}

final pinLockStoreProvider = Provider<PinLockStore>((ref) => PinLockStore());

/// Whether the PIN lock is turned on (refresh after changing it).
final pinEnabledProvider = FutureProvider<bool>((ref) => ref.watch(pinLockStoreProvider).isEnabled());
