// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
//
// Host side of integration_test/store_screenshots_test.dart: writes the
// screenshots (Flutter surface, no system status bar) to build/store_screenshots.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final out = File('build/store_screenshots/$name.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(bytes);
    return true;
  },
);
