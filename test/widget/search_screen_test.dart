// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunis_go/core/database/database_helper.dart';
import 'package:tunis_go/core/helpers/locale_provider.dart';
import 'package:tunis_go/core/repositories/providers.dart';
import 'package:tunis_go/core/repositories/station_repository.dart';
import 'package:tunis_go/features/search/search_screen.dart';
import 'package:tunis_go/l10n/app_localizations.dart';

// Fake DB returning two stations.
class _FakeDb extends DatabaseHelper {
  _FakeDb() : super.forTesting();

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async =>
      [
        {
          'id': 1,
          'code': 'TUN',
          'name_fr': 'Tunis',
          'name_ar': 'تونس',
          'name_en': 'Tunis',
          'is_major': 1,
        },
        {
          'id': 2,
          'code': 'BBR',
          'name_fr': 'Bir Bou Rekba',
          'name_ar': 'بئر بو ركبة',
          'name_en': 'Bir Bou Rekba',
          'is_major': 1,
        },
      ];
}

Widget _wrap(Widget child, SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      stationRepositoryProvider.overrideWithValue(
        StationRepository(_FakeDb()),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('SearchScreen shows From and To fields', (tester) async {
    await tester.pumpWidget(_wrap(const SearchScreen(), prefs));
    await tester.pump();

    // Verify the search form fields are present
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('SearchScreen search button is disabled when fields are empty',
      (tester) async {
    await tester.pumpWidget(_wrap(const SearchScreen(), prefs));
    await tester.pump();

    final searchButton = find.widgetWithText(FilledButton, 'Rechercher');
    expect(searchButton, findsOneWidget);

    // Button should be disabled (onPressed == null) when no stations selected.
    final btn = tester.widget<FilledButton>(searchButton);
    expect(btn.onPressed, isNull);
  });
}
