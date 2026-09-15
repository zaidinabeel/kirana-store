import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/money/money_utils.dart';
import '../../../core/db/app_database.dart';
import '../../../shared/widgets/app_header.dart';
import '../../inventory/domain/product_model.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../inventory/presentation/add_edit_product_screen.dart';
import '../../inventory/presentation/widgets/barcode_scanner_modal.dart';
import '../../inventory/state/inventory_notifier.dart';
import '../../billing/presentation/billing_screen.dart';
import '../../billing/presentation/bill_preview_screen.dart';
import '../../khata/presentation/khata_list_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    BillingScreen(),
    InventoryScreen(),
    KhataListScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryContainer,
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: AppColors.primary),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined, color: AppColors.primary),
            selectedIcon: Icon(Icons.point_of_sale_rounded, color: AppColors.primary),
            label: 'Billing',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined, color: AppColors.primary),
            selectedIcon: Icon(Icons.inventory_2_rounded, color: AppColors.primary),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined, color: AppColors.primary),
            selectedIcon: Icon(Icons.menu_book_rounded, color: AppColors.primary),
            label: 'Khata',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: AppColors.primary),
            selectedIcon: Icon(Icons.settings_rounded, color: AppColors.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  List<Invoice> _recentInvoices = [];
  Decimal _todaySales = Decimal.zero;
  int _todayBillsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final allInvoices = await (db.select(db.invoices)
      ..where((i) => i.createdAt.isBiggerOrEqualValue(startOfDay) & i.status.equals('active')))
      .get();

    Decimal total = Decimal.zero;
    for (final inv in allInvoices) {
      total += MoneyUtils.parse(inv.total);
    }

    final recent = await (db.select(db.invoices)
      ..orderBy([(i) => drift.OrderingTerm.desc(i.createdAt)])
      ..limit(6))
      .get();

    setState(() {
      _todaySales = total;
      _todayBillsCount = allInvoices.length;
      _recentInvoices = recent;
      _isLoading = false;
    });
  }

  void _openBarcodeScannerForStock() {
    showDialog(
      context: context,
      builder: (ctx) => BarcodeScannerModal(
        title: 'Scan Barcode to Add Stock',
        onBarcodeScanned: (code) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddEditProductScreen(initialBarcode: code),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final invState = ref.watch(inventoryProvider);
    final lowStockItems = invState.products.where((p) => p.product.stockQty <= p.product.reorderLevel).toList();

    return Scaffold(
      appBar: AppHeader(
        title: AppStrings.appTitle(lang),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              _loadDashboardData();
              ref.read(inventoryProvider.notifier).loadCatalog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadDashboardData();
                await ref.read(inventoryProvider.notifier).loadCatalog();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Metric: Today's Sales Total
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x181F3A5F),
                            offset: Offset(0, 4),
                            blurRadius: 12,
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppStrings.todaySales(lang),
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  AppStrings.billsCount(lang, _todayBillsCount),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            MoneyUtils.formatCurrency(_todaySales),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Quick Actions
                    Text(
                      AppStrings.quickActions(lang),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // New Bill Button (Primary CTA)
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const BillingScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 84,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(Icons.add_shopping_cart_rounded, color: AppColors.textPrimary, size: 26),
                                  Text(
                                    AppStrings.newBillAction(lang),
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Scan & Add Stock Button
                        Expanded(
                          child: InkWell(
                            onTap: _openBarcodeScannerForStock,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 84,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.divider, width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 26),
                                  Text(
                                    AppStrings.addStockAction(lang),
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // View Khata Button
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const KhataListScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 84,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.divider, width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 26),
                                  Text(
                                    AppStrings.viewKhataAction(lang),
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Low Stock Alert Strip
                    if (lowStockItems.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.alertLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.alert.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: AppColors.alert, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppStrings.lowStockAlert(lang, lowStockItems.length),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.alert,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 30),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    ref.read(inventoryProvider.notifier).setFilter(InventoryFilter.lowStock);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const InventoryScreen()),
                                    );
                                  },
                                  child: Text(
                                    AppStrings.restockNow(lang),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.alert,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: lowStockItems.take(3).map((item) {
                                return Chip(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                  label: Text(
                                    '${item.product.nameEn} (${item.product.stockQty} left)',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.alert),
                                  ),
                                  side: const BorderSide(color: AppColors.alert, width: 0.8),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Recent Bills Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.recentBills(lang),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '${_recentInvoices.length} Bills',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_recentInvoices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'No bills generated today yet. Tap "New Bill" to start selling.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentInvoices.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final inv = _recentInvoices[i];
                            final timeStr = DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(inv.createdAt));
                            final isVoid = inv.status == 'void';

                            return ListTile(
                              dense: true,
                              title: Row(
                                children: [
                                  Text(
                                    'Bill #${inv.invoiceNo} (${inv.invoiceType.toUpperCase()})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      decoration: isVoid ? TextDecoration.lineThrough : null,
                                      color: isVoid ? AppColors.textMuted : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (isVoid) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.alertLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('VOID', style: TextStyle(fontSize: 9, color: AppColors.alert, fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text('$timeStr • ${inv.paymentMode.toUpperCase()}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${inv.total.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isVoid ? AppColors.textMuted : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.border),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BillPreviewScreen(invoice: inv),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
