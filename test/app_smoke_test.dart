import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirana_store/core/db/app_database.dart';
import 'package:kirana_store/core/settings/shop_profile.dart';
import 'package:kirana_store/features/dashboard/presentation/dashboard_screen.dart';
import 'package:kirana_store/features/help/presentation/help_screen.dart';
import 'package:kirana_store/features/inventory/domain/product_model.dart';
import 'package:kirana_store/features/onboarding/onboarding_screen.dart';
import 'package:kirana_store/features/inventory/presentation/widgets/quick_add_product_sheet.dart';
import 'package:kirana_store/features/settings/presentation/settings_screen.dart';
import 'package:kirana_store/main.dart';
import 'package:kirana_store/core/security/lock_screen.dart';
import 'package:kirana_store/core/security/pin_lock.dart';

/// Pumps the real app shell on a small Android-phone-sized screen.
Future<AppDatabase> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final db = AppDatabase.inMemory();
  await tester.pumpWidget(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const MaterialApp(home: MainNavigationShell()),
  ));
  return db;
}

/// For screens with endless animations (spinners): advance a fixed number of frames.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _settle(WidgetTester tester) async {
  // Database work happens off the fake clock; let it finish, then settle frames.
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }
}

final _settingsList = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('first launch: Hindi setup, start empty, land on simple home', (tester) async {
    final db = await _pumpApp(tester);
    await _settle(tester);

    // Onboarding opens in Hindi.
    expect(find.text('नमस्ते! आपका स्वागत है'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'शर्मा किराना');
    await tester.enterText(find.byType(TextFormField).at(1), '9876543210');
    final start = find.text('शुरू करें  →');
    await tester.scrollUntilVisible(start, 200,
        scrollable: find.descendant(of: find.byType(OnboardingScreen), matching: find.byType(Scrollable)).first);
    await tester.tap(start);
    await _settle(tester);

    // Home shows the four big tiles and Hindi tabs.
    expect(find.text('सामान स्कैन करें'), findsOneWidget);
    expect(find.text('खाता (उधार)'), findsOneWidget);
    expect(find.text('मदद'), findsOneWidget);
    expect(find.text('सेटिंग'), findsOneWidget);

    // "Start empty" removed the sample items and saved the shop name.
    final settings = await tester.runAsync(() => db.getAllSettings());
    expect(settings![SettingKeys.shopName], 'शर्मा किराना');
    expect(settings[SettingKeys.onboarded], '1');
    final products = await tester.runAsync(() => db.select(db.products).get());
    expect(products, isEmpty);

    await tester.runAsync(() => db.close());
  });

  testWidgets('settings: every section opens without layout errors', (tester) async {
    final db = AppDatabase.inMemory();
    await db.upsertSettings({SettingKeys.onboarded: '1'});
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: MainNavigationShell()),
    ));
    await _settle(tester);

    await tester.tap(find.text('सेटिंग'));
    await _settle(tester);

    for (final title in ['दुकान की जानकारी', 'प्रिंटर', 'रसीद पर क्या छपे']) {
      await tester.scrollUntilVisible(find.text(title), 200, scrollable: _settingsList);
      await tester.tap(find.text(title));
      await _settle(tester);
    }

    // Turning a receipt switch off is saved straight away.
    final gstSwitch = find.widgetWithText(SwitchListTile, 'GST नंबर');
    await tester.scrollUntilVisible(gstSwitch, 200, scrollable: _settingsList);
    await tester.tap(gstSwitch);
    await _settle(tester);
    final settings = await tester.runAsync(() => db.getAllSettings());
    expect(settings![SettingKeys.showGstin], '0');

    expect(tester.takeException(), isNull);
    await tester.runAsync(() => db.close());
  });

  testWidgets('help: asking in Hinglish shows the printer guide', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));

    await tester.enterText(find.byType(TextField), 'printer kaise jode');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('ब्लूटूथ प्रिंटर कैसे जोड़ें'), findsWidgets);
    expect(find.textContaining('पेयर'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick add: name + price + qty saves a product with stock', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AppDatabase.inMemory();
    Product? result;

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => result = await showQuickAddProductSheet(context, initialQty: 12),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await _pumpFrames(tester);

    expect(find.text('नया सामान जोड़ें'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Parle-G 100g');
    await tester.enterText(find.byType(TextFormField).at(1), '10');
    // Bump the quantity once with the + button: 12 -> 13.
    await tester.tap(find.byIcon(Icons.add));
    await _pumpFrames(tester);
    await tester.ensureVisible(find.text('सेव करें'));
    await tester.tap(find.text('सेव करें'));
    // The save spinner animates while the database works, so pump frames
    // manually instead of waiting for the screen to settle.
    for (var i = 0; i < 40 && result == null; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(result, isNotNull);
    expect(result!.nameEn, 'Parle-G 100g');
    expect(result!.price, 10);
    expect(result!.stockQty, 13);
    expect(tester.takeException(), isNull);
    // In-memory database: no close needed (closing with the sheet's queries
    // still scheduled stalls the fake-async test clock).
  });

  testWidgets('narrow phone with large system font: home, bill, stock, khata, settings', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6; // app caps this at 1.2
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final db = AppDatabase.inMemory();
    await db.upsertSettings({SettingKeys.onboarded: '1'});
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const KiranaStoreApp(),
    ));
    await _settle(tester);
    expect(find.text('सामान स्कैन करें'), findsOneWidget);

    for (final tab in ['बिल', 'स्टॉक', 'खाता', 'सेटिंग', 'होम']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await _settle(tester);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back on any tab returns to Home instead of blanking the app', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AppDatabase.inMemory();
    await db.upsertSettings({SettingKeys.onboarded: '1'});
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const KiranaStoreApp(),
    ));
    await _settle(tester);

    for (final tab in ['बिल', 'स्टॉक', 'खाता', 'सेटिंग']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await _settle(tester);
      await tester.binding.handlePopRoute(); // Android Back button
      await _settle(tester);
      expect(find.byType(MainNavigationShell), findsOneWidget, reason: 'Back on $tab removed the app');
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0, reason: 'Back on $tab');
    }
  });

  testWidgets('reports and expenses screens on a narrow phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = AppDatabase.inMemory();
    await db.upsertSettings({SettingKeys.onboarded: '1'});

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const KiranaStoreApp(),
    ));
    await _settle(tester);

    // Expenses: add ₹1500 rent.
    await tester.scrollUntilVisible(find.text('खर्च लिखें'), 200,
        scrollable: find.descendant(of: find.byType(DashboardScreen), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('खर्च लिखें'));
    await _settle(tester);
    await tester.tap(find.text('खर्च जोड़ें'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, '1500');
    await tester.ensureVisible(find.text('सेव करें'));
    await tester.tap(find.text('सेव करें'));
    await _settle(tester);
    expect(find.text('₹1,500'), findsWidgets);
    await tester.binding.handlePopRoute(); // Android Back
    await _settle(tester);

    // Reports for this month show the expense.
    await tester.scrollUntilVisible(find.text('हिसाब / मुनाफ़ा'), 200,
        scrollable: find.descendant(of: find.byType(DashboardScreen), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('हिसाब / मुनाफ़ा'));
    await _settle(tester);
    await tester.tap(find.text('इस महीने'));
    await _settle(tester);
    expect(find.text('कुल बिक्री'), findsOneWidget);
    expect(find.textContaining('शुद्ध मुनाफ़ा'), findsOneWidget);
    expect(find.text('-₹1,500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PIN lock covers the app until the right PIN is entered', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('pin_ui')))!;
    final store = PinLockStore(() async => dir);
    await tester.runAsync(() => store.setPin('2580'));
    final db = AppDatabase.inMemory();
    await db.upsertSettings({SettingKeys.onboarded: '1'});

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db), pinLockStoreProvider.overrideWithValue(store)],
      child: const KiranaStoreApp(),
    ));
    await _settle(tester);
    expect(find.text('अपना 4 अंक का PIN डालें'), findsOneWidget);

    Future<void> type(String pin) async {
      for (final ch in pin.split('')) {
        await tester.tap(find.descendant(of: find.byType(PinPad), matching: find.text(ch)));
        await tester.pump();
      }
      await _settle(tester);
    }

    await type('1111');
    expect(find.text('गलत PIN, फिर से डालें'), findsOneWidget);
    await type('2580');
    expect(find.text('अपना 4 अंक का PIN डालें'), findsNothing);
    expect(find.text('सामान स्कैन करें'), findsOneWidget);
    await tester.runAsync(() => dir.delete(recursive: true));
  });
}
