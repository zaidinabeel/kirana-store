import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../core/security/lock_screen.dart';
import '../../../../core/security/pin_lock.dart';

/// Turn the 4-digit app lock on/off and change the PIN.
class PinSection extends ConsumerWidget {
  const PinSection({super.key});

  Future<String?> _ask(BuildContext context, String title, Future<bool> Function(String) validate, {String? subtitle}) {
    return Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => PinEntryPage(title: title, subtitle: subtitle, validate: validate),
    ));
  }

  /// Enter a new PIN twice. Returns it, or null if cancelled.
  Future<String?> _chooseNew(BuildContext context, bool hi) async {
    final first = await _ask(context, hi ? 'नया 4 अंक का PIN चुनें' : 'Choose a new 4-digit PIN', (_) async => true,
        subtitle: hi ? 'ऐसा PIN चुनें जो आपको याद रहे' : 'Pick one you will remember');
    if (first == null || !context.mounted) return null;
    var mismatch = false;
    final second = await _ask(
      context,
      hi ? 'वही PIN दोबारा डालें' : 'Enter the same PIN again',
      (pin) async {
        mismatch = pin != first;
        return !mismatch;
      },
    );
    return second;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hi = ref.watch(localeProvider) == AppLanguage.hi;
    final enabled = ref.watch(pinEnabledProvider).valueOrNull ?? false;
    final store = ref.read(pinLockStoreProvider);

    void toast(String msg) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));

    Future<bool> verifyCurrent() async {
      final pin = await _ask(context, hi ? 'अभी वाला PIN डालें' : 'Enter current PIN', store.verify);
      return pin != null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(hi ? 'ऐप खोलने पर PIN माँगे' : 'Ask for PIN when opening the app',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          subtitle: Text(hi
              ? 'खाता और बिक्री दूसरों से सुरक्षित रहे'
              : 'Keeps your khata and sales private'),
          value: enabled,
          onChanged: (on) async {
            if (on) {
              final pin = await _chooseNew(context, hi);
              if (pin == null) return;
              await store.setPin(pin);
              ref.invalidate(pinEnabledProvider);
              toast(hi ? '✓ PIN लॉक चालू हो गया' : '✓ PIN lock turned on');
            } else {
              if (!await verifyCurrent()) return;
              await store.clear();
              ref.invalidate(pinEnabledProvider);
              toast(hi ? 'PIN लॉक बंद हो गया' : 'PIN lock turned off');
            }
          },
        ),
        if (enabled)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () async {
              if (!await verifyCurrent() || !context.mounted) return;
              final pin = await _chooseNew(context, hi);
              if (pin == null) return;
              await store.setPin(pin);
              toast(hi ? '✓ PIN बदल गया' : '✓ PIN changed');
            },
            icon: const Icon(Icons.password_rounded),
            label: Text(hi ? 'PIN बदलें' : 'Change PIN'),
          ),
        const SizedBox(height: 6),
        Text(
          hi
              ? 'PIN भूल जाएं तो: ऐप दोबारा डालकर बैकअप से वापस लाएं — डेटा वापस आ जाता है।'
              : 'Forgot the PIN? Reinstall and restore a backup — your data comes back.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
