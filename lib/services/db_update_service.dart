// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import '../core/database/database_helper.dart';
import 'database_updater.dart';

export 'database_updater.dart' show DbUpdateStatus;

/// Manual "check for timetable updates" from Settings. Applies a downloaded
/// database right away by reopening it.
class DbUpdateService {
  DbUpdateService._();

  static const String _operator = 'sncft';

  /// Checked too; its errors are not shown (no manifest entry until the first
  /// TRANSTU upload), but a downloaded update counts.
  static const String _secondary = 'transtu';

  static Future<DbUpdateStatus> checkAndUpdate({
    void Function(double progress)? onProgress,
  }) async {
    var status = await DatabaseUpdater().checkForUpdate(
      _operator,
      onProgress: onProgress,
    );
    final transtu = await DatabaseUpdater().checkForUpdate(_secondary);
    if (transtu == DbUpdateStatus.updated) status = DbUpdateStatus.updated;
    if (status == DbUpdateStatus.updated) await DatabaseHelper.instance.reopen();
    return status;
  }

  static Future<String> getLocalVersion() async =>
      (await DatabaseUpdater.installedVersion(_operator)).toString();
}
