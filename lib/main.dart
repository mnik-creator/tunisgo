// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/helpers/locale_provider.dart';
import 'core/helpers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/favorites/favorites_notifications_manager.dart';
import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'services/ad_service.dart';
import 'services/interstitial_ad_service.dart';

class _NoStretchScrollBehavior extends ScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  if (!kIsWeb) {
    // Initialize AdMob (mobile only)
    await AdService.initialize();

    // Preload ads in background (don't await — no need to block startup)
    unawaited(InterstitialAdService.preload());
  }

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // Activate the favorites notifications manager so daily reminders stay in sync.
  container.read(favoritesNotificationsManagerProvider);

  runApp(
    UncontrolledProviderScope(container: container, child: const TunisGoApp()),
  );
}

class TunisGoApp extends ConsumerStatefulWidget {
  const TunisGoApp({super.key});

  @override
  ConsumerState<TunisGoApp> createState() => _TunisGoAppState();
}

class _TunisGoAppState extends ConsumerState<TunisGoApp> {
  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'TunisGO',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _NoStretchScrollBehavior(),
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
    );
  }
}
