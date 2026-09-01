// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:sqflite/sqflite.dart';

import '../../services/database_updater.dart';

/// Opens the SNCFT SQLite database, updating from InsForge Storage if a newer
/// manifest version is available.  Falls back to the local copy or bundled
/// asset when the device is offline.
Future<Database> initDbNative() async {
  final path = await DatabaseUpdater().ensureDatabase('sncft');
  // Do NOT open readOnly: WAL mode requires write access to -shm/-wal files.
  return openDatabase(path);
}
