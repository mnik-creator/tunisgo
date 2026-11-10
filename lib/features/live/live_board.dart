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
