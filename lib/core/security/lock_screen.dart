import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../i18n/app_strings.dart';
import 'pin_lock.dart';

/// Four dots + big number keypad. Calls [onComplete] with the 4 digits;
/// return true to accept, false to shake-clear and try again.
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<bool> Function(String pin) onComplete;
  final bool enabled;
  final Widget? footer;

  const PinPad({
    super.key,
    required this.title,
    required this.onComplete,
    this.subtitle,
    this.enabled = true,
    this.footer,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _busy = false;

  Future<void> _press(String key) async {
    if (!widget.enabled || _busy) return;
    HapticFeedback.selectionClick();
    if (key == '⌫') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= 4) return;
    setState(() => _pin += key);
    if (_pin.length == 4) {
      _busy = true;
      final ok = await widget.onComplete(_pin);
      if (!mounted) return;
      if (!ok) HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_rounded, size: 48, color: AppColors.primary),
        const SizedBox(height: 12),
        Text(widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary)),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(widget.subtitle!,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? AppColors.primary : Colors.transparent,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final k in row)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: SizedBox(
                    width: 76,
                    height: 64,
                    child: k.isEmpty
                        ? null
                        : Material(
                            color: k == '⌫' ? AppColors.surfaceMuted : AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: AppColors.divider),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: widget.enabled ? () => _press(k) : null,
                              child: Center(
                                child: k == '⌫'
                                    ? const Icon(Icons.backspace_outlined, size: 26)
                                    : Text(k, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        if (widget.footer != null) ...[const SizedBox(height: 12), widget.footer!],
      ],
    );
  }
}

/// Covers the whole app with the PIN screen at start-up and after the app has
/// been in the background for more than [relockAfter].
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;
  final Duration relockAfter;

  const AppLockGate({super.key, required this.child, this.relockAfter = const Duration(minutes: 1)});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  bool? _locked; // null while checking
  DateTime? _backgroundAt;
  int _wrong = 0;
  DateTime? _waitUntil;
  Timer? _tick;
  bool _showForgot = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final enabled = await ref.read(pinLockStoreProvider).isEnabled();
    if (mounted) setState(() => _locked = enabled);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _backgroundAt == null ? Duration.zero : DateTime.now().difference(_backgroundAt!);
      _backgroundAt = null;
      if (away > widget.relockAfter) _check();
    }
  }

  Future<bool> _tryPin(String pin) async {
    final ok = await ref.read(pinLockStoreProvider).verify(pin);
    if (!mounted) return ok;
    if (ok) {
      setState(() {
        _locked = false;
        _wrong = 0;
        _showForgot = false;
      });
      return true;
    }
    setState(() => _wrong++);
    if (_wrong >= PinLockStore.maxAttempts) {
      _waitUntil = DateTime.now().add(PinLockStore.lockoutDuration);
      _wrong = 0;
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        if (DateTime.now().isAfter(_waitUntil!)) {
          t.cancel();
          _waitUntil = null;
        }
        setState(() {});
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hi = ref.watch(localeProvider) == AppLanguage.hi;
    final waiting = _waitUntil != null && DateTime.now().isBefore(_waitUntil!);
    final secondsLeft = waiting ? _waitUntil!.difference(DateTime.now()).inSeconds + 1 : 0;

    String? subtitle;
    if (waiting) {
      subtitle = hi ? 'बहुत बार गलत PIN। $secondsLeft सेकंड रुकें।' : 'Too many wrong tries. Wait $secondsLeft s.';
    } else if (_wrong > 0) {
      subtitle = hi ? 'गलत PIN, फिर से डालें' : 'Wrong PIN, try again';
    }

    // Same tree shape locked or not, so the app underneath never rebuilds on unlock.
    return Stack(
      children: [
        widget.child,
        if (_locked != false)
          Positioned.fill(
            // Dark status-bar icons over the light lock page.
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark,
              child: Material(
                color: AppColors.background,
                child: SafeArea(
                  child: _locked == null
                      ? const SizedBox.shrink()
                      : Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: PinPad(
                              title: hi ? 'अपना 4 अंक का PIN डालें' : 'Enter your 4-digit PIN',
                              subtitle: subtitle,
                              enabled: !waiting,
                              onComplete: _tryPin,
                              footer: Column(
                                children: [
                                  TextButton(
                                    onPressed: () => setState(() => _showForgot = !_showForgot),
                                    child:
                                        Text(hi ? 'PIN भूल गए?' : 'Forgot PIN?', style: const TextStyle(fontSize: 16)),
                                  ),
                                  if (_showForgot)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentLight,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        hi
                                            ? 'आपका डेटा सुरक्षित है। ऐप हटाकर फिर से डालें, फिर सेटिंग → बैकअप → "बैकअप से वापस लाएं" में सबसे नया बैकअप चुनें (फ़ोन के Documents → KiranaStore → Backups में)। सारा हिसाब वापस आ जाएगा, पुराना PIN नहीं।'
                                            : 'Your data is safe. Uninstall and reinstall the app, then Settings → Backup → "Restore" and pick the newest backup (in Documents → KiranaStore → Backups). Everything comes back, without the old PIN.',
                                        style: const TextStyle(fontSize: 14, height: 1.5),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Full-screen "enter PIN" page used by settings. Pops with the PIN if [validate] accepts it.
class PinEntryPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Future<bool> Function(String pin) validate;

  const PinEntryPage({super.key, required this.title, required this.validate, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary, // visible back arrow on the light page
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: PinPad(
            title: title,
            subtitle: subtitle,
            onComplete: (pin) async {
              final ok = await validate(pin);
              if (ok && context.mounted) Navigator.of(context).pop(pin);
              return ok;
            },
          ),
        ),
      ),
    );
  }
}
