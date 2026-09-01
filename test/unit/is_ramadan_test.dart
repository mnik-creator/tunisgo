// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'package:flutter_test/flutter_test.dart';
import 'package:tunis_go/core/database/database_helper.dart';
import 'package:tunis_go/core/repositories/trip_repository.dart';

/// Fake DatabaseHelper that returns configurable rows without touching SQLite.
class _FakeDb extends DatabaseHelper {
  _FakeDb(this._rows) : super.forTesting();

  final List<Map<String, dynamic>> _rows;

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async =>
      _rows;
}

TripRepository _repoWith(List<Map<String, dynamic>> rows) =>
    TripRepository(_FakeDb(rows));

void main() {
  group('TripRepository.isRamadanActive', () {
    test('always returns false (sncft.db has no Ramadan-specific trips)', () async {
      final repo = _repoWith([
        {'cnt': 1},
      ]);
      expect(await repo.isRamadanActive(), isFalse);
    });

    test('returns false when DB reports count == 0', () async {
      final repo = _repoWith([
        {'cnt': 0},
      ]);
      expect(await repo.isRamadanActive(), isFalse);
    });

    test('returns false when cnt is null', () async {
      final repo = _repoWith([
        {'cnt': null},
      ]);
      expect(await repo.isRamadanActive(), isFalse);
    });
  });
}
