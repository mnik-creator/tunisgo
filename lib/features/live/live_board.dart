// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
//
// Pure functions that turn a [LiveFeed] into what the UI shows: a live board
// for one station, and a delay overlay for one offline timetable row.
import 'live_models.dart';
import 'station_aliases.dart';
import 'train_number.dart';

/// A live train's call at one station.
class LiveCall {
  const LiveCall({
    required this.train,
    required this.stop,
    required this.stopIndex,
    required this.eta,
    required this.delayMinutes,
  });

  final LiveTrain train;
  final LiveStopTime stop;
  final int stopIndex;

  /// Best known time at this station (actual > forecast > plan + delay).
  final String? eta;

  /// Delay at this station; 0 when unknown or on time.
  final int delayMinutes;

  String get terminus => train.stops.isEmpty ? '' : train.stops.last.name;
  bool get isCancelled => train.isCancelled;
  bool get isPassed => stop.isPassed;

  /// Delay is only meaningful once the train has started reporting.
  bool get hasLiveDelay => train.isRunning || stop.isPassed;
}

/// Does live stop [liveName] refer to the timetable stop [dbStationName]?
bool isSameStation(String liveName, String dbStationName) {
  final resolved = resolveStopName(liveName);
  if (resolved == null) return false; // technical point, no passengers
  return normalizeStationName(resolved) == normalizeStationName(dbStationName);
}

LiveCall? _callAt(LiveTrain train, String dbStationName) {
  for (var i = 0; i < train.stops.length; i++) {
    final stop = train.stops[i];
    if (!isSameStation(stop.name, dbStationName)) continue;
    final eta = stop.bestTime(train.delayMinutes);
    final planned = minutesOfDay(stop.scheduled);
    final best = minutesOfDay(eta);
    final delay = planned != null && best != null
        ? clockDelta(planned, best)
        : train.delayMinutes;
    return LiveCall(
      train: train,
      stop: stop,
      stopIndex: i,
      eta: eta,
      delayMinutes: delay > 0 ? delay : 0,
    );
  }
  return null;
}

/// Trains calling at [dbStationName] from [graceMinutes] ago up to
/// [withinMinutes] ahead, soonest first. Finished calls drop off after the
/// grace period; cancelled trains stay so riders see the cancellation.
List<LiveCall> buildStationBoard(
  LiveFeed feed,
  String dbStationName, {
  required int nowMinutes,
  int withinMinutes = 120,
  int graceMinutes = 5,
}) {
  final out = <(int, LiveCall)>[];
  for (final train in feed.trains) {
    if (train.isFinished) continue;
    final call = _callAt(train, dbStationName);
    if (call == null) continue;
    // Never list a train at its terminus as a departure.
    if (call.stopIndex == train.stops.length - 1) continue;
    final at = minutesOfDay(call.isCancelled ? call.stop.scheduled : call.eta);
    if (at == null) continue;
    final delta = clockDelta(nowMinutes, at);
    if (delta < -graceMinutes || delta > withinMinutes) continue;
    out.add((delta, call));
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final e in out) e.$2];
}

/// Live status for one offline timetable row at [dbStationName].
///
/// Matches on train number first, then requires the live train to call at
/// this station with a planned time within [toleranceMinutes] of the
/// timetable's — number keys collide across lines, so neither check is enough
/// alone. Returns null when nothing matches; the row then keeps its printed
/// time.
LiveCall? matchTimetableRow(
  Map<String, List<LiveTrain>> trainsByKey, {
  required String tripCode,
  required String dbStationName,
  required String plannedHhmm,
  int toleranceMinutes = 20,
}) {
  final candidates = trainsByKey[timetableTrainKey(tripCode)];
  final planned = minutesOfDay(plannedHhmm);
  if (candidates == null || planned == null) return null;

  LiveCall? best;
  var bestGap = toleranceMinutes + 1;
  for (final train in candidates) {
    final call = _callAt(train, dbStationName);
    final scheduled = minutesOfDay(call?.stop.scheduled);
    if (call == null || scheduled == null) continue;
    final gap = clockDelta(planned, scheduled).abs();
    if (gap < bestGap) {
      bestGap = gap;
      best = call;
    }
  }
  return best;
}

/// Index for [matchTimetableRow]; build once per feed generation.
Map<String, List<LiveTrain>> indexByTrainKey(LiveFeed feed) {
  final index = <String, List<LiveTrain>>{};
  for (final train in feed.trains) {
    if (train.stops.isEmpty) continue;
    (index[liveTrainKey(train.number)] ??= []).add(train);
  }
  return index;
}

/// Live call for an already-scheduled-past [tripCode] when the train is
/// running late and is still expected at [dbStationName] at or after
/// [refMinutes] (and within [maxAheadMinutes]). Null when the feed has no
/// evidence of a delay — a train that merely "may" be late is not shown.
LiveCall? lateDeparture(
  Map<String, List<LiveTrain>> trainsByKey, {
  required String tripCode,
  required String dbStationName,
  required String plannedHhmm,
  required int refMinutes,
  int maxAheadMinutes = 90,
}) {
  final call = matchTimetableRow(
    trainsByKey,
    tripCode: tripCode,
    dbStationName: dbStationName,
    plannedHhmm: plannedHhmm,
  );
  if (call == null || call.isCancelled || call.isPassed) return null;
  if (!call.train.isRunning || call.delayMinutes <= 0) return null;
  final eta = minutesOfDay(call.eta);
  if (eta == null) return null;
  final ahead = clockDelta(refMinutes, eta);
  return ahead >= 0 && ahead <= maxAheadMinutes ? call : null;
}

/// Where a train is along a timetable stop list, snapped to "at a stop" or
/// "halfway to the next one".
class TrainPosition {
  const TrainPosition({required this.lastPassed, required this.atStation});

  /// Index into the stop list of the last stop reached (all up to it are done).
  final int lastPassed;

  /// True: standing at [lastPassed]; false: between it and the next stop.
  final bool atStation;
}

/// Position of [train] along [dbStationNames] (the trip's stops in order) at
/// [nowMinutes]. Uses actual times where SNCFT reported them, otherwise
/// planned times shifted by the train's delay — the feed often stops
/// reporting actuals mid-run. Null when the train is not on its way.
TrainPosition? positionAlongStops(
  LiveTrain train,
  List<String> dbStationNames, {
  required int nowMinutes,
}) {
  if (dbStationNames.isEmpty || train.isCancelled) return null;
  final last = dbStationNames.length - 1;
  if (train.isFinished) return TrainPosition(lastPassed: last, atStation: true);
  if (!train.isRunning) return null;

  bool reached(String? actual, String? estimate) {
    if (actual != null) return true;
    final m = minutesOfDay(estimate);
    return m != null && clockDelta(nowMinutes, m) <= 0;
  }

  var lastPassed = -1;
  var atStation = false;
  for (var i = 0; i < dbStationNames.length; i++) {
    LiveStopTime? stop;
    for (final s in train.stops) {
      if (isSameStation(s.name, dbStationNames[i])) {
        stop = s;
        break;
      }
    }
    if (stop == null) continue; // not in the feed — judge by its neighbours
    final delay = train.delayMinutes;
    final departed = reached(
      stop.actualDeparture,
      shiftHhmm(stop.planDeparture ?? stop.planArrival, delay),
    );
    if (departed) {
      lastPassed = i;
      atStation = false;
      continue;
    }
    final arrived = reached(
      stop.actualArrival,
      stop.forecastArrival ?? shiftHhmm(stop.planArrival ?? stop.planDeparture, delay),
    );
    if (arrived) {
      lastPassed = i;
      atStation = true;
    }
    break;
  }
  if (lastPassed < 0) return null;
  return TrainPosition(lastPassed: lastPassed, atStation: atStation || lastPassed == last);
}

/// Position along a timetable stop list judged by the clock alone: for trains
/// the feed does not track or has not reported as departed yet. [arrivals]
/// and [departures] are minutes since midnight from the offline timetable (may
/// run past 24:00 for overnight trains); [delayMinutes] shifts them all. Null
/// before the first departure.
TrainPosition? positionBySchedule(
  List<int> arrivals,
  List<int> departures, {
  required int nowMinutes,
  int delayMinutes = 0,
}) {
  final n = departures.length;
  if (n == 0 || arrivals.length != n) return null;
  var now = nowMinutes;
  // Past midnight on a train that left yesterday evening.
  if (departures.last >= 24 * 60 && now + 12 * 60 < departures.first) now += 24 * 60;
  var lastPassed = -1;
  var atStation = false;
  for (var i = 0; i < n; i++) {
    final dep = departures[i] + delayMinutes;
    final arr = (i == 0 || arrivals[i] == 0 ? departures[i] : arrivals[i]) + delayMinutes;
    if (i < n - 1 && dep <= now) {
      lastPassed = i;
      atStation = false;
      continue;
    }
    if (i > 0 && arr <= now) {
      lastPassed = i;
      atStation = true;
    }
    break;
  }
  if (lastPassed < 0) return null;
  return TrainPosition(lastPassed: lastPassed, atStation: atStation);
}
