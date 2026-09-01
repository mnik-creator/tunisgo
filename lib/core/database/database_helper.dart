// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'database_helper_native.dart'
    if (dart.library.js_interop) 'database_helper_web.dart' as platform;

class DatabaseHelper {
  DatabaseHelper._();

  /// Only for use in tests — allows subclassing to override [rawQuery].
  @visibleForTesting
  DatabaseHelper.forTesting();

  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;
  Completer<Database>? _initCompleter;

  Future<Database> get database async {
    if (_db != null) return _db!;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<Database>();
    try {
      _db = await _initDb();
      _initCompleter!.complete(_db);
    } catch (e, st) {
      final c = _initCompleter!;
      _initCompleter = null;
      c.completeError(e, st);
    }
    return _db!;
  }

  Future<Database> _initDb() async {
    if (kIsWeb) return _initDbWeb();
    return platform.initDbNative();
  }

  /// Web: loads DB bytes from the bundled asset and opens it via
  /// sqflite_common_ffi_web (backed by OPFS / IndexedDB).
  Future<Database> _initDbWeb() async {
    databaseFactory = databaseFactoryFfiWeb;
    const dbName = 'sncft.db';

    // Check stored version; if stale or absent, restore from asset.
    bool needsCopy = true;
    try {
      final probe = await databaseFactory.openDatabase(dbName);
      final rows = await probe.rawQuery(
        "SELECT value FROM metadata WHERE key='version' LIMIT 1",
      );
      await probe.close();
      if (rows.isNotEmpty) {
        needsCopy = (rows.first['value'] as String?) != '2.2.2';
      }
    } catch (_) {
      needsCopy = true;
    }

    if (needsCopy) {
      await databaseFactory.deleteDatabase(dbName);
      final data = await rootBundle.load('assets/db/sncft.db');
      final bytes = data.buffer.asUint8List();
      await databaseFactoryFfiWeb.writeDatabaseBytes(dbName, bytes);
    }

    return databaseFactory.openDatabase(dbName);
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }
}
