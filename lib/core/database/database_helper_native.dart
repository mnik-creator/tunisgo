// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../services/database_updater.dart';
import 'database_helper.dart';

/// Opens the SNCFT SQLite database (the bundled copy, or a newer one that
/// DatabaseUpdater.checkForUpdate downloaded earlier) and attaches the TRANSTU
/// one next to it. Never waits for network.
Future<Database> initDbNative() async {
  final path = await DatabaseUpdater().ensureDatabase('sncft');
  // Do NOT open readOnly: WAL mode requires write access to -shm/-wal files.
  final db = await openDatabase(path);
  try {
    final transtu = await DatabaseUpdater().ensureDatabase('transtu');
    await DatabaseHelper.attachTranstu(db, transtu);
  } catch (e) {
    // No TRANSTU file: SNCFT keeps working on its own.
    debugPrint('[DatabaseHelper] TRANSTU unavailable: $e');
  }
  return db;
}
