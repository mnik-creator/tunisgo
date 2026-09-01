// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import '../helpers/time_helpers.dart';

/// Times are stored as TEXT "HH:MM" in the DB and parsed to minutes since midnight.
class StopTime {
  const StopTime({
    required this.id,
    required this.tripId,
    required this.stationId,
    required this.arrivalTime,
    required this.departureTime,
    required this.stopNumber,
  });

  factory StopTime.fromMap(Map<String, dynamic> map) {
    int parseTime(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val; // already minutes since midnight
      final s = val.toString().trim();
      if (s.isEmpty) return 0;
      if (s.contains(':')) return hhmmToMinutes(s);
      return int.tryParse(s) ?? 0; // integer stored as text
    }

    return StopTime(
      id: map['id'] as String,
      tripId: map['tripId'] as String,
      stationId: map['stationId'] as String,
      arrivalTime: parseTime(map['arrivalTime']),
      departureTime: parseTime(map['departureTime']),
      stopNumber: map['stopNumber'] as int,
    );
  }

  final String id;
  final String tripId;
  final String stationId;

  /// Minutes since midnight.
  final int arrivalTime;

  /// Minutes since midnight.
  final int departureTime;
  final int stopNumber;
}
