import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/money/money_utils.dart';
import '../../../core/validation/validators.dart';
import '../../../core/validation/formatters.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/debounced_button.dart';
import '../state/khata_notifier.dart';
import 'khata_detail_screen.dart';

class KhataListScreen extends ConsumerStatefulWidget {
  const KhataListScreen({super.key});

  @override
  ConsumerState<KhataListScreen> createState() => _KhataListScreenState();
}

class _KhataListScreenState extends ConsumerState<KhataListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCustomerModal() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final balanceController = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add New Khata Customer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameController,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  hintText: 'e.g. Rajesh Kumar',
                  counterText: '',
                ),
                validator: Validators.customerName,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 13,
                inputFormatters: [DigitsOnlyFormatter(13)],
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: 'e.g. 9810123456',
                  counterText: '',
                ),
                validator: (v) {
                  final err = Validators.mobileNumber(v, isRequired: false);
                  if (err != null) return err;
                  if (v != null && v.trim().isNotEmpty) {
                    final clean = Validators.cleanMobileNumber(v);
                    final khataState = ref.read(khataProvider);
                    final exists = khataState.customers.any((c) =>
                        c.customer.phone != null &&
                        Validators.cleanMobileNumber(c.customer.phone!) == clean);
                    if (exists) return 'Customer with this phone already exists';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: addressController,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Address / Landmark',
                  hintText: 'e.g. House #12, Gali 2',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter(2)],
                decoration: const InputDecoration(
                  labelText: 'Opening Due Balance (₹)',
                  hintText: '0 if new customer',
                ),
                validator: (v) => Validators.price(v, isRequired: false, fieldName: 'Opening Balance'),
              ),
              const SizedBox(height: 18),
              DebouncedButton(
                height: 50,
                backgroundColor: AppColors.primary,
                semanticLabel: 'Save customer button',
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final name = nameController.text.trim();
                  final opBalance = double.tryParse(balanceController.text.trim()) ?? 0.0;
                  final err = await ref.read(khataProvider.notifier).addCustomer(
                    name: name,
                    phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                    address: addressController.text.trim().isNotEmpty ? addressController.text.trim() : null,
                    openingBalance: opBalance,
                  );

                  if (err != null && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(err), backgroundColor: AppColors.alert),
                    );
                  } else if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final khataState = ref.watch(khataProvider);
    final customers = khataState.filteredCustomers;

    return Scaffold(
      appBar: AppHeader(
        title: AppStrings.khata(lang),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimary,
        elevation: 2,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
        label: Text(
          AppStrings.addCustomer(lang),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        onPressed: _showAddCustomerModal,
      ),
      body: Column(
        children: [
          // Outstanding Market Due Hero Banner
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.totalOutstanding(lang),
                          style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          MoneyUtils.formatCurrency(khataState.totalOutstanding),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${khataState.customers.length} Customers',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search Bar
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => ref.read(khataProvider.notifier).setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: AppStrings.searchCustomer(lang),
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(khataProvider.notifier).setSearchQuery('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Customer List
          Expanded(
            child: khataState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : customers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline, size: 54, color: AppColors.textMuted.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No customer matches "${_searchController.text}"'
                                    : 'No khata customers yet. Tap "+ Add Customer" to create an account.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: customers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (ctx, index) {
                          final item = customers[index];
                          final c = item.customer;
                          final isDue = item.currentBalance > Decimal.zero;

                          return InkWell(
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => KhataDetailScreen(customer: c),
                                ),
                              );
                              ref.read(khataProvider.notifier).loadCustomers();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isDue ? AppColors.alertLight : AppColors.surfaceMuted,
                                    child: Text(
                                      c.name.substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontWeight: FontWeight.w800,
                                        color: isDue ? AppColors.alert : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                        ),
                                        if (c.phone != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            c.phone!,
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        MoneyUtils.formatCurrency(item.currentBalance),
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: isDue ? AppColors.alert : AppColors.success,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isDue ? 'Due Amount' : 'Clear',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDue ? AppColors.alert : AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.border),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
