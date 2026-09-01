// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'package:flutter_test/flutter_test.dart';
import 'package:tunis_go/core/helpers/time_helpers.dart';

void main() {
  group('minutesToHHMM', () {
    test('converts 0 to 00:00', () {
      expect(minutesToHHMM(0), '00:00');
    });

    test('converts 510 to 08:30', () {
      expect(minutesToHHMM(510), '08:30');
    });

    test('pads single-digit hours and minutes', () {
      expect(minutesToHHMM(65), '01:05');
    });

    test('converts midnight minus one minute (1439) to 23:59', () {
      expect(minutesToHHMM(1439), '23:59');
    });

    test('converts noon (720) to 12:00', () {
      expect(minutesToHHMM(720), '12:00');
    });
  });

  // Note: servicesDaysLabel now requires AppLocalizations parameter
  // Integration tests should verify proper localization behavior
}
