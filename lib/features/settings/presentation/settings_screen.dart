import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/settings/shop_profile.dart';
import '../../../core/validation/formatters.dart';
import '../../../core/validation/validators.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/debounced_button.dart';
import '../../help/presentation/help_screen.dart';
import 'widgets/backup_section.dart';
import 'widgets/pin_section.dart';
import 'widgets/printer_section.dart';

/// Settings as a list of big, clearly labelled cards. Each card opens on tap so
/// the screen never looks crowded.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final hi = lang == AppLanguage.hi;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(title: AppStrings.settings(lang)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _SettingsCard(
            icon: Icons.store_rounded,
            title: hi ? 'दुकान की जानकारी' : 'Shop details',
            subtitle: hi ? 'नाम, पता, फ़ोन, GST, UPI' : 'Name, address, phone, GST, UPI',
            child: const ShopProfileForm(),
          ),
          _SettingsCard(
            icon: Icons.print_rounded,
            title: hi ? 'प्रिंटर' : 'Printer',
            subtitle: hi ? 'ब्लूटूथ प्रिंटर जोड़ें, टेस्ट प्रिंट' : 'Connect Bluetooth printer, test print',
            child: const PrinterSection(),
          ),
          _SettingsCard(
            icon: Icons.receipt_long_rounded,
            title: hi ? 'रसीद पर क्या छपे' : 'What prints on the receipt',
            subtitle: hi ? 'हर चीज़ चालू / बंद करें' : 'Turn each item on or off',
            child: const ReceiptOptionsSection(),
          ),
          _SettingsCard(
            icon: Icons.backup_rounded,
            title: hi ? 'बैकअप (डेटा सुरक्षा)' : 'Backup',
            subtitle: hi ? 'फ़ोन में अपने आप बैकअप, WhatsApp/Drive पर भेजें' : 'Automatic phone backup, send to WhatsApp/Drive',
            initiallyExpanded: true,
            child: const BackupSection(),
          ),
          _SettingsCard(
            icon: Icons.lock_rounded,
            title: hi ? 'PIN लॉक' : 'PIN lock',
            subtitle: hi ? '4 अंक का PIN — खाता सुरक्षित रखें' : '4-digit PIN to keep data private',
            child: const PinSection(),
          ),
          _SettingsCard(
            icon: Icons.translate_rounded,
            title: hi ? 'भाषा / Language' : 'Language / भाषा',
            subtitle: hi ? 'हिंदी' : 'English',
            child: SegmentedButton<AppLanguage>(
              segments: const [
                ButtonSegment(value: AppLanguage.hi, label: Text('हिंदी', style: TextStyle(fontSize: 16))),
                ButtonSegment(value: AppLanguage.en, label: Text('English', style: TextStyle(fontSize: 16))),
              ],
              selected: {lang},
              onSelectionChanged: (s) => ref.read(localeProvider.notifier).setLanguage(s.first),
            ),
          ),
          const SizedBox(height: 6),
          Card(
            color: AppColors.accentLight,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const Text('❓', style: TextStyle(fontSize: 30)),
              title: Text(hi ? 'मदद / कैसे करें' : 'Help / How to',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              subtitle: Text(hi ? 'हिंदी में आसान गाइड, सवाल पूछें' : 'Simple guides, ask a question'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 30),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(icon, color: AppColors.primary, size: 30),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        children: [child],
      ),
    );
  }
}

/// Shop name, address, phone, GSTIN, UPI ID and receipt footer.
class ShopProfileForm extends ConsumerStatefulWidget {
  const ShopProfileForm({super.key});

  @override
  ConsumerState<ShopProfileForm> createState() => _ShopProfileFormState();
}

class _ShopProfileFormState extends ConsumerState<ShopProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameHi = TextEditingController();
  final _address = TextEditingController();
  final _addressHi = TextEditingController();
  final _phone = TextEditingController();
  final _gstin = TextEditingController();
  final _upi = TextEditingController();
  final _footerEn = TextEditingController();
  final _footerHi = TextEditingController();
  bool _loaded = false;

  static final upiPattern = RegExp(r'^[\w.\-]{2,256}@[a-zA-Z][a-zA-Z0-9]{1,63}$');

  @override
  void dispose() {
    for (final c in [_name, _nameHi, _address, _addressHi, _phone, _gstin, _upi, _footerEn, _footerHi]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(ShopProfile p) {
    _name.text = p.nameEn;
    _nameHi.text = p.nameHi;
    _address.text = p.addressEn;
    _addressHi.text = p.addressHi;
    _phone.text = p.phone;
    _gstin.text = p.gstin;
    _upi.text = p.upiId;
    _footerEn.text = p.footerEn;
    _footerHi.text = p.footerHi;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final hi = ref.read(localeProvider) == AppLanguage.hi;
    final current = ref.read(shopProfileProvider).valueOrNull ?? ShopProfile.empty;
    try {
      await ref.read(shopProfileProvider.notifier).save(current.copyWith(
            nameEn: _name.text,
            nameHi: _nameHi.text,
            addressEn: _address.text,
            addressHi: _addressHi.text,
            phone: _phone.text,
            gstin: _gstin.text,
            upiId: _upi.text,
            footerEn: _footerEn.text,
            footerHi: _footerHi.text,
          ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(hi ? '✓ दुकान की जानकारी सेव हो गई' : '✓ Shop details saved'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(hi ? 'सेव नहीं हुआ: $e' : 'Could not save: $e'),
        backgroundColor: AppColors.alert,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hi = ref.watch(localeProvider) == AppLanguage.hi;
    final profile = ref.watch(shopProfileProvider);
    if (!_loaded && profile.hasValue) {
      _fill(profile.requireValue);
      _loaded = true;
    }

    Widget field(
      TextEditingController c,
      String label, {
      String? hint,
      int maxLength = 80,
      TextInputType? keyboard,
      List<TextInputFormatter>? formatters,
      FormFieldValidator<String>? validator,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          maxLength: maxLength,
          keyboardType: keyboard,
          inputFormatters: formatters,
          validator: validator,
          style: const TextStyle(fontSize: 17),
          decoration: InputDecoration(labelText: label, hintText: hint, counterText: ''),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field(_name, hi ? 'दुकान का नाम' : 'Shop name',
              validator: (v) => v == null || v.trim().isEmpty ? (hi ? 'दुकान का नाम लिखें' : 'Shop name is required') : null),
          field(_nameHi, hi ? 'दुकान का नाम हिंदी में (हिंदी रसीद पर)' : 'Shop name in Hindi (optional)'),
          field(_address, hi ? 'पता' : 'Address', maxLength: 150),
          field(_addressHi, hi ? 'पता हिंदी में (ज़रूरी नहीं)' : 'Address in Hindi (optional)', maxLength: 150),
          field(_phone, hi ? 'दुकान का मोबाइल नंबर' : 'Shop mobile number',
              maxLength: 13,
              keyboard: TextInputType.phone,
              formatters: [DigitsOnlyFormatter(13)],
              validator: (v) => Validators.mobileNumber(v, isRequired: false)),
          field(_gstin, hi ? 'GST नंबर (ज़रूरी नहीं)' : 'GSTIN (optional)',
              maxLength: 15, formatters: [AlphanumericUppercaseFormatter(15)], validator: Validators.gstin),
          field(_upi, hi ? 'UPI ID (ज़रूरी नहीं)' : 'UPI ID (optional)',
              hint: hi ? 'जैसे: dukan@okaxis' : 'e.g. shop@okaxis',
              maxLength: 100,
              keyboard: TextInputType.emailAddress, validator: (v) {
            final value = v?.trim() ?? '';
            if (value.isEmpty) return null;
            return upiPattern.hasMatch(value) ? null : (hi ? 'सही UPI ID लिखें (नाम@बैंक)' : 'Enter a valid UPI ID (name@bank)');
          }),
          field(_footerHi, hi ? 'रसीद के नीचे संदेश (हिंदी)' : 'Receipt footer (Hindi)', maxLength: 120),
          field(_footerEn, hi ? 'रसीद के नीचे संदेश (English)' : 'Receipt footer (English)', maxLength: 120),
          DebouncedButton(
            height: 52,
            backgroundColor: AppColors.primary,
            semanticLabel: 'Save shop profile',
            onPressed: _save,
            child: Text(hi ? 'सेव करें' : 'Save',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
