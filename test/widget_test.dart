// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

// Smoke test — kept minimal; full screen tests are in test/widget/.
import 'package:flutter_test/flutter_test.dart';
import 'package:tunis_go/core/helpers/time_helpers.dart';

void main() {
  test('app helpers smoke test', () {
    expect(minutesToHHMM(0), '00:00');
  });
}
