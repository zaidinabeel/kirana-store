import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../../core/backup/backup_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../core/settings/shop_profile.dart';
import '../../../dashboard/presentation/dashboard_screen.dart';
import '../../../inventory/domain/product_model.dart';

/// Backup card: last backup time, backup now + share, restore from file.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  DateTime? _lastBackup;
  String? _folder;
  int _count = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (kIsWeb) return;
    try {
      final db = ref.read(databaseProvider);
      final settings = await db.getAllSettings();
      final ms = int.tryParse(settings[SettingKeys.lastBackupAt] ?? '');
      final dir = await BackupService.backupDirectory();
      final files = await BackupService.listBackups(dir);
      if (!mounted) return;
      setState(() {
        _lastBackup = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
        _folder = dir.path;
        _count = files.length;
      });
    } catch (_) {}
  }

  bool get _hi => ref.read(localeProvider) == AppLanguage.hi;

  void _toast(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 15)),
        backgroundColor: ok ? AppColors.success : AppColors.alert,
        duration: Duration(seconds: ok ? 3 : 6),
      ),
    );
  }

  Future<void> _backupAndShare() async {
    setState(() => _busy = true);
    try {
      final file = await BackupService.createBackup(ref.read(databaseProvider));
      await _refresh();
      if (!mounted) return;
      final shop = ref.read(shopProfileProvider).valueOrNull;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/octet-stream')],
        subject: 'Kirana Store Backup',
        text: _hi
            ? '${shop?.displayName(true) ?? "दुकान"} का बैकअप (${DateFormat('dd-MM-yyyy').format(DateTime.now())}). इसे संभाल कर रखें।'
            : 'Backup of ${shop?.displayName(false) ?? "shop"} (${DateFormat('dd-MM-yyyy').format(DateTime.now())}). Keep it safe.',
      ));
    } catch (e) {
      if (mounted) _toast(_hi ? 'बैकअप नहीं बना: $e' : 'Backup failed: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    try {
      final file = await BackupService.createBackup(ref.read(databaseProvider));
      await _refresh();
      if (mounted) _toast(_hi ? '✓ बैकअप बन गया: ${p.basename(file.path)}' : '✓ Backup saved: ${p.basename(file.path)}');
    } catch (e) {
      if (mounted) _toast(_hi ? 'बैकअप नहीं बना: $e' : 'Backup failed: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final hi = _hi;
    final picked = await FilePicker.pickFiles(type: FileType.any, withData: false);
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;
    final file = File(path);

    final problem = BackupService.validateBackup(file);
    if (problem != null) {
      _toast(problem, ok: false);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hi ? 'बैकअप से वापस लाएं?' : 'Restore this backup?'),
        content: Text(
          hi
              ? 'अभी फ़ोन में जो सामान, बिल और खाता है, वो इस बैकअप से बदल जाएगा।\n\nचिंता न करें — बदलने से पहले अभी वाले डेटा का भी बैकअप बन जाएगा।'
              : 'Your current items, bills and khata will be replaced by this backup.\n\nA backup of the current data is made first, so nothing is lost.',
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(hi ? 'नहीं' : 'No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(hi ? 'हाँ, वापस लाएं' : 'Yes, restore')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await BackupService.restore(backup: file, db: ref.read(databaseProvider));
      // Open the restored database and rebuild every screen from it.
      ref.invalidate(databaseProvider);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hi ? '✓ पुराना डेटा वापस आ गया' : '✓ Backup restored'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(hi ? 'वापस नहीं ला पाए: $e' : 'Restore failed: $e', ok: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(backupTickProvider, (_, __) => _refresh());
    final hi = ref.watch(localeProvider) == AppLanguage.hi;
    if (kIsWeb) {
      return Text(hi ? 'बैकअप सिर्फ़ फ़ोन ऐप में चलता है।' : 'Backup works in the phone app only.');
    }
    final last = _lastBackup;
    final lastText = last == null
        ? (hi ? 'अभी तक कोई बैकअप नहीं' : 'No backup yet')
        : (hi ? 'आखिरी बैकअप: ' : 'Last backup: ') + DateFormat('dd MMM, hh:mm a').format(last);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              last == null ? Icons.warning_amber_rounded : Icons.verified_rounded,
              color: last == null ? AppColors.alert : AppColors.success,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(lastText, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hi
              ? 'ऐप हर दिन अपने आप बैकअप बनाता है। फ़ोन में रखे बैकअप: $_count\nफ़ोल्डर: ${_folder ?? "…"}'
              : 'A backup is made automatically every day. Backups on phone: $_count\nFolder: ${_folder ?? "…"}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            onPressed: _busy ? null : _backupAndShare,
            icon: const Icon(Icons.send_rounded),
            label: Text(
              hi ? 'बैकअप बनाकर WhatsApp / Drive पर भेजें' : 'Back up & send to WhatsApp / Drive',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                onPressed: _busy ? null : _backupNow,
                icon: const Icon(Icons.save_rounded),
                label: Text(hi ? 'अभी बैकअप लें' : 'Back up now'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50), foregroundColor: AppColors.alert),
                onPressed: _busy ? null : _restore,
                icon: const Icon(Icons.restore_rounded),
                label: Text(hi ? 'बैकअप से वापस लाएं' : 'Restore'),
              ),
            ),
          ],
        ),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      ],
    );
  }
}
