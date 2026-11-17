// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'package:flutter_test/flutter_test.dart';
import 'package:tunis_go/features/live/live_board.dart';
import 'package:tunis_go/features/live/live_models.dart';
import 'package:tunis_go/features/live/station_aliases.dart';
import 'package:tunis_go/features/live/train_number.dart';

Map<String, dynamic> _train(
  String id,
  String num, {
  String status = 'EN_ROUTE',
  int delay = 0,
  List<Map<String, dynamic>> stops = const [],
}) => {
  'id': id,
  'num': num,
  'unite': 'BL',
  'name': 'TUNIS - ERRIADH',
  'status': status,
  'delay': delay,
  'stops': stops,
};

LiveFeed _feed(List<Map<String, dynamic>> trains) => LiveFeed.fromJson({
  'v': 1,
  'generatedAt': '2026-11-10T07:00:00Z',
  'trains': trains,
});

void main() {
  group('parsing', () {
    test('reads Worker schema with compact stops', () {
      final feed = _feed([
        _train('1', '0005076', delay: 12, stops: [
          {'n': 'Tunis Ville', 'pd': '06:00', 'ad': '06:04'},
          {'n': 'Sousse', 'pa': '08:10', 'pd': '08:15', 'fa': '08:22'},
          {'n': 'Gabes', 'pa': '12:00'},
        ]),
      ]);
      final t = feed.trains.single;
      expect(t.number, '0005076');
      expect(t.stops, hasLength(3));
      expect(t.stops[0].isPassed, isTrue);
      expect(t.stops[1].bestTime(t.delayMinutes), '08:22');
      expect(t.stops[2].bestTime(t.delayMinutes), '12:12');
      expect(t.stops[2].scheduled, '12:00');
    });

    test('survives garbage', () {
      final t = LiveTrain.fromJson({'id': 42, 'num': null, 'delay': '7', 'prog': '120', 'arrivalPlan': '--:--'});
      expect(t.id, '42');
      expect(t.number, '');
      expect(t.delayMinutes, 7);
      expect(t.progress, 100);
      expect(t.arrivalPlan, isNull);
      expect(t.stops, isEmpty);
    });

    test('staleness uses generatedAt', () {
      final feed = _feed([]);
      final at = DateTime.utc(2026, 11, 10, 7);
      expect(feed.isStale(const Duration(minutes: 5), now: at.add(const Duration(minutes: 4))), isFalse);
      expect(feed.isStale(const Duration(minutes: 5), now: at.add(const Duration(minutes: 6))), isTrue);
      expect(LiveFeed.fromJson({}).isStale(const Duration(minutes: 5)), isTrue);
    });

    test('quiet-night file stays fresh until its announced next poll', () {
      final feed = LiveFeed.fromJson({
        'generatedAt': '2026-11-12T00:00:00Z',
        'nextAt': '2026-11-12T00:15:00Z',
      });
      final at = DateTime.utc(2026, 11, 12);
      const max = Duration(minutes: 5);
      expect(feed.isStale(max, now: at.add(const Duration(minutes: 14))), isFalse);
      expect(feed.isStale(max, now: at.add(const Duration(minutes: 18))), isFalse);
      expect(feed.isStale(max, now: at.add(const Duration(minutes: 20))), isTrue);
    });
  });

  group('clock', () {
    test('accepts timetable HH:MM:SS', () {
      expect(parseHhmm('07:05:00'), '07:05');
      expect(parseHhmm('24:10:00'), '00:10');
    });

    test('wraps at midnight', () {
      expect(clockDelta(23 * 60 + 50, 10), 20);
      expect(clockDelta(10, 23 * 60 + 50), -20);
    });

    test('Tunis time ignores device zone', () {
      expect(tunisNowMinutes(DateTime.utc(2026, 7, 1, 23, 30)), 30);
    });
  });

  group('train number keys', () {
    test('AA TA CCC codes (Bizerte line)', () {
      expect(liveTrainKey('01TA004'), '1-4');
      expect(liveTrainKey('01TA004'), timetableTrainKey('mainlines_1/4'));
      expect(liveTrainKey('00TA014'), '14');
    });

    test('live and timetable formats meet', () {
      expect(liveTrainKey('205'), timetableTrainKey('ligne_a_tunis_erriadh_205'));
      expect(liveTrainKey('0005076'), timetableTrainKey('mainlines_5/76'));
      expect(liveTrainKey('1305072'), timetableTrainKey('mainlines_13‑5/72'));
      expect(liveTrainKey('0512079'), timetableTrainKey('mainlines_5-12/79'));
      expect(liveTrainKey('00TA014'), timetableTrainKey('ligne_r_x_14'));
      expect(liveTrainKey('00TM2'), timetableTrainKey('ligne_r_ghardimaou_tunis_TM2'));
      expect(liveTrainKey('TA01025'), timetableTrainKey('mainlines_1/25'));
      expect(liveTrainKey('00TA507'), '507');
    });

    test('different trains differ', () {
      expect(liveTrainKey('0005076'), isNot(timetableTrainKey('mainlines_5/73')));
    });
  });

  group('aliases', () {
    test('feed spellings resolve to DB names', () {
      expect(resolveStopName('Jebel Jelloud'), 'Jebel Jelloud');
      expect(resolveStopName('SOUSSE BAB JEDID'), 'Sousse Bab Jdid');
      expect(resolveStopName('SOUSSE'), 'Sousse');
      expect(isSameStation('TUNIS VILLE', 'Tunis'), isTrue);
    });

    test('technical points are dropped, unknown names pass through', () {
      expect(resolveStopName('Aig-SS-L22'), isNull);
      expect(resolveStopName("M'Razga"), "M'Razga");
    });
  });

  group('timetable overlay', () {
    final feed = _feed([
      _train('a', '205', delay: 6, stops: [
        {'n': 'Tunis Ville', 'pd': '07:00', 'ad': '07:06'},
        {'n': 'Jebel Jelloud', 'pd': '07:05', 'fa': '07:11'},
        {'n': 'Erriadh', 'pa': '07:40'},
      ]),
      // Same key, other line (Bir Aniba shuttle vs Sahel 507).
      _train('b', '00TA507', stops: [
        {'n': 'Tunis Ville', 'pd': '09:00'},
        {'n': 'Bir Aniba', 'pa': '09:30'},
      ]),
      _train('c', '0608069', status: 'CANCELLED', stops: [
        {'n': 'Tunis Ville', 'pd': '10:00'},
        {'n': 'Le Kef', 'pa': '13:00'},
      ]),
    ]);
    final index = indexByTrainKey(feed);

    test('matches by number, station and time', () {
      final call = matchTimetableRow(index,
          tripCode: 'ligne_a_tunis_erriadh_205',
          dbStationName: 'Jebel Jelloud',
          plannedHhmm: '07:05');
      expect(call, isNotNull);
      expect(call!.delayMinutes, 6);
      expect(call.eta, '07:11');
      expect(call.hasLiveDelay, isTrue);
    });

    test('rejects a same-number train on another line', () {
      expect(
        matchTimetableRow(index,
            tripCode: 'banlieue_sahel_507',
            dbStationName: 'Sousse Bab Jdid',
            plannedHhmm: '09:00'),
        isNull,
      );
    });

    test('rejects a match too far in time', () {
      expect(
        matchTimetableRow(index,
            tripCode: 'ligne_a_tunis_erriadh_205',
            dbStationName: 'Jebel Jelloud',
            plannedHhmm: '18:05'),
        isNull,
      );
    });

    test('reports cancellations', () {
      final call = matchTimetableRow(index,
          tripCode: 'mainlines_6-8/69',
          dbStationName: 'Tunis',
          plannedHhmm: '10:00');
      expect(call?.isCancelled, isTrue);
    });
  });

  group('station board', () {
    final feed = _feed([
      _train('late', '210', delay: 8, stops: [
        {'n': 'Tunis Ville', 'pd': '07:20', 'fa': '07:28'},
        {'n': 'Erriadh', 'pa': '08:00'},
      ]),
      _train('soon', '212', stops: [
        {'n': 'Tunis Ville', 'pd': '07:10'},
        {'n': 'Erriadh', 'pa': '07:50'},
      ]),
      _train('arriving', '211', stops: [
        {'n': 'Erriadh', 'pd': '06:30'},
        {'n': 'Tunis Ville', 'pa': '07:15'},
      ]),
      _train('gone', '208', status: 'TERMINATED', stops: [
        {'n': 'Tunis Ville', 'pd': '07:05'},
        {'n': 'Erriadh', 'pa': '07:45'},
      ]),
      _train('far', '230', stops: [
        {'n': 'Tunis Ville', 'pd': '11:00'},
        {'n': 'Erriadh', 'pa': '11:40'},
      ]),
    ]);

    test('lists departures soonest first, skips terminus and finished trains', () {
      final rows = buildStationBoard(feed, 'Tunis', nowMinutes: 7 * 60);
      expect(rows.map((r) => r.train.id), ['soon', 'late']);
      expect(rows.last.delayMinutes, 8);
      expect(rows.last.terminus, 'Erriadh');
    });
  });

  group('late previous train', () {
    final stops = [
      {'n': 'Tunis Ville', 'pd': '11:00'},
      {'n': 'Ez-Zahra', 'pa': '11:29'},
    ];
    LiveCall? late(Map<String, dynamic> train, {int ref = 11 * 60 + 8}) =>
        lateDeparture(
          indexByTrainKey(_feed([train])),
          tripCode: 'ligne_a_tunis_erriadh_159',
          dbStationName: 'Tunis',
          plannedHhmm: '11:00',
          refMinutes: ref,
        );

    test('shown when running late and still to come', () {
      final call = late(_train('1', '159', delay: 12, stops: stops));
      expect(call?.delayMinutes, 12);
      expect(call?.eta, '11:12');
    });

    test('hidden when the delay is already over by the search time', () {
      expect(late(_train('1', '159', delay: 5, stops: stops)), isNull);
    });

    test('hidden without live evidence of a delay', () {
      expect(late(_train('1', '159', stops: stops)), isNull);
      expect(late(_train('1', '159', status: 'NOT_STARTED', delay: 12, stops: stops)), isNull);
    });

    test('hidden once departed or cancelled', () {
      expect(
        late(_train('1', '159', delay: 12, stops: [
          {'n': 'Tunis Ville', 'pd': '11:00', 'ad': '11:12'},
          {'n': 'Ez-Zahra', 'pa': '11:29'},
        ])),
        isNull,
      );
      expect(late(_train('1', '159', status: 'CANCELLED', delay: 12, stops: stops)), isNull);
    });
  });

  group('train position', () {
    const names = ['Tunis', 'Rades', 'Ez-Zahra', 'Erriadh'];
    LiveTrain train({String status = 'EN_ROUTE', int delay = 0, List<Map<String, dynamic>>? stops}) =>
        _feed([
          _train('1', '159', status: status, delay: delay, stops: stops ??
              [
                {'n': 'Tunis Ville', 'pd': '11:00', 'ad': '11:02'},
                {'n': 'Rades', 'pa': '11:10', 'pd': '11:11'},
                {'n': 'Ez-Zahra', 'pa': '11:20', 'pd': '11:21'},
                {'n': 'Erriadh', 'pa': '11:30'},
              ]),
        ]).trains.single;
    TrainPosition? at(LiveTrain t, String hhmm) =>
        positionAlongStops(t, names, nowMinutes: minutesOfDay(hhmm)!);

    test('between stops after departing, estimated from plan', () {
      final p = at(train(), '11:05');
      expect(p?.lastPassed, 0);
      expect(p?.atStation, isFalse);
    });

    test('at a stop between its arrival and departure', () {
      final p = at(train(), '11:10');
      expect(p?.lastPassed, 1);
      expect(p?.atStation, isTrue);
    });

    test('delay shifts the estimate', () {
      final p = at(train(delay: 10), '11:15');
      expect(p?.lastPassed, 0);
      expect(p?.atStation, isFalse);
    });

    test('at the terminus or when finished', () {
      expect(at(train(), '11:40')?.atStation, isTrue);
      expect(at(train(), '11:40')?.lastPassed, 3);
      expect(at(train(status: 'TERMINATED'), '09:00')?.lastPassed, 3);
    });

    test('none when not started or cancelled', () {
      expect(at(train(status: 'NOT_STARTED'), '11:05'), isNull);
      expect(at(train(status: 'CANCELLED'), '11:05'), isNull);
    });
  });

  group('big delays', () {
    test('a 67-minute delay still matches: tolerance compares planned times', () {
      final index = indexByTrainKey(_feed([
        _train('g', '205', delay: 67, stops: [
          {'n': 'Tunis Ville', 'pd': '21:15', 'ad': '22:22'},
          {'n': 'Jebel Jelloud', 'pd': '21:22'},
          {'n': 'Erriadh', 'pa': '22:00'},
        ]),
      ]));
      final call = matchTimetableRow(index,
          tripCode: 'ligne_a_tunis_erriadh_205',
          dbStationName: 'Jebel Jelloud',
          plannedHhmm: '21:22');
      expect(call, isNotNull);
      expect(call!.delayMinutes, 67);
      expect(call.eta, '22:29');
    });
  });

  group('position by schedule', () {
    // Tunis 07:15 → Jebel Jelloud 07:26 → Megrine Riadh 07:28/07:29 → Megrine 07:30
    const arr = [0, 7 * 60 + 26, 7 * 60 + 28, 7 * 60 + 30];
    const dep = [7 * 60 + 15, 7 * 60 + 26, 7 * 60 + 29, 7 * 60 + 30];

    test('nothing before the first departure', () {
      expect(positionBySchedule(arr, dep, nowMinutes: 7 * 60 + 10), isNull);
    });

    test('between stops', () {
      final p = positionBySchedule(arr, dep, nowMinutes: 7 * 60 + 27);
      expect(p?.lastPassed, 1);
      expect(p?.atStation, isFalse);
    });

    test('dwelling at a stop', () {
      final p = positionBySchedule(arr, dep, nowMinutes: 7 * 60 + 28);
      expect(p?.lastPassed, 2);
      expect(p?.atStation, isTrue);
    });

    test('at the terminus afterwards', () {
      final p = positionBySchedule(arr, dep, nowMinutes: 9 * 60);
      expect(p?.lastPassed, 3);
      expect(p?.atStation, isTrue);
    });

    test('delay shifts it back', () {
      final p = positionBySchedule(arr, dep, nowMinutes: 7 * 60 + 27, delayMinutes: 10);
      expect(p?.lastPassed, 0);
      expect(p?.atStation, isFalse);
    });

    test('overnight train after midnight', () {
      const a = [0, 24 * 60 + 30];
      const d = [23 * 60 + 50, 24 * 60 + 30];
      final p = positionBySchedule(a, d, nowMinutes: 10);
      expect(p?.lastPassed, 0);
      expect(p?.atStation, isFalse);
    });
  });
}
