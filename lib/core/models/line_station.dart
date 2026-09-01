// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
class LineStation {
  const LineStation({
    required this.id,
    required this.lineId,
    required this.stationId,
    required this.order,
  });

  factory LineStation.fromMap(Map<String, dynamic> map) => LineStation(
    id: map['id'] as String,
    lineId: map['lineId'] as String,
    stationId: map['stationId'] as String,
    order: map['order'] as int,
  );

  final String id;
  final String lineId;
  final String stationId;
  final int order;
}
