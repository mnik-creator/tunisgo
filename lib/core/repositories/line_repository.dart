// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import '../database/database_helper.dart';
import '../models/line.dart';
import '../models/line_station.dart';
import '../models/station.dart';

// SQL expression to derive a lineType from the route short_name.
// - Tunis suburban: 120S-160P/160P-120S (Erriadh), 120S-615E/615E-120S (Bougatfa),
//                  120S-615B/615B-120S (Gobaa), 120S-154H/154H-120S (Hammam Lif)
// - Sahel suburban: 231A-267S/267S-231A (Sousse-Mahdia),
//                   231A-MahZT/MahZT-231A (Sousse-Mahdia Zone Touristique),
//                   267S-238H/238H-267S (Mahdia-Monastir)
// - All others: mainline
const _lineTypeExpr = '''
  CASE
    WHEN r.short_name IN ('120S-160P', '160P-120S') THEN 'suburban_tunis'
    WHEN r.short_name IN ('120S-615E', '615E-120S') THEN 'suburban_tunis'
    WHEN r.short_name IN ('120S-615B', '615B-120S') THEN 'suburban_tunis'
    WHEN r.short_name IN ('120S-154H', '154H-120S') THEN 'suburban_tunis'
    WHEN r.short_name IN ('231A-267S', '267S-231A') THEN 'suburban_sahel'
    WHEN r.short_name IN ('231A-MahZT', 'MahZT-231A') THEN 'suburban_sahel'
    WHEN r.short_name IN ('267S-238H', '238H-267S') THEN 'suburban_sahel'
    ELSE 'mainline'
  END
''';

class LineRepository {
  const LineRepository(this._db);
  final DatabaseHelper _db;

  Future<List<Line>> getAllLines() async {
    final rows = await _db.rawQuery('''
      SELECT
        CAST(r.id AS TEXT)                              AS id,
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
          COALESCE(r.long_name, r.short_name),
          '_', ' '), '700', 'Annaba'), '007A', 'Annaba'),
          ' Voyageurs', ''), ' Voy', ''), ' Ville', ''),
          'Jendouba V', 'Jendouba'), 'Haammam', 'Hammam') AS nameFr,
        -- First stop localized names
        (SELECT COALESCE(s.name_ar, '')
         FROM stop_times st JOIN stops s ON s.id = st.stop_id
         JOIN trips t ON t.id = st.trip_id
         WHERE t.route_id = r.id ORDER BY st.stop_sequence ASC LIMIT 1)  AS startNameAr,
        (SELECT COALESCE(s.name_ru, '')
         FROM stop_times st JOIN stops s ON s.id = st.stop_id
         JOIN trips t ON t.id = st.trip_id
         WHERE t.route_id = r.id ORDER BY st.stop_sequence ASC LIMIT 1)  AS startNameRu,
        -- Last stop localized names
        (SELECT COALESCE(s.name_ar, '')
         FROM stop_times st JOIN stops s ON s.id = st.stop_id
         JOIN trips t ON t.id = st.trip_id
         WHERE t.route_id = r.id ORDER BY st.stop_sequence DESC LIMIT 1) AS endNameAr,
        (SELECT COALESCE(s.name_ru, '')
         FROM stop_times st JOIN stops s ON s.id = st.stop_id
         JOIN trips t ON t.id = st.trip_id
         WHERE t.route_id = r.id ORDER BY st.stop_sequence DESC LIMIT 1) AS endNameRu,
        CASE WHEN r.color IS NOT NULL
             THEN '#' || r.color
             ELSE '#000000' END                         AS color,
        $_lineTypeExpr                                  AS lineType,
        CAST(r_rev.id AS TEXT)                          AS reverseId
      FROM routes r
      LEFT JOIN routes r_rev ON (
        r_rev.short_name = SUBSTR(r.short_name, INSTR(r.short_name, '-') + 1)
                        || '-'
                        || SUBSTR(r.short_name, 1, INSTR(r.short_name, '-') - 1)
        AND EXISTS (SELECT 1 FROM trips t WHERE t.route_id = r_rev.id)
      )
      WHERE EXISTS (
        SELECT 1 FROM trips t
        WHERE t.route_id = r.id
      )
      AND (
        r_rev.id IS NULL
        OR (r.short_name LIKE '120S-%' AND r_rev.short_name NOT LIKE '120S-%')
        OR (r.short_name NOT LIKE '120S-%' AND r_rev.short_name NOT LIKE '120S-%' AND r.id < r_rev.id)
      )
      ORDER BY lineType, nameFr
      ''');
    return rows.map(Line.fromMap).toList();
  }

  Future<List<({LineStation lineStation, Station station})>> getStationsForLine(
    String lineId, {
    int direction = 0,
  }) async {
    final orderDir = direction == 0 ? 'ASC' : 'DESC';
    final rows = await _db.rawQuery(
      '''
      WITH ref_trip AS (
        SELECT t.id
        FROM trips t
        JOIN stop_times st ON st.trip_id = t.id
        WHERE t.route_id = CAST(? AS INTEGER)
        GROUP BY t.id
        ORDER BY COUNT(st.id) DESC
        LIMIT 1
      )
      SELECT
        CAST(s.id AS TEXT)                   AS stationId,
        CAST(r.id AS TEXT)                   AS lineId,
        COALESCE(s.code, CAST(s.id AS TEXT)) AS slug,
        CASE WHEN s.name = 'Gobaa Ville'
             THEN s.name
             ELSE REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    s.name, ' Voyageurs', ''), ' Voy', ''), ' Ville', ''),
                    'Jendouba V', 'Jendouba'), 'Haammam', 'Hammam')
        END AS nameFr,
        COALESCE(s.name_ar, '')              AS nameAr,
        CASE WHEN s.name = 'Gobaa Ville'
             THEN s.name
             ELSE REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    s.name, ' Voyageurs', ''), ' Voy', ''), ' Ville', ''),
                    'Jendouba V', 'Jendouba'), 'Haammam', 'Hammam')
        END AS nameEn,
        COALESCE(s.name_ru, '')              AS nameRu,
        1                                    AS isActive,
        st.stop_sequence                     AS stopNumber
      FROM stops s
      JOIN stop_times st ON st.stop_id = s.id
      JOIN trips t       ON t.id = st.trip_id
      JOIN routes r      ON r.id = t.route_id
      WHERE t.id = (SELECT id FROM ref_trip)
      ORDER BY st.stop_sequence $orderDir
      ''',
      [lineId],
    );
    return rows.map((row) {
      final ls = LineStation(
        id: row['stationId'] as String,
        lineId: row['lineId'] as String,
        stationId: row['stationId'] as String,
        order: row['stopNumber'] as int,
      );
      final station = Station.fromMap({
        'id': row['stationId'],
        'slug': row['slug'],
        'nameFr': row['nameFr'],
        'nameAr': row['nameAr'],
        'nameEn': row['nameEn'],
        'nameRu': row['nameRu'],
        'isActive': 1,
      });
      return (lineStation: ls, station: station);
    }).toList();
  }
}
