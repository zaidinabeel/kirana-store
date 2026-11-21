import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../../inventory/presentation/stock_scan_screen.dart';
import '../../help/presentation/help_screen.dart';
import '../../reports/reports_screen.dart';
import '../../reports/report_service.dart';
import '../../expenses/expenses_screen.dart';
import '../../onboarding/onboarding_screen.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/db/seed_data.dart';
import '../../../core/settings/shop_profile.dart';
import '../../inventory/state/inventory_notifier.dart';
import '../../billing/presentation/billing_screen.dart';
import '../../billing/presentation/bill_preview_screen.dart';
import '../../khata/presentation/khata_list_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    BillingScreen(isTab: true),
    InventoryScreen(),
    KhataListScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  Future<void> _startup() async {
    final db = ref.read(databaseProvider);
    final Map<String, String> settings;
    try {
      await SeedData.ensureSeeded(db);
      settings = await db.getAllSettings();
    } catch (e) {
      // The home screen shows the database error with a retry button.
      debugPrint('Startup failed: $e');
      return;
    }
    if (!mounted) return;
    if (settings[SettingKeys.onboarded] != '1') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    }
    // Daily automatic backup into phone storage (Documents/KiranaStore/Backups).
    if (!kIsWeb) {
      final made = await BackupService.autoBackupIfDue(ref.read(databaseProvider));
      if (made != null && mounted) ref.read(backupTickProvider.notifier).state++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hi = ref.watch(localeProvider) == AppLanguage.hi;
    const labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
    // Back on any tab goes to Home; Back on Home leaves the app.
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(labelTextStyle: WidgetStateProperty.all(labelStyle)),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primaryContainer,
            height: 70,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined, color: AppColors.primary, size: 28),
                selectedIcon: const Icon(Icons.home_rounded, color: AppColors.primary, size: 28),
                label: hi ? 'होम' : 'Home',
              ),
              NavigationDestination(
                icon: const Icon(Icons.point_of_sale_outlined, color: AppColors.primary, size: 28),
                selectedIcon: const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 28),
                label: hi ? 'बिल' : 'Bill',
              ),
              NavigationDestination(
                icon: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 28),
                selectedIcon: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 28),
                label: hi ? 'स्टॉक' : 'Stock',
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined, color: AppColors.primary, size: 28),
                selectedIcon: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 28),
                label: hi ? 'खाता' : 'Khata',
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined, color: AppColors.primary, size: 28),
                selectedIcon: const Icon(Icons.settings_rounded, color: AppColors.primary, size: 28),
                label: hi ? 'सेटिंग' : 'Settings',
              ),
            ],
          ),
        ),
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
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      await _loadDashboardDataUnsafe();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = '$e';
      });
    }
  }

  Future<void> _loadDashboardDataUnsafe() async {
    final db = ref.read(databaseProvider);

    // Same rules as the reports screen (khata "you gave" entries are not sales).
    final today = await ReportService.build(db, rangeFor(ReportPeriod.today, DateTime.now()));
    final total = Decimal.parse(today.totalSales.toStringAsFixed(2));

    final recent = await (db.select(db.invoices)
          ..orderBy([(i) => drift.OrderingTerm.desc(i.createdAt)])
          ..limit(6))
        .get();

    if (!mounted) return;
    setState(() {
      _loadError = null;
      _todaySales = total;
      _todayBillsCount = today.billCount;
      _recentInvoices = recent;
      _isLoading = false;
    });
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)).then((_) {
      _loadDashboardData();
      ref.read(inventoryProvider.notifier).loadCatalog();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final invState = ref.watch(inventoryProvider);
    final lowStockItems = invState.products.where((p) => p.product.stockQty <= p.product.reorderLevel).toList();

    return Scaffold(
      appBar: AppHeader(
        title: ref.watch(shopProfileProvider).valueOrNull?.displayName(lang == AppLanguage.hi) ??
            AppStrings.appTitle(lang),
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
          : _loadError != null
              ? _LoadErrorView(
                  message: _loadError!,
                  hindi: lang == AppLanguage.hi,
                  onRetry: () {
                    setState(() => _isLoading = true);
                    _loadDashboardData();
                  },
                )
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
                                  Flexible(
                                    child: Text(
                                      AppStrings.todaySales(lang),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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

                        // Big action tiles (2 x 2)
                        // Two rows of two equal-height tiles; heights grow with the text instead of overflowing.
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _ActionTile(
                                  emoji: '🛒',
                                  label: AppStrings.newBillAction(lang),
                                  color: AppColors.accent,
                                  onTap: () => _open(const BillingScreen()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionTile(
                                  emoji: '📷',
                                  label: lang == AppLanguage.hi ? 'सामान स्कैन करें' : 'Scan items',
                                  color: AppColors.surface,
                                  onTap: () => _open(const StockScanScreen()),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _ActionTile(
                                  emoji: '📒',
                                  label: lang == AppLanguage.hi ? 'खाता (उधार)' : 'Khata (credit)',
                                  color: AppColors.surface,
                                  onTap: () => _open(const KhataListScreen()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionTile(
                                  emoji: '📊',
                                  label: lang == AppLanguage.hi ? 'हिसाब / मुनाफ़ा' : 'Reports',
                                  color: AppColors.surface,
                                  onTap: () => _open(const ReportsScreen()),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _ActionTile(
                                  emoji: '🧾',
                                  label: lang == AppLanguage.hi ? 'खर्च लिखें' : 'Expenses',
                                  color: AppColors.surface,
                                  onTap: () => _open(const ExpensesScreen()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionTile(
                                  emoji: '❓',
                                  label: lang == AppLanguage.hi ? 'मदद' : 'Help',
                                  color: AppColors.surface,
                                  onTap: () => _open(const HelpScreen()),
                                ),
                              ),
                            ],
                          ),
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
                                    const Icon(Icons.warning_amber_rounded, color: AppColors.alert, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        AppStrings.lowStockAlert(lang, lowStockItems.length),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.alert,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                                        lang == AppLanguage.hi
                                            ? '${item.product.nameHi ?? item.product.nameEn} (${item.product.stockQty % 1 == 0 ? item.product.stockQty.toInt() : item.product.stockQty} बचा)'
                                            : '${item.product.nameEn} (${item.product.stockQty % 1 == 0 ? item.product.stockQty.toInt() : item.product.stockQty} left)',
                                        style: const TextStyle(
                                            fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.alert),
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
                            Expanded(
                              child: Text(
                                AppStrings.recentBills(lang),
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Text(
                              AppStrings.billsCount(lang, _recentInvoices.length),
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
                            child: Text(
                              lang == AppLanguage.hi
                                  ? 'अभी कोई बिल नहीं बना। "नया बिल" दबाकर शुरू करें।'
                                  : 'No bills yet. Tap "New Bill" to start selling.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
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
                                final timeStr =
                                    DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(inv.createdAt));
                                final isVoid = inv.status == 'void';

                                return ListTile(
                                  dense: true,
                                  title: Row(
                                    children: [
                                      Text(
                                        '${lang == AppLanguage.hi ? "बिल" : "Bill"} #${inv.invoiceNo}${inv.invoiceType == 'gst' ? ' (GST)' : ''}',
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
                                          child: const Text('VOID',
                                              style: TextStyle(
                                                  fontSize: 9, color: AppColors.alert, fontWeight: FontWeight.w800)),
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

class _ActionTile extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({required this.emoji, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider, width: 1.2),
          ),
          constraints: const BoxConstraints(minHeight: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32, height: 1.1)),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1.15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  final String message;
  final bool hindi;
  final VoidCallback onRetry;

  const _LoadErrorView({required this.message, required this.hindi, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.alert),
            const SizedBox(height: 12),
            Text(
              hindi ? 'डेटा खुल नहीं पाया' : 'Could not open your data',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(hindi ? 'फिर से कोशिश करें' : 'Try again', style: const TextStyle(fontSize: 17)),
            ),
          ],
        ),
      ),
    );
  }
}
