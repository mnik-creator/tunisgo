// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import '../database/database_helper.dart';
import '../helpers/time_helpers.dart';
import '../models/stop_time.dart';
import '../models/trip.dart';
import 'station_repository.dart';

// Derives a lineType string from the trips.trip_id TEXT prefix.
const _lineTypeExpr = '''
  CASE
    WHEN t.trip_id LIKE 'mainlines_%' THEN 'mainline'
    WHEN t.trip_id LIKE 'banlieue_sahel%' THEN 'suburban_sahel'
    WHEN t.trip_id LIKE 'banlieue_tunis%' THEN 'suburban_tunis'
    WHEN t.trip_id LIKE 'tgm%' THEN 'tgm'
    WHEN t.trip_id LIKE 'metro%' THEN 'metro'
    WHEN t.trip_id LIKE 'banlieue%' THEN 'suburban_sahel'
    WHEN t.trip_id LIKE 'ligne%' THEN 'mainline'
    ELSE 'suburban_sahel'
  END
''';

class TripRepository {
  const TripRepository(this._db, {StationRepository? stationRepo})
    : _stationRepo = stationRepo;

  final DatabaseHelper _db;
  final StationRepository? _stationRepo;

  static final _stopDaysSupport = Expando<Future<bool>>();

  /// `stop_times.stop_days` exists from DB 2.3.1 on; an older downloaded copy
  /// lacks it, so queries select NULL instead.
  Future<bool> _hasStopDays() => _stopDaysSupport[_db] ??= () async {
        try {
          final rows = await _db.rawQuery(
            "SELECT COUNT(*) AS n FROM pragma_table_info('stop_times') "
            "WHERE name = 'stop_days'",
          );
          return rows.isNotEmpty && rows.first['n'] == 1;
        } catch (_) {
          return false;
        }
      }();

  Future<String> _stopDays(String alias, String as) async =>
      await _hasStopDays() ? '$alias.stop_days AS $as' : 'NULL AS $as';

  Future<List<Trip>> getTripsForLine(String lineId, {int? direction}) async {
    // direction_id is NULL for all trips in sncft.db — ignored here.
    final rows = await _db.rawQuery(
      '''
      SELECT
        CAST(t.id AS TEXT)        AS id,
        CAST(t.route_id AS TEXT)  AS lineId,
        t.trip_id                 AS tripCode,
        t.service_id              AS serviceType,
        $_lineTypeExpr            AS lineType,
        st_first.departure_time   AS fromDepartureTime,
        st_last.arrival_time      AS toArrivalTime
      FROM trips t
      JOIN stop_times st_first ON st_first.trip_id = t.id
                               AND st_first.stop_sequence = (
                                 SELECT MIN(s2.stop_sequence) FROM stop_times s2
                                 WHERE s2.trip_id = t.id
                               )
      JOIN stop_times st_last  ON st_last.trip_id = t.id
                               AND st_last.stop_sequence = (
                                 SELECT MAX(s3.stop_sequence) FROM stop_times s3
                                 WHERE s3.trip_id = t.id
                               )
      WHERE t.route_id = CAST(? AS INTEGER)
      ORDER BY st_first.departure_time
      ''',
      [lineId],
    );
    return rows.map(Trip.fromMap).toList();
  }

  /// Every trip that runs from [fromStationId] to [toStationId] (in that
  /// order), whatever route it is filed under, plus the trips of [lineId].
  ///
  /// Trips are filed under the route named after their own terminus, so the
  /// "Tunis – Sousse" route alone holds only the trains that end in Sousse;
  /// this also brings in the Tunis → Sfax/Gabès trains calling at Sousse.
  /// Ordered by departure from [fromStationId].
  Future<List<Trip>> getTripsServingLine(
    String lineId,
    String fromStationId,
    String toStationId,
  ) async {
    final rows = await _db.rawQuery(
      '''
      SELECT
        CAST(t.id AS TEXT)        AS id,
        CAST(t.route_id AS TEXT)  AS lineId,
        t.trip_id                 AS tripCode,
        t.service_id              AS serviceType,
        $_lineTypeExpr            AS lineType,
        a.departure_time          AS fromDepartureTime,
        b.arrival_time            AS toArrivalTime
      FROM trips t
      JOIN stop_times a ON a.trip_id = t.id AND a.stop_id = CAST(? AS INTEGER)
      JOIN stop_times b ON b.trip_id = t.id AND b.stop_id = CAST(? AS INTEGER)
                       AND b.stop_sequence > a.stop_sequence
      UNION
      SELECT
        CAST(t.id AS TEXT), CAST(t.route_id AS TEXT), t.trip_id, t.service_id,
        $_lineTypeExpr,
        (SELECT s.departure_time FROM stop_times s WHERE s.trip_id = t.id
          ORDER BY s.stop_sequence LIMIT 1),
        (SELECT s.arrival_time FROM stop_times s WHERE s.trip_id = t.id
          ORDER BY s.stop_sequence DESC LIMIT 1)
      FROM trips t
      WHERE t.route_id = CAST(? AS INTEGER)
      ORDER BY fromDepartureTime
      ''',
      [fromStationId, toStationId, lineId],
    );
    // A route trip that also matched the first query appears twice when its
    // first stop differs from fromStationId; keep the first row per trip.
    final seen = <String>{};
    return [
      for (final r in rows)
        if (seen.add('${r['id']}')) Trip.fromMap(r),
    ];
  }

  /// Returns trips where [fromStationId] appears before [toStationId] in
  /// stop order. If [afterMinutes] is provided, filters to trips departing
  /// at or after that time (minutes since midnight).
  Future<List<Trip>> searchTrips(
    String fromStationId,
    String toStationId, {
    int? afterMinutes,
    int? arrivalBeforeMinutes,
  }) async {
    final fromIds = _stationRepo != null
        ? await _stationRepo.getEquivalentStationIds(fromStationId)
        : [fromStationId];
    final toIds = _stationRepo != null
        ? await _stationRepo.getEquivalentStationIds(toStationId)
        : [toStationId];

    final fromPlaceholders = List.filled(fromIds.length, '?').join(',');
    final toPlaceholders = List.filled(toIds.length, '?').join(',');

    final args = <dynamic>[...fromIds, ...toIds];
    String timeFilter = '';
    if (afterMinutes != null) {
      timeFilter = 'AND st_from.departure_time >= ?';
      args.add(minutesToHHMM(afterMinutes));
    } else if (arrivalBeforeMinutes != null) {
      timeFilter = 'AND st_to.arrival_time <= ?';
      args.add(minutesToHHMM(arrivalBeforeMinutes));
    }

    final orderBy = arrivalBeforeMinutes != null
        ? 'st_to.arrival_time DESC'
        : 'st_from.departure_time';

    final rows = await _db.rawQuery('''
      SELECT
        CAST(t.id AS TEXT)        AS id,
        CAST(t.route_id AS TEXT)  AS lineId,
        t.trip_id                 AS tripCode,
        t.service_id              AS serviceType,
        $_lineTypeExpr            AS lineType,
        st_from.departure_time    AS fromDepartureTime,
        (SELECT s.name FROM stops s WHERE s.id = st_from.stop_id) AS fromStationName,
        st_to.arrival_time        AS toArrivalTime,
        ${await _stopDays('st_from', 'fromStopDays')},
        ${await _stopDays('st_to', 'toStopDays')},
        (
          SELECT f.price FROM fares f
          WHERE f.fare_id = (
            SELECT fr.fare_id FROM fare_rules fr
            WHERE fr.origin_id = (SELECT s.code FROM stops s WHERE s.id = st_from.stop_id LIMIT 1)
              AND fr.destination_id = (SELECT s2.code FROM stops s2 WHERE s2.id = st_to.stop_id LIMIT 1)
            LIMIT 1
          )
          LIMIT 1
        ) AS price
      FROM trips t
      JOIN stop_times st_from ON st_from.trip_id = t.id
                              AND CAST(st_from.stop_id AS TEXT) IN ($fromPlaceholders)
      JOIN stop_times st_to   ON st_to.trip_id = t.id
                              AND CAST(st_to.stop_id AS TEXT) IN ($toPlaceholders)
      WHERE st_from.stop_sequence < st_to.stop_sequence
        $timeFilter
      ORDER BY $orderBy
      ''', args);
    return rows.map(Trip.fromMap).toList();
  }

  Future<List<StopTime>> getStopTimesForTrip(String tripId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT
        CAST(st.id AS TEXT)      AS id,
        CAST(st.trip_id AS TEXT) AS tripId,
        CAST(st.stop_id AS TEXT) AS stationId,
        st.arrival_time          AS arrivalTime,
        st.departure_time        AS departureTime,
        st.stop_sequence         AS stopNumber,
        ${await _stopDays('st', 'stopDays')}
      FROM stop_times st
      WHERE st.trip_id = ?
      ORDER BY st.stop_sequence
      ''',
      [tripId],
    );
    return rows.map(StopTime.fromMap).toList();
  }

  /// Returns all departures from [stationId] ordered by departure time.
  Future<List<Map<String, dynamic>>> getDeparturesForStation(
    String stationId,
  ) async {
    return _db.rawQuery(
      '''
      SELECT
        CAST(t.id AS TEXT)       AS trip_id,
        CAST(t.route_id AS TEXT) AS lineId,
        t.trip_id                AS train_number,
        t.service_id             AS service_id,
        st.departure_time        AS departure_time,
        ${await _stopDays('st', 'stop_days')}
      FROM stop_times st
      JOIN trips t ON t.id = st.trip_id
      WHERE CAST(st.stop_id AS TEXT) = ?
      ORDER BY st.departure_time
      ''',
      [stationId],
    );
  }

  /// Trips departing in the [windowMinutes] before [beforeMinutes], most
  /// recent first. Candidates for a late train that has not left yet; the
  /// live feed decides which (if any) is actually shown.
  Future<List<Trip>> getRecentTrains(
    String fromStationId,
    String toStationId,
    int beforeMinutes, {
    int windowMinutes = 90,
  }) async {
    final fromIds = _stationRepo != null
        ? await _stationRepo.getEquivalentStationIds(fromStationId)
        : [fromStationId];
    final toIds = _stationRepo != null
        ? await _stationRepo.getEquivalentStationIds(toStationId)
        : [toStationId];

    final fromPlaceholders = List.filled(fromIds.length, '?').join(',');
    final toPlaceholders = List.filled(toIds.length, '?').join(',');

    final since = beforeMinutes - windowMinutes;
    final args = <dynamic>[
      ...fromIds,
      ...toIds,
      minutesToHHMM(beforeMinutes),
      minutesToHHMM(since < 0 ? 0 : since),
    ];

    final rows = await _db.rawQuery('''
      SELECT
        CAST(t.id AS TEXT)        AS id,
        CAST(t.route_id AS TEXT)  AS lineId,
        t.trip_id                 AS tripCode,
        t.service_id              AS serviceType,
        $_lineTypeExpr            AS lineType,
        st_from.departure_time    AS fromDepartureTime,
        (SELECT s.name FROM stops s WHERE s.id = st_from.stop_id) AS fromStationName,
        st_to.arrival_time        AS toArrivalTime,
        ${await _stopDays('st_from', 'fromStopDays')},
        ${await _stopDays('st_to', 'toStopDays')},
        (
          SELECT f.price FROM fares f
          WHERE f.fare_id = (
            SELECT fr.fare_id FROM fare_rules fr
            WHERE fr.origin_id = (SELECT s.code FROM stops s WHERE s.id = st_from.stop_id LIMIT 1)
              AND fr.destination_id = (SELECT s2.code FROM stops s2 WHERE s2.id = st_to.stop_id LIMIT 1)
            LIMIT 1
          )
          LIMIT 1
        ) AS price
      FROM trips t
      JOIN stop_times st_from ON st_from.trip_id = t.id
                              AND CAST(st_from.stop_id AS TEXT) IN ($fromPlaceholders)
      JOIN stop_times st_to   ON st_to.trip_id = t.id
                              AND CAST(st_to.stop_id AS TEXT) IN ($toPlaceholders)
      WHERE st_from.stop_sequence < st_to.stop_sequence
        AND st_from.departure_time < ?
        AND st_from.departure_time >= ?
      ORDER BY st_from.departure_time DESC
      ''', args);
    return rows.map(Trip.fromMap).toList();
  }

  /// One trip by its `trips.id`, timed at its first stop; null if unknown.
  Future<Trip?> getTripById(String id) async {
    final rows = await _db.rawQuery(
      '''
      SELECT
        CAST(t.id AS TEXT)        AS id,
        CAST(t.route_id AS TEXT)  AS lineId,
        t.trip_id                 AS tripCode,
        t.service_id              AS serviceType,
        $_lineTypeExpr            AS lineType,
        st_first.departure_time   AS fromDepartureTime,
        st_last.arrival_time      AS toArrivalTime
      FROM trips t
      JOIN stop_times st_first ON st_first.trip_id = t.id
                               AND st_first.stop_sequence = (
                                 SELECT MIN(s2.stop_sequence) FROM stop_times s2
                                 WHERE s2.trip_id = t.id
                               )
      JOIN stop_times st_last  ON st_last.trip_id = t.id
                               AND st_last.stop_sequence = (
                                 SELECT MAX(s3.stop_sequence) FROM stop_times s3
                                 WHERE s3.trip_id = t.id
                               )
      WHERE t.id = CAST(? AS INTEGER)
      ''',
      [id],
    );
    return rows.isEmpty ? null : Trip.fromMap(rows.first);
  }

  /// Returns true if at least one trip connects [fromStationId] → [toStationId]
  /// in the correct stop order, regardless of time or service day.
  Future<bool> hasAnyConnection(
    String fromStationId,
    String toStationId,
  ) async {
    final fromIds = _stationRepo != null
        ? await _stationRepo.getEquivalentStationIds(fromStationId)
        : [fromStationId];
    final toIds = _stationRepo != null
        ? await _stationRepo.getEquivalentStationIds(toStationId)
        : [toStationId];

    final fromPlaceholders = List.filled(fromIds.length, '?').join(',');
    final toPlaceholders = List.filled(toIds.length, '?').join(',');

    final rows = await _db.rawQuery('''
      SELECT 1 FROM trips t
      JOIN stop_times st_from ON st_from.trip_id = t.id
                              AND CAST(st_from.stop_id AS TEXT) IN ($fromPlaceholders)
      JOIN stop_times st_to   ON st_to.trip_id = t.id
                              AND CAST(st_to.stop_id AS TEXT) IN ($toPlaceholders)
      WHERE st_from.stop_sequence < st_to.stop_sequence
      LIMIT 1
      ''', [...fromIds, ...toIds]);
    return rows.isNotEmpty;
  }

  /// Always returns false — sncft.db has no Ramadan-specific trips.
  Future<bool> isRamadanActive() async => false;
}
