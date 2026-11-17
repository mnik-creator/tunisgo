// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter_test/flutter_test.dart';
import 'package:tunis_go/services/database_updater.dart';

void main() {
  test('checkForUpdate completes (startup awaits sncft, then transtu)', () async {
    // Without WORKER_URL the check returns at once; before the fix the
    // in-flight future waited on itself and never completed.
    final status = await DatabaseUpdater()
        .checkForUpdate('sncft')
        .timeout(const Duration(seconds: 5));
    expect(status, DbUpdateStatus.upToDate);
    expect(
      await DatabaseUpdater()
          .checkForUpdate('transtu')
          .timeout(const Duration(seconds: 5)),
      DbUpdateStatus.upToDate,
    );
  });
}
