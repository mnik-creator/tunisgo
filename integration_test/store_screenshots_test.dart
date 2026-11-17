// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
//
// Walks through the main screens and saves store screenshots.
// One language per run (the locale is read once at start-up):
//
//   flutter drive --driver test_driver/screenshots_driver.dart \
//     --target integration_test/store_screenshots_test.dart \
//     -d <simulator> --dart-define=NO_ADS=true \
//     --dart-define=WORKER_URL=https://tunisgo-live.tunisgo.workers.dev \
//     --dart-define=SHOT_LANG=fr
//
// Files land in build/store_screenshots/<lang>_<n>_<name>.png.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunis_go/main.dart' as app;
import 'package:tunis_go/router/app_router.dart';

const _lang = String.fromEnvironment('SHOT_LANG', defaultValue: 'fr');

const _from = {'fr': 'Tunis', 'en': 'Tunis', 'ar': 'تونس', 'ru': 'Тунис'};
const _to = {'fr': 'Sousse', 'en': 'Sousse', 'ar': 'سوسة', 'ru': 'Сусс'};

// Optional overrides: a different destination, and stop after the first shot.
const _toOverride = String.fromEnvironment('SHOT_TO');
const _onlySearch = bool.fromEnvironment('SHOT_ONLY_SEARCH');

const _sousse = {'fr': 'Sousse', 'en': 'Sousse', 'ar': 'سوسة', 'ru': 'Сусс'};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester t, [int ms = 2500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shot(WidgetTester t, String name) async {
    await settle(t, 1200);
    await binding.takeScreenshot('${_lang}_$name');
  }

  Future<void> pickStation(WidgetTester t, int field, String name) async {
    await t.tap(find.byType(TextField).at(field));
    await settle(t, 800);
    await t.enterText(find.byType(TextField).at(field), name);
    await settle(t, 1500);
    final tile = find.descendant(
      of: find.byType(ListTile),
      matching: find.text(name),
    );
    await t.tap(tile.first);
    await settle(t, 1200);
  }

  testWidgets('store screenshots', (t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', _lang);
    await prefs.setString('app_theme', 'light');

    app.main();
    await settle(t, 6000);

    // 1. Search with results for the whole day.
    await pickStation(t, 0, _from[_lang]!);
    await pickStation(t, 1, _toOverride.isNotEmpty ? _toOverride : _to[_lang]!);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t, 1000);
    await t.tap(find.byIcon(Icons.close).last); // time → "all trains"
    await settle(t, 800);
    await t.tap(find.byIcon(Icons.search).first);
    await settle(t, 3000);
    await shot(t, '1_search');
    if (_onlySearch) return;

    // 2. Trip detail sheet (a mid-morning train).
    final cards = find.textContaining(RegExp(r'^0[6-9]:\d\d$'));
    await t.scrollUntilVisible(cards.first, 200,
        scrollable: find.byType(Scrollable).first);
    await settle(t, 800);
    await t.tap(cards.first);
    await settle(t, 3000);
    await shot(t, '2_trip');
    Navigator.of(t.element(find.byIcon(Icons.adaptive.share))).pop();
    await settle(t, 1500);

    // 3. Live departures board for the departure station.
    await t.scrollUntilVisible(find.byIcon(Icons.sensors), -200,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.byIcon(Icons.sensors));
    await settle(t, 6000);
    await shot(t, '3_live');
    Navigator.of(t.element(find.byType(BottomSheet).first)).pop();
    await settle(t, 1500);

    // 4. Lines → full timetable of one line.
    appRouter.go('/lines');
    await settle(t, 2500);
    await shot(t, '4_lines');
    // First line through Sousse (Tunis–Sousse among the main lines).
    final line = find.textContaining(_sousse[_lang]!);
    await t.scrollUntilVisible(line.first, 200,
        scrollable: find.byType(Scrollable).first);
    await settle(t, 800);
    await t.tap(line.first);
    await settle(t, 8000);
    await shot(t, '5_timetable');
    Navigator.of(t.element(find.byType(BottomSheet).first)).pop();
    await settle(t, 1500);

    // 6. Dark mode results.
    appRouter.go('/settings');
    await settle(t, 2000);
    await t.tap(find.byIcon(Icons.dark_mode_outlined));
    await settle(t, 1500);
    appRouter.go('/search');
    await settle(t, 3000);
    await pickStation(t, 0, _from[_lang]!);
    await pickStation(t, 1, _to[_lang]!);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t, 1000);
    await t.tap(find.byIcon(Icons.close).last);
    await settle(t, 800);
    await t.tap(find.byIcon(Icons.search).first);
    await settle(t, 3000);
    await shot(t, '6_dark');

    await prefs.setString('app_theme', 'light');
  });
}
