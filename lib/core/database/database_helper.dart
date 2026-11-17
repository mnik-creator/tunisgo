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

  /// `metadata.version` of the bundled `assets/db/sncft.db`; web reloads the
  /// asset when its stored copy differs.
  static const _webDbVersion = '2.3.1';

  /// `metadata.version` of the bundled `assets/db/transtu.db` (web reload).
  static const _webTranstuVersion = '1.0.0';

  /// Tables read through the merged TEMP views (see [attachTranstu]).
  static const _mergedTables = [
    'operators', 'routes', 'stops', 'trips', 'stop_times', 'fares', 'fare_rules',
  ];

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

  /// Closes the database so the next query reopens it, picking up a
  /// downloaded update (see DatabaseUpdater.ensureDatabase). Native only.
  Future<void> reopen() async {
    if (kIsWeb) return;
    final pending = _initCompleter?.future;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // Failed open: nothing to close.
      }
    }
    final db = _db;
    _db = null;
    _initCompleter = null;
    await db?.close();
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
        needsCopy = (rows.first['value'] as String?) != _webDbVersion;
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

    final db = await databaseFactory.openDatabase(dbName);
    try {
      const transtuName = 'transtu.db';
      if (await _webStoredVersion(transtuName) != _webTranstuVersion) {
        await databaseFactory.deleteDatabase(transtuName);
        final data = await rootBundle.load('assets/db/transtu.db');
        await databaseFactoryFfiWeb.writeDatabaseBytes(
          transtuName,
          data.buffer.asUint8List(),
        );
      }
      await attachTranstu(db, transtuName);
    } catch (e) {
      debugPrint('[DatabaseHelper] TRANSTU unavailable on web: $e');
    }
    return db;
  }

  Future<String?> _webStoredVersion(String name) async {
    try {
      final probe = await databaseFactory.openDatabase(name);
      final rows = await probe.rawQuery(
        "SELECT value FROM metadata WHERE key='version' LIMIT 1",
      );
      await probe.close();
      return rows.isEmpty ? null : rows.first['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Attaches the TRANSTU database (métro léger + TGM, its own file and OTA
  /// cycle) to [db] and shadows each table in [_mergedTables] with a TEMP view
  /// `main.X UNION ALL transtu.X`. SQLite resolves unqualified names to TEMP
  /// first, so every repository query reads both operators unchanged. Ids
  /// never overlap (ranges in tools/build_transtu_db.py).
  ///
  /// Columns follow `main`; one missing from transtu.db reads as NULL, so an
  /// older sncft.db or transtu.db still works. Returns false (SNCFT only) on
  /// any failure. TEMP views and the attachment end with the connection.
  static Future<bool> attachTranstu(Database db, String path) async {
    try {
      await db.execute('ATTACH DATABASE ? AS transtu', [path]);
    } catch (e) {
      debugPrint('[DatabaseHelper] attach transtu failed: $e');
      return false;
    }
    try {
      for (final table in _mergedTables) {
        final mainCols = await _columns(db, 'main', table);
        final otherCols = (await _columns(db, 'transtu', table)).toSet();
        if (mainCols.isEmpty || otherCols.isEmpty) continue;
        final select = mainCols.map((c) => '"$c"').join(', ');
        final selectOther = mainCols
            .map((c) => otherCols.contains(c) ? '"$c"' : 'NULL')
            .join(', ');
        await db.execute(
          'CREATE TEMP VIEW "$table" AS '
          'SELECT $select FROM main."$table" '
          'UNION ALL SELECT $selectOther FROM transtu."$table"',
        );
      }
      return true;
    } catch (e) {
      debugPrint('[DatabaseHelper] TRANSTU views failed: $e');
      for (final table in _mergedTables) {
        try {
          await db.execute('DROP VIEW IF EXISTS temp."$table"');
        } catch (_) {}
      }
      try {
        await db.execute('DETACH DATABASE transtu');
      } catch (_) {}
      return false;
    }
  }

  static Future<List<String>> _columns(
    Database db,
    String schema,
    String table,
  ) async {
    final rows = await db.rawQuery('PRAGMA $schema.table_info("$table")');
    return [for (final r in rows) r['name'] as String];
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }
}
