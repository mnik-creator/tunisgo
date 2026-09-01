// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import '../helpers/time_helpers.dart';

const _allDays = 0x7F; // 127
const _exceptSunday = 0x3F; // 63
const _sundayOnly = 0x40; // 64
const _weekdays = 0x1F; // 31 (Mon-Fri)
const _weekends = 0x60; // 96 (Sat-Sun)

String _stripTripPrefix(String tripCode) {
  return tripCode
      .replaceAll(RegExp(r'^mainlines_'), '')
      .replaceAll(RegExp(r'^banlieue_sahel_'), '')
      .replaceAll(RegExp(r'^banlieue_tunis_'), '')
      .replaceAll(RegExp(r'^banlieue_'), '')
      .replaceAll(RegExp(r'^tgm_'), '')
      .replaceAll('ligne_a_tunis_erriadh_', '')
      .replaceAll('ligne_d_tunis_gobaa_ville_', '')
      .replaceAll('ligne_e_tunis_bougatfa_', '')
      .replaceAll(RegExp(r'^ligne_[a-z]_[a-z_]+_'), '')
      .replaceAll(RegExp(r'^ligne_[a-z]_'), '')
      .replaceAll(RegExp(r'^ligne_'), '');
}

String _extractTrainNumber(String? tripCode) {
  if (tripCode == null || tripCode.isEmpty) return '';
  final cleaned = _stripTripPrefix(tripCode);
  final parts = cleaned.split('-');
  return parts.isNotEmpty ? parts.last : cleaned;
}

String _extractFullTrainNumber(String? tripCode) {
  if (tripCode == null || tripCode.isEmpty) return '';
  return _stripTripPrefix(tripCode);
}

/// Public helper — parses a raw trip_id (from DB) into the display train number.
String extractTrainNumber(String? tripCode) => _extractTrainNumber(tripCode);

/// Public helper — derives a service-days bitmask from a raw trip_id and service_id.
int tripServiceDaysBitmask(String? serviceId, String? tripCode) =>
    _serviceTypeToBitmask(serviceId, tripCode);

int _serviceTypeToBitmask(String? serviceType, String? tripCode) {
  if (serviceType != null && serviceType != '-') {
    switch (serviceType) {
      case 'A':
        return _exceptSunday;
      case 'B':
        return _sundayOnly;
      case 'C':
        return _weekdays;
      case 'D':
      case 'D/*':
        return _weekends;
      default:
        break;
    }
  }
  return _allDays;
}

/// Trip populated from a JOIN across Trip + StopTime + Calendar + Line.
/// The public interface (departureTime, arrivalTime, serviceDays, trainType)
/// is kept stable so ResultsScreen needs no changes.
class Trip {
  const Trip({
    required this.id,
    required this.lineId,
    required this.trainNumber,
    required this.fullTrainNumber,
    required this.departureTime,
    required this.arrivalTime,
    required this.serviceDays,
    required this.trainType,
    this.approximatePrice,
    this.mayArriveLate = false,
  });

  factory Trip.fromMap(Map<String, dynamic> map) {
    final tripCode = map['tripCode'] as String?;
    return Trip(
      id: map['id'] as String,
      lineId: map['lineId'] as String,
      trainNumber: _extractTrainNumber(tripCode),
      fullTrainNumber: _extractFullTrainNumber(tripCode),
      departureTime: hhmmToMinutes(map['fromDepartureTime'] as String),
      arrivalTime: hhmmToMinutes(map['toArrivalTime'] as String),
      serviceDays: _serviceTypeToBitmask(
        map['serviceType'] as String?,
        tripCode,
      ),
      trainType: _mapServiceType((map['lineType'] as String?) ?? 'regular'),
      approximatePrice: map['price'] != null
          ? (map['price'] as num).toDouble()
          : null,
    );
  }

  final String id;
  final String lineId;
  final String trainNumber;
  final String fullTrainNumber;

  /// Minutes since midnight.
  final int departureTime;

  /// Minutes since midnight.
  final int arrivalTime;

  /// Bitmask: bit0=Mon, bit1=Tue, bit2=Wed, bit3=Thu, bit4=Fri, bit5=Sat, bit6=Sun.
  final int serviceDays;

  final String trainType;

  /// Approximate price in TND
  final double? approximatePrice;

  /// True when this trip departed before the search time but may still arrive
  /// at the destination after the searched departure time (running late).
  final bool mayArriveLate;

  Trip copyWith({bool? mayArriveLate}) => Trip(
        id: id,
        lineId: lineId,
        trainNumber: trainNumber,
        fullTrainNumber: fullTrainNumber,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        serviceDays: serviceDays,
        trainType: trainType,
        approximatePrice: approximatePrice,
        mayArriveLate: mayArriveLate ?? this.mayArriveLate,
      );
}

String _mapServiceType(String s) {
  switch (s.toLowerCase()) {
    case 'express':
      return 'EXPRESS';
    case 'intercity':
    case 'mainline':
      return 'INTERCITY';
    case 'suburban':
    case 'suburban_sahel':
    case 'suburban_tunis':
    case 'tgm':
      return 'SUBURBAN';
    default:
      return 'REGULAR';
  }
}
