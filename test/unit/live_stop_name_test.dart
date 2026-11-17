// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'package:flutter_test/flutter_test.dart';
import 'package:tunis_go/core/models/station.dart';
import 'package:tunis_go/features/live/live_board_sheet.dart';
import 'package:tunis_go/features/live/live_models.dart';
import 'package:tunis_go/features/live/station_aliases.dart';

void main() {
  const gabes = Station(
    id: '1', slug: 'gabes', nameFr: 'Gabes', nameAr: 'قابس',
    nameEn: '', nameRu: 'Габес', isActive: true,
  );
  final byName = {normalizeStationName(gabes.nameFr): gabes};
  final stop = LiveStopTime.fromJson({'n': 'GABES', 'a': 'قابس'});

  test('Arabic comes from SNCFT, Russian from the bundled stations', () {
    expect(liveStopName(stop, 'ar', byName), 'قابس');
    expect(liveStopName(stop, 'ru', byName), 'Габес');
    expect(liveStopName(stop, 'fr', byName), 'Gabes');
  });

  test('unknown stop keeps the feed name', () {
    final other = LiveStopTime.fromJson({'n': 'NOWHERE'});
    expect(liveStopName(other, 'ru', byName), 'NOWHERE');
    expect(liveStopName(stop, 'ru', null), 'GABES');
  });
}
