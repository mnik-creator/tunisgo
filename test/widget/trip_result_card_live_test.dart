// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
//
// Live badges only render when the app is built with a feed URL, so run with:
//   flutter test --dart-define=LIVE_FEED_URL=x test/widget/trip_result_card_live_test.dart
// Without it the test checks that the card stays badge-free.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunis_go/config/live_config.dart';
import 'package:tunis_go/core/models/trip.dart';
import 'package:tunis_go/core/widgets/trip_result_card.dart';
import 'package:tunis_go/features/live/live_board.dart';
import 'package:tunis_go/features/live/live_models.dart';
import 'package:tunis_go/features/live/live_providers.dart';
import 'package:tunis_go/l10n/app_localizations.dart';

Trip _trip({String? from = 'Tunis'}) => Trip(
      id: '1',
      lineId: '1',
      trainNumber: '157',
      fullTrainNumber: '157',
      departureTime: 10 * 60 + 40,
      arrivalTime: 11 * 60 + 8,
      serviceDays: 0x3F,
      trainType: 'INTERCITY',
      tripCode: 'ligne_a_tunis_erriadh_157',
      fromStationName: from,
    );

Widget _wrap(Trip trip, LiveFeed feed) => ProviderScope(
      overrides: [
        liveTrainIndexProvider.overrideWithValue(indexByTrainKey(feed)),
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
        home: Scaffold(body: TripResultCard(trip: trip, onTap: () {})),
      ),
    );

LiveFeed _feed({required String num, String? departedAt, String status = 'EN_ROUTE'}) => LiveFeed.fromJson({
      'v': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'trains': [
        {
          'id': '9',
          'num': num,
          'status': status,
          'delay': 7,
          'stops': [
            {'n': 'Tunis Ville', 'pd': '10:40', 'ad': ?departedAt},
            {'n': 'Ez-Zahra', 'pa': '11:08'},
            {'n': 'Erriadh', 'pa': '11:30'},
          ],
        },
      ],
    });

void main() {
  testWidgets('shows live delay for the boarding station', (tester) async {
    await tester.pumpWidget(_wrap(_trip(), _feed(num: '157')));
    expect(find.text('+7 min'), LiveConfig.isEnabled ? findsOneWidget : findsNothing);
  });

  testWidgets('shows departed once the train left', (tester) async {
    await tester.pumpWidget(_wrap(_trip(), _feed(num: '157', departedAt: '10:47')));
    expect(find.text('Parti'), LiveConfig.isEnabled ? findsOneWidget : findsNothing);
  });

  testWidgets('no badge for another train number', (tester) async {
    await tester.pumpWidget(_wrap(_trip(), _feed(num: '159')));
    expect(find.text('+7 min'), findsNothing);
  });

  testWidgets('cancelled train gets the red header', (tester) async {
    await tester.pumpWidget(_wrap(_trip(), _feed(num: '157', status: 'CANCELLED')));
    expect(
      find.text('Train supprimé · SNCFT'),
      LiveConfig.isEnabled ? findsOneWidget : findsNothing,
    );
  });
}
