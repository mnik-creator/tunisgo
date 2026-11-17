// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
//
// The bundled sncft.db with transtu.db attached through
// DatabaseHelper.attachTranstu, queried by the real repositories.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tunis_go/core/database/database_helper.dart';
import 'package:tunis_go/core/models/trip.dart';
import 'package:tunis_go/core/repositories/line_repository.dart';
import 'package:tunis_go/core/repositories/station_repository.dart';
import 'package:tunis_go/core/repositories/trip_repository.dart';

class _TestDb extends DatabaseHelper {
  _TestDb(this.db) : super.forTesting();
  final Database db;

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) =>
      db.rawQuery(sql, args);
}

void main() {
  late Directory tmp;
  late Database db;
  late _TestDb helper;

  setUpAll(() async {
    sqfliteFfiInit();
    tmp = Directory.systemTemp.createTempSync('transtu_attach');
    File('assets/db/sncft.db').copySync('${tmp.path}/sncft.db');
    File('assets/db/transtu.db').copySync('${tmp.path}/transtu.db');
    db = await databaseFactoryFfi.openDatabase('${tmp.path}/sncft.db');
    expect(
      await DatabaseHelper.attachTranstu(db, '${tmp.path}/transtu.db'),
      isTrue,
    );
    helper = _TestDb(db);
  });

  tearDownAll(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<String> stopId(String name) async =>
      '${(await db.rawQuery('SELECT id FROM stops WHERE name = ?', [name])).single['id']}';

  test('ids of the two databases never overlap', () async {
    for (final t in ['stops', 'routes', 'trips', 'stop_times', 'fares', 'fare_rules']) {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM main.$t m JOIN transtu.$t x ON x.id = m.id',
      );
      expect(rows.single['n'], 0, reason: t);
    }
    final trips = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM main.trips m JOIN transtu.trips x ON x.trip_id = m.trip_id',
    );
    expect(trips.single['n'], 0);
  });

  test('line list has the six metro lines and the TGM, paired', () async {
    final lines = await LineRepository(helper).getAllLines();
    final transtu = lines
        .where((l) => l.lineCategory == 'metro' || l.lineCategory == 'tgm')
        .toList();
    expect(transtu.map((l) => l.nameFr.split(' ').first).toList(),
        ['M1', 'M2', 'M3', 'M4', 'M5', 'M6', 'TGM']);
    expect(transtu.every((l) => l.reverseId != null), isTrue);
    expect(transtu.last.nameAr, startsWith('TGM '));
    // SNCFT lines unchanged alongside.
    expect(lines.where((l) => l.lineCategory == 'mainline'), isNotEmpty);
  });

  test('poster first/last departures (hiver 2026-2027)', () async {
    final repo = TripRepository(helper);
    final barcelone = await stopId('Place de Barcelone');
    final benArous = await stopId('Ben Arous');
    final out = await repo.searchTrips(barcelone, benArous);
    expect(out.first.departureTime, 3 * 60 + 52);
    expect(out.last.departureTime, 22 * 60 + 30);
    expect(out.first.trainNumber, 'M1');
    expect(isEstimatedTrip(out.first.tripCode), isTrue);

    final marsa = await stopId('La Marsa Plage');
    final marine = await stopId('Tunis Marine');
    final tgmIn = await repo.searchTrips(marsa, marine);
    final starts = tgmIn.map((t) => t.departureTime).toSet();
    expect(starts, containsAll([4 * 60 + 15, 30])); // 04:15 … 00:30
    expect(tgmIn.first.trainNumber, 'TGM');
  });

  test('TGM end-to-end fare, SNCFT search still works', () async {
    final repo = TripRepository(helper);
    final tgm = await repo.searchTrips(
      await stopId('Tunis Marine'),
      await stopId('La Marsa Plage'),
      afterMinutes: 8 * 60,
    );
    expect(tgm.first.approximatePrice, 0.8);
    final sncft = await repo.searchTrips(
      await stopId('Tunis'),
      await stopId('Hammam Lif'),
      afterMinutes: 17 * 60,
    );
    expect(sncft, isNotEmpty);
    expect(isEstimatedTrip(sncft.first.tripCode), isFalse);
  });

  test('picker lists served stops once; lookups keep every stop', () async {
    final repo = StationRepository(helper);
    final served = await repo.getServedStations();
    expect(served.where((s) => s.nameFr == 'La Goulette'), hasLength(1));
    final all = await repo.getAllStations();
    expect(all.where((s) => s.nameFr == 'La Goulette'), hasLength(2));
    final names = served.map((s) => s.nameFr).toList();
    expect(names.toSet().length, names.length);
    // The live board is hidden for TRANSTU stops only.
    expect(served.firstWhere((s) => s.nameFr == 'Tunis Marine').isTranstu, isTrue);
    expect(served.firstWhere((s) => s.nameFr == 'Tunis').isTranstu, isFalse);
  });
}
