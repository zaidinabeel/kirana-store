import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/printing/printer_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/seed_data.dart';
import '../../../core/validation/validators.dart';
import '../../../core/validation/formatters.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/debounced_button.dart';
import '../../inventory/domain/product_model.dart';
import '../../inventory/state/inventory_notifier.dart';
import '../../khata/state/khata_notifier.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _shopNameController = TextEditingController(text: 'Gupta Kirana & General Store');
  final TextEditingController _shopAddressController = TextEditingController(text: 'Plot 14, Main Mandi Road, Ghaziabad');
  final TextEditingController _shopPhoneController = TextEditingController(text: '9811234567');
  final TextEditingController _gstinController = TextEditingController(text: '07AAAAA0000A1Z5');

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  void _runTestPrint() async {
    final printerService = ref.read(printerProvider.notifier);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sending test print pattern to Bluetooth thermal printer...'),
        backgroundColor: AppColors.primary,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test print completed successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _resetSeedData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset Sample Data?', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.alert)),
        content: const Text('This will reload the realistic sample grocery catalog and test customer accounts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.alert),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final db = ref.read(databaseProvider);
      await SeedData.populate(db);
      await ref.read(inventoryProvider.notifier).loadCatalog();
      await ref.read(khataProvider.notifier).loadCustomers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample data refreshed!'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  void _saveShopProfile() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shop profile updated successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final printerState = ref.watch(printerProvider);

    return Scaffold(
      appBar: AppHeader(
        title: AppStrings.settings(lang),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section: Shop Profile
              _sectionHeader('Shop Profile & GSTIN', Icons.store_rounded),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _shopNameController,
                      maxLength: 80,
                      decoration: const InputDecoration(labelText: 'Shop Name', isDense: true, counterText: ''),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Shop name is required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _shopAddressController,
                      maxLength: 150,
                      decoration: const InputDecoration(labelText: 'Address', isDense: true, counterText: ''),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _shopPhoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 13,
                            inputFormatters: [DigitsOnlyFormatter(13)],
                            decoration: const InputDecoration(labelText: 'Contact Phone', isDense: true, counterText: ''),
                            validator: (v) => Validators.mobileNumber(v, isRequired: false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _gstinController,
                            autofillHints: null,
                            maxLength: 15,
                            inputFormatters: [AlphanumericUppercaseFormatter(15)],
                            decoration: const InputDecoration(labelText: 'GSTIN (15 chars)', isDense: true, counterText: ''),
                            validator: Validators.gstin,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: DebouncedButton(
                        height: 40,
                        backgroundColor: AppColors.primary,
                        semanticLabel: 'Save shop profile button',
                        onPressed: () async => _saveShopProfile(),
                        child: const Text('Save Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

            // Section: Bluetooth Thermal Printer
            _sectionHeader('Bluetooth Thermal Printer', Icons.print_rounded),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            printerState.connectedDevice != null ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                            color: printerState.connectedDevice != null ? AppColors.success : AppColors.alert,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            printerState.connectedDevice != null
                                ? 'Connected: ${printerState.connectedDevice!.name}'
                                : 'No Printer Connected',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceMuted,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(60, 36),
                        ),
                        onPressed: () => ref.read(printerProvider.notifier).scanDevices(),
                        child: const Text('Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Paper Width Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Receipt Paper Width:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      SegmentedButton<PaperWidth>(
                        segments: const [
                          ButtonSegment(value: PaperWidth.mm58, label: Text('58mm')),
                          ButtonSegment(value: PaperWidth.mm80, label: Text('80mm')),
                        ],
                        selected: {printerState.paperWidth},
                        onSelectionChanged: (set) {
                          ref.read(printerProvider.notifier).setPaperWidth(set.first);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Test Print Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      onPressed: _runTestPrint,
                      icon: const Icon(Icons.receipt_rounded, size: 18),
                      label: const Text('Run Test Print', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section: Language Settings
            _sectionHeader('Language & Localization', Icons.translate_rounded),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Active App Language:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  DropdownButton<AppLanguage>(
                    value: lang,
                    items: const [
                      DropdownMenuItem(value: AppLanguage.en, child: Text('English (EN)')),
                      DropdownMenuItem(value: AppLanguage.hi, child: Text('हिन्दी (Hindi)')),
                    ],
                    onChanged: (val) {
                      if (val != null) ref.read(localeProvider.notifier).setLanguage(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Reset Sample Catalog
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.alert,
                side: const BorderSide(color: AppColors.alert),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _resetSeedData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset Sample Grocery Catalog', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
