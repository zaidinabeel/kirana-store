import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_theme.dart';
import 'core/i18n/app_strings.dart';
import 'core/security/lock_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation & status bar styles for high contrast light theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: KiranaStoreApp(),
    ),
  );
}

class KiranaStoreApp extends ConsumerWidget {
  const KiranaStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Kirana Store Management',
      debugShowCheckedModeBanner: false,
      // STRICT DESIGN CONSTRAINT: Hard-coded light theme only. No dark mode code path.
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      locale: language == AppLanguage.hi ? const Locale('hi', 'IN') : const Locale('en', 'IN'),
      supportedLocales: const [
        Locale('en', 'IN'),
        Locale('hi', 'IN'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Respect the phone's font size, but cap it so screens don't break apart
      // on phones set to very large text.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.2,
        // Covers every screen (including pushed pages) with the PIN pad when locked.
        child: AppLockGate(child: child!),
      ),
      home: const MainNavigationShell(),
    );
  }
}
