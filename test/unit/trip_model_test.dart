// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'package:flutter_test/flutter_test.dart';
import 'package:tunis_go/core/models/trip.dart';

void main() {
  group('Trip constructor', () {
    test('creates trip with all required fields', () {
      const trip = Trip(
        id: 'T1',
        lineId: 'L1',
        trainNumber: 'RAM-42',
        fullTrainNumber: 'RAM-42',
        departureTime: 300,
        arrivalTime: 360,
        serviceDays: 0x7F,
        trainType: 'EXPRESS',
      );
      expect(trip.id, 'T1');
      expect(trip.trainNumber, 'RAM-42');
      expect(trip.departureTime, 300);
      expect(trip.arrivalTime, 360);
      expect(trip.serviceDays, 0x7F);
      expect(trip.trainType, 'EXPRESS');
    });

    test('creates regular trip', () {
      const trip = Trip(
        id: 'T2',
        lineId: 'L1',
        trainNumber: '101',
        fullTrainNumber: '101',
        departureTime: 300,
        arrivalTime: 360,
        serviceDays: 0x7F,
        trainType: 'REGULAR',
      );
      expect(trip.trainType, 'REGULAR');
    });
  });

  group('Trip.fromMap', () {
    test('parses required fields correctly', () {
      final map = {
        'id': 'T3',
        'lineId': 'L2',
        'tripCode': '202',
        'fromDepartureTime': '08:30',
        'toArrivalTime': '10:00',
        'lineType': 'express',
        'serviceType': 'C',
        'monday': 1,
        'tuesday': 1,
        'wednesday': 1,
        'thursday': 1,
        'friday': 1,
        'saturday': 0,
        'sunday': 0,
      };
      final trip = Trip.fromMap(map);
      expect(trip.id, 'T3');
      expect(trip.departureTime, 510); // 08:30 = 510 min
      expect(trip.arrivalTime, 600);  // 10:00 = 600 min
      expect(trip.trainType, 'EXPRESS');
      expect(trip.serviceDays, 31); // Mon-Fri = bits 0-4
    });

    test('defaults trainType to REGULAR when absent', () {
      final map = {
        'id': 'T4',
        'lineId': 'L1',
        'tripCode': '303',
        'fromDepartureTime': '08:00',
        'toArrivalTime': '09:00',
        'lineType': null,
        'serviceType': null,
        'monday': 1,
        'tuesday': 1,
        'wednesday': 1,
        'thursday': 1,
        'friday': 1,
        'saturday': 1,
        'sunday': 1,
      };
      final trip = Trip.fromMap(map);
      expect(trip.trainType, 'REGULAR');
    });
  });
}
