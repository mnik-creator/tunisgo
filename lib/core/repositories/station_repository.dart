// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import '../database/database_helper.dart';
import '../models/station.dart';

class StationRepository {
  const StationRepository(this._db);

  final DatabaseHelper _db;

  static const _selectCols = '''
    CAST(id AS TEXT) AS id,
    COALESCE(code, CAST(id AS TEXT)) AS slug,
    name AS nameFr,
    COALESCE(name_ar, '') AS nameAr,
    name AS nameEn,
    COALESCE(name_ru, '') AS nameRu,
    1 AS isActive
  ''';

  /// Returns all station IDs that should be considered equivalent to [stationId].
  Future<List<String>> getEquivalentStationIds(String stationId) async {
    return [stationId];
  }

  Future<List<Station>> getAllStations() async {
    final rows = await _db.rawQuery(
      'SELECT $_selectCols FROM stops ORDER BY name',
    );
    return rows.map(Station.fromMap).toList();
  }

  Future<List<Station>> getMajorStations() async {
    final rows = await _db.rawQuery(
      'SELECT $_selectCols FROM stops ORDER BY name LIMIT 30',
    );
    return rows.map(Station.fromMap).toList();
  }

  Future<List<Station>> searchByName(String query) async {
    // SQLite's COLLATE NOCASE only handles ASCII, so Cyrillic/Arabic
    // case-insensitive matching must be done in Dart.
    final queryLower = query.toLowerCase();
    final rows = await _db.rawQuery(
      'SELECT $_selectCols FROM stops ORDER BY name',
    );
    return rows
        .map(Station.fromMap)
        .where((s) =>
            s.nameFr.toLowerCase().contains(queryLower) ||
            s.nameAr.toLowerCase().contains(queryLower) ||
            s.nameRu.toLowerCase().contains(queryLower))
        .toList();
  }

  Future<List<Station>> getStationsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _db.rawQuery(
      'SELECT $_selectCols FROM stops ORDER BY name',
    );
    final byId = {for (final s in rows.map(Station.fromMap)) s.id: s};
    return ids.where(byId.containsKey).map((id) => byId[id]!).toList();
  }

  /// Returns all stations reachable from [fromStationId] (i.e. stations that
  /// appear after it in stop_sequence within the same trip). Optionally filters
  /// by [query] against FR/AR/RU names.
  Future<List<Station>> getReachableStations(
    String fromStationId, {
    String? query,
  }) async {
    // Use explicit s. prefix on every column to avoid ambiguity with
    // stop_times, which also has an `id` column.
    final rows = await _db.rawQuery(
      '''
      SELECT DISTINCT
        CAST(s.id AS TEXT)                     AS id,
        COALESCE(s.code, CAST(s.id AS TEXT))   AS slug,
        s.name                                 AS nameFr,
        COALESCE(s.name_ar, '')                AS nameAr,
        s.name                                 AS nameEn,
        COALESCE(s.name_ru, '')                AS nameRu,
        1                                      AS isActive
      FROM stops s
      JOIN stop_times st_to  ON st_to.stop_id = s.id
      JOIN stop_times st_from ON st_from.trip_id = st_to.trip_id
                             AND CAST(st_from.stop_id AS TEXT) = ?
                             AND st_from.stop_sequence < st_to.stop_sequence
      ORDER BY s.name
      ''',
      [fromStationId],
    );
    final stations = rows.map(Station.fromMap).toList();
    if (query == null || query.isEmpty) return stations;
    final q = query.toLowerCase();
    return stations
        .where((s) =>
            s.nameFr.toLowerCase().contains(q) ||
            s.nameAr.toLowerCase().contains(q) ||
            s.nameRu.toLowerCase().contains(q))
        .toList();
  }

}
