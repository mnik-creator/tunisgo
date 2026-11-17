// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/worker_config.dart';

/// Version (on the manifest's scale) of each database bundled in
/// `assets/initial/`. Bump it whenever the bundled file is rebuilt: installs
/// holding an older copy then switch to the bundled one on the next start,
/// and a remote file only replaces it when the manifest version is higher.
/// Keep in step with `cloudflare/live-worker/db.json`.
/// `transtu` = métro léger + TGM (tools/build_transtu_db.py), attached to
/// sncft.db by DatabaseHelper.attachTranstu.
const Map<String, int> kBundledDbVersions = {'sncft': 6, 'transtu': 1};

/// Highest database schema this build can read. A manifest entry with a
/// higher `schema` is skipped, so old app builds keep a file they understand.
const int kSupportedDbSchema = 1;

enum DbUpdateStatus {
  upToDate,

  /// A newer file was downloaded and verified; it is swapped in the next time
  /// the database is opened ([DatabaseUpdater.ensureDatabase]).
  updated,
  noConnection,
  serverError,
  checksumMismatch,
  unknown,
}

/// Timetable databases: bundled copy plus over-the-air updates from the
/// TunisGO Worker (`/db/manifest.json`, see `cloudflare/live-worker`).
///
/// Opening never waits for the network. [checkForUpdate] downloads a newer
/// file next to the live one (`{operator}.db.next`), verifies its SHA-256, and
/// [ensureDatabase] swaps it in before the next open.
///
/// Files live under `{ApplicationDocumentsDirectory}/operator_dbs/`.
class DatabaseUpdater {
  static const String _versionKey = 'db_version_';
  static const String _pendingKey = 'db_pending_version_';

  static final Map<String, Future<DbUpdateStatus>> _inFlight = {};

  /// Path of an up-to-date local database for [operator], ready for
  /// `openDatabase()`. Call only while the database is closed.
  Future<String> ensureDatabase(String operator) async {
    final dir = await _dbDirectory();
    final localPath = p.join(dir.path, '$operator.db');
    final prefs = await SharedPreferences.getInstance();
    final bundled = kBundledDbVersions[operator] ?? 1;

    // 1. A verified download from a previous run.
    final pending = prefs.getInt('$_pendingKey$operator');
    final nextPath = '$localPath.next';
    if (pending != null) {
      if (pending > bundled && File(nextPath).existsSync()) {
        _replaceDbFile(nextPath, localPath);
        await prefs.setInt('$_versionKey$operator', pending);
        _log('"$operator" switched to downloaded v$pending.');
      } else if (File(nextPath).existsSync()) {
        File(nextPath).deleteSync();
      }
      await prefs.remove('$_pendingKey$operator');
    }

    // 2. Bundled asset when nothing newer is installed.
    if (!File(localPath).existsSync() ||
        (prefs.getInt('$_versionKey$operator') ?? 0) < bundled) {
      await _bootstrapFromAssets(operator, localPath, prefs, bundled);
    }
    return localPath;
  }

  /// Installed (or bundled) version of [operator].
  static Future<int> installedVersion(String operator) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_versionKey$operator') ?? kBundledDbVersions[operator] ?? 0;
  }

  /// Downloads a newer [operator] database if the manifest has one. Safe to
  /// call concurrently: callers share one check.
  Future<DbUpdateStatus> checkForUpdate(
    String operator, {
    void Function(double progress)? onProgress,
  }) {
    // Block body: an arrow would return the removed future itself, and
    // whenComplete waits on a returned future, so the call never completed.
    return _inFlight[operator] ??= _check(operator, onProgress)
        .whenComplete(() {
      _inFlight.remove(operator);
    });
  }

  Future<DbUpdateStatus> _check(
    String operator,
    void Function(double progress)? onProgress,
  ) async {
    const manifestUrl = WorkerConfig.dbManifestUrl;
    if (manifestUrl == '') return DbUpdateStatus.upToDate;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    try {
      final r = await dio.get<dynamic>(manifestUrl);
      final data = r.data;
      final manifest = data is Map<String, dynamic>
          ? data
          : jsonDecode(data as String) as Map<String, dynamic>;
      final entry = (manifest['databases'] as Map<String, dynamic>?)?[operator];
      if (entry is! Map<String, dynamic>) {
        // E.g. a new operator before its first upload, or an edge-cached
        // manifest from before the deploy (max-age 300 s).
        _log('"$operator" not in the manifest.');
        return DbUpdateStatus.serverError;
      }

      final remote = entry['version'] as int;
      final schema = entry['schema'] as int? ?? 1;
      final prefs = await SharedPreferences.getInstance();
      final have = [
        await installedVersion(operator),
        prefs.getInt('$_pendingKey$operator') ?? 0,
      ].reduce((a, b) => a > b ? a : b);
      if (remote <= have || schema > kSupportedDbSchema) {
        _log('"$operator" current: have v$have, remote v$remote (schema $schema).');
        return DbUpdateStatus.upToDate;
      }

      final dir = await _dbDirectory();
      final nextPath = p.join(dir.path, '$operator.db.next');
      final tmpPath = '$nextPath.tmp';
      final fileUrl = Uri.parse(manifestUrl).resolve(entry['file'] as String);
      try {
        await dio.downloadUri(
          fileUrl,
          tmpPath,
          options: Options(receiveTimeout: const Duration(minutes: 5)),
          onReceiveProgress: (got, total) {
            if (total > 0) onProgress?.call(got / total);
          },
        );
        final hash = sha256.convert(await File(tmpPath).readAsBytes()).toString();
        if (hash != entry['sha256']) {
          _log('"$operator" v$remote checksum mismatch — discarded.');
          return DbUpdateStatus.checksumMismatch;
        }
        File(tmpPath).renameSync(nextPath);
      } finally {
        if (File(tmpPath).existsSync()) File(tmpPath).deleteSync();
      }
      await prefs.setInt('$_pendingKey$operator', remote);
      _log('"$operator" v$remote downloaded; applies on next open.');
      return DbUpdateStatus.updated;
    } on DioException catch (e) {
      _log('"$operator" update check failed: ${e.type}');
      return switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => DbUpdateStatus.noConnection,
        _ => DbUpdateStatus.serverError,
      };
    } catch (e) {
      _log('"$operator" update check failed: $e');
      return DbUpdateStatus.unknown;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static void _log(String message) {
    if (kDebugMode) debugPrint('[DatabaseUpdater] $message');
  }

  Future<Directory> _dbDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'operator_dbs'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Copies the bundled `assets/initial/{operator}.db` to [localPath].
  Future<void> _bootstrapFromAssets(
    String operator,
    String localPath,
    SharedPreferences prefs,
    int bundledVersion,
  ) async {
    try {
      final asset = await rootBundle.load('assets/initial/$operator.db');
      final tmpPath = '$localPath.asset';
      await File(tmpPath).writeAsBytes(asset.buffer.asUint8List(), flush: true);
      _replaceDbFile(tmpPath, localPath);
      // Remote files at or below this version are older than what we ship.
      await prefs.setInt('$_versionKey$operator', bundledVersion);
      _log('Bootstrapped "$operator" from assets (v$bundledVersion).');
    } catch (e) {
      _log('No bundled asset for "$operator": $e');
      if (!File(localPath).existsSync()) rethrow;
    }
  }

  /// Moves [from] over [to], dropping the old file's WAL journal so SQLite
  /// never replays it onto the new database.
  void _replaceDbFile(String from, String to) {
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('$to$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    File(from).renameSync(to);
  }
}
