import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/db/seed_data.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/settings/shop_profile.dart';
import '../../core/validation/formatters.dart';
import '../../core/validation/validators.dart';
import '../inventory/domain/product_model.dart';
import '../inventory/state/inventory_notifier.dart';
import '../khata/state/khata_notifier.dart';

/// One-time welcome: shop name, phone, and whether to keep the sample items.
/// Returns true when finished.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _keepSample = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    await SeedData.ensureSeeded(db);

    final current = await ref.read(shopProfileProvider.future);
    final name = _name.text.trim();
    final isDevanagari = RegExp(r'[ऀ-ॿ]').hasMatch(name);
    ShopProfile profile;
    if (_keepSample) {
      profile = current.copyWith(nameEn: name, nameHi: isDevanagari ? name : '', phone: _phone.text.trim());
    } else {
      await SeedData.clearSampleData(db);
      // Drop the sample shop's address and GST number too.
      profile = ShopProfile(
        nameEn: name,
        nameHi: isDevanagari ? name : '',
        phone: _phone.text.trim(),
        footerEn: current.footerEn,
        footerHi: current.footerHi,
        paperWidth: current.paperWidth,
        receipt: current.receipt,
      );
    }
    await ref.read(shopProfileProvider.notifier).save(profile);
    await db.upsertSettings({SettingKeys.onboarded: '1'});
    await ref.read(inventoryProvider.notifier).loadCatalog();
    await ref.read(khataProvider.notifier).loadCustomers();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final hi = lang == AppLanguage.hi;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: SegmentedButton<AppLanguage>(
                      segments: const [
                        ButtonSegment(value: AppLanguage.hi, label: Text('हिंदी')),
                        ButtonSegment(value: AppLanguage.en, label: Text('English')),
                      ],
                      selected: {lang},
                      onSelectionChanged: (s) => ref.read(localeProvider.notifier).setLanguage(s.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('🏪', style: TextStyle(fontSize: 64), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    hi ? 'नमस्ते! आपका स्वागत है' : 'Welcome!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hi ? 'बस दो चीज़ें बताइए, फिर बिल बनाना शुरू करें।' : 'Tell us two things and start billing.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _name,
                    maxLength: 80,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: hi ? 'दुकान का नाम' : 'Shop name',
                      hintText: hi ? 'जैसे: शर्मा किराना स्टोर' : 'e.g. Sharma Kirana Store',
                      counterText: '',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? (hi ? 'दुकान का नाम लिखें' : 'Enter the shop name') : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    maxLength: 13,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [DigitsOnlyFormatter(13)],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: hi ? 'मोबाइल नंबर (रसीद पर छपेगा)' : 'Mobile number (printed on receipts)',
                      counterText: '',
                    ),
                    validator: (v) => Validators.mobileNumber(v, isRequired: false),
                  ),
                  const SizedBox(height: 20),
                  Text(hi ? 'कैसे शुरू करें?' : 'How do you want to start?',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _choice(
                    selected: !_keepSample,
                    icon: '✨',
                    title: hi ? 'खाली शुरू करें' : 'Start empty',
                    subtitle: hi
                        ? 'अपनी असली दुकान के लिए — अपना सामान स्कैन करके जोड़ें'
                        : 'For your real shop — scan your own items',
                    onTap: () => setState(() => _keepSample = false),
                  ),
                  const SizedBox(height: 8),
                  _choice(
                    selected: _keepSample,
                    icon: '🎓',
                    title: hi ? 'नमूना सामान के साथ सीखें' : 'Learn with sample items',
                    subtitle: hi
                        ? 'आटा, चीनी, मैगी जैसे नमूने — ऐप चलाना सीखने के लिए'
                        : 'Sample atta, sugar, Maggi — to practise',
                    onTap: () => setState(() => _keepSample = true),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _saving ? null : _finish,
                      child: _saving
                          ? const CircularProgressIndicator()
                          : Text(hi ? 'शुरू करें  →' : 'Start  →',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice({
    required bool selected,
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentLight : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.accent : AppColors.divider, width: selected ? 2.5 : 1),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.accentHover : AppColors.border, size: 28),
          ],
        ),
      ),
    );
  }
}
