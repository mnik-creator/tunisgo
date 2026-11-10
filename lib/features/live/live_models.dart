// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
//
// Models for `live.json` produced by the TunisGO Worker. Train fields keep the
// SNCFT wire names; stop rows use the Worker's compact keys. Parsing is
// defensive because the upstream feed is undocumented.

class LiveFeed {
  const LiveFeed({required this.generatedAt, required this.trains});

  factory LiveFeed.fromJson(Map<String, dynamic> json) => LiveFeed(
    generatedAt: DateTime.tryParse('${json['generatedAt'] ?? ''}')?.toUtc(),
    trains: (json['trains'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LiveTrain.fromJson)
        .toList(growable: false),
  );

  final DateTime? generatedAt;
  final List<LiveTrain> trains;

  bool isStale(Duration maxAge, {DateTime? now}) {
    final at = generatedAt;
    if (at == null) return true;
    return (now ?? DateTime.now().toUtc()).difference(at) > maxAge;
  }
}

class LiveTrain {
  const LiveTrain({
    required this.id,
    required this.number,
    required this.unit,
    required this.routeName,
    required this.routeNameAr,
    required this.status,
    required this.delayMinutes,
    required this.currentFr,
    required this.nextFr,
    required this.arrivalPlan,
    required this.arrivalActual,
    required this.arrivalForecast,
    required this.progress,
    required this.stops,
  });

  factory LiveTrain.fromJson(Map<String, dynamic> json) => LiveTrain(
    id: '${json['id'] ?? ''}',
    number: '${json['num'] ?? ''}'.trim(),
    unit: '${json['unite'] ?? ''}',
    routeName: '${json['name'] ?? ''}',
    routeNameAr: '${json['nameAr'] ?? ''}',
    status: '${json['status'] ?? ''}',
    delayMinutes: _asInt(json['delay']),
    currentFr: '${json['curFr'] ?? ''}',
    nextFr: '${json['nextFr'] ?? ''}',
    arrivalPlan: parseHhmm(json['arrivalPlan']),
    arrivalActual: parseHhmm(json['arrivalActual']),
    arrivalForecast: parseHhmm(json['arrivalForecast']),
    progress: _asInt(json['prog']).clamp(0, 100).toInt(),
    stops: (json['stops'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LiveStopTime.fromJson)
        .toList(growable: false),
  );

  /// Per-service id; changes daily, never persist it.
  final String id;

  /// As printed by SNCFT: `205`, `0005076`, `00TA014`, `5/912` — keep string.
  final String number;

  /// `GL` (Grandes Lignes) or `BL` (Banlieue).
  final String unit;
  final String routeName;
  final String routeNameAr;

  /// EN_ROUTE | NOT_STARTED | TERMINATED | CANCELLED
  final String status;
  final int delayMinutes;
  final String currentFr;
  final String nextFr;

  /// Arrival at the final destination.
  final String? arrivalPlan;
  final String? arrivalActual;
  final String? arrivalForecast;

  /// 0..100 along the whole route.
  final int progress;

  /// Ordered calls; empty until the Worker has fetched this train's details.
  final List<LiveStopTime> stops;

  bool get isRunning => status == 'EN_ROUTE';
  bool get isCancelled => status == 'CANCELLED';
  bool get isFinished => status == 'TERMINATED';
}

class LiveStopTime {
  const LiveStopTime({
    required this.name,
    required this.nameAr,
    required this.planArrival,
    required this.planDeparture,
    required this.actualArrival,
    required this.actualDeparture,
    required this.forecastArrival,
  });

  factory LiveStopTime.fromJson(Map<String, dynamic> json) => LiveStopTime(
    name: '${json['n'] ?? ''}',
    nameAr: '${json['a'] ?? ''}',
    planArrival: parseHhmm(json['pa']),
    planDeparture: parseHhmm(json['pd']),
    actualArrival: parseHhmm(json['aa']),
    actualDeparture: parseHhmm(json['ad']),
    forecastArrival: parseHhmm(json['fa']),
  );

  final String name;
  final String nameAr;
  final String? planArrival;
  final String? planDeparture;
  final String? actualArrival;
  final String? actualDeparture;
  final String? forecastArrival;

  /// Planned time for this call (departure preferred, arrival at the terminus).
  String? get scheduled => planDeparture ?? planArrival;

  /// The train has already left (or reached) this stop.
  bool get isPassed => actualDeparture != null || actualArrival != null;

  /// Actual > forecast > planned + train delay.
  String? bestTime(int trainDelayMinutes) =>
      actualDeparture ??
      actualArrival ??
      forecastArrival ??
      shiftHhmm(scheduled, trainDelayMinutes);
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

/// `H:MM`, `HH:MM` or timetable `HH:MM:SS` -> `HH:MM`; null for `--:--`,
/// empty, or out-of-range values. GTFS-style hours past 24 wrap.
String? parseHhmm(Object? value) {
  if (value == null) return null;
  final parts = '$value'.trim().split(':');
  if (parts.length != 2 && parts.length != 3) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 47 || m < 0 || m > 59) {
    return null;
  }
  return '${(h % 24).toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Minutes since midnight for `HH:MM`, or null.
int? minutesOfDay(String? hhmm) {
  final parsed = parseHhmm(hhmm);
  if (parsed == null) return null;
  return int.parse(parsed.substring(0, 2)) * 60 + int.parse(parsed.substring(3));
}

String? shiftHhmm(String? hhmm, int minutes) {
  final m = minutesOfDay(hhmm);
  if (m == null) return null;
  final total = (m + minutes) % (24 * 60);
  return '${(total ~/ 60).toString().padLeft(2, '0')}:'
      '${(total % 60).toString().padLeft(2, '0')}';
}

/// Signed minutes from [from] to [to] on a 24 h clock, wrapping at midnight
/// (feed times are wall-clock `HH:MM` with no date).
int clockDelta(int from, int to) {
  var d = to - from;
  if (d < -12 * 60) d += 24 * 60;
  if (d > 12 * 60) d -= 24 * 60;
  return d;
}

/// Current time in Tunisia (UTC+1 all year, no DST since 2009). Never trust
/// the device zone: a phone set to another zone would shift every departure.
int tunisNowMinutes([DateTime? nowUtc]) {
  final t = (nowUtc ?? DateTime.now().toUtc()).add(const Duration(hours: 1));
  return t.hour * 60 + t.minute;
}
