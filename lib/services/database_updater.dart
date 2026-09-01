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

import '../config/insforge_config.dart';

/// Manifest-based OTA database updater.
///
/// Flow for each operator on every cold start:
///   1. Bootstrap from `assets/initial/{operator}.db` if no local file exists.
///   2. Fetch `files/manifest.json` from InsForge Storage.
///   3. If offline → return existing local path (offline-first).
///   4. Compare manifest version with locally installed version.
///   5. Download versioned `.db` into a `.tmp` file if newer.
///   6. Verify SHA-256; on mismatch delete `.tmp` and throw.
///   7. Atomic rename `.tmp` → final path; persist version in SharedPreferences.
///
/// All operator databases are stored under:
///   `{ApplicationDocumentsDirectory}/operator_dbs/{operator}.db`
class DatabaseUpdater {
  static const String _prefKeyPrefix = 'db_version_';

  /// Guarantees an up-to-date `.db` file on disk for [operator].
  /// Returns the absolute path suitable for passing to `openDatabase()`.
  Future<String> ensureDatabase(String operator) async {
    final dir = await _dbDirectory();
    final localPath = p.join(dir.path, '$operator.db');
    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getInt('$_prefKeyPrefix$operator') ?? 0;

    // 1. Bootstrap from bundled asset if local file is absent.
    if (!File(localPath).existsSync()) {
      await _bootstrapFromAssets(operator, localPath, prefs);
    }

    // 2. Fetch manifest — null means offline or server unreachable.
    final manifest = await _fetchManifest();
    if (manifest == null) {
      if (!File(localPath).existsSync()) {
        throw Exception(
          '[DatabaseUpdater] No network and no local DB for "$operator".',
        );
      }
      if (kDebugMode) {
        debugPrint('[DatabaseUpdater] Offline — using local "$operator" DB.');
      }
      return localPath;
    }

    // 3. Locate operator entry in manifest.
    final entry = manifest['databases']?[operator] as Map<String, dynamic>?;
    if (entry == null) {
      throw Exception(
        '[DatabaseUpdater] Operator "$operator" not found in manifest.',
      );
    }

    final remoteVersion = entry['version'] as int;

    // 4. Already up-to-date?
    if (installedVersion >= remoteVersion && File(localPath).existsSync()) {
      if (kDebugMode) {
        debugPrint(
          '[DatabaseUpdater] "$operator" is current (v$installedVersion).',
        );
      }
      return localPath;
    }

    if (kDebugMode) {
      debugPrint(
        '[DatabaseUpdater] Updating "$operator": '
        'v$installedVersion → v$remoteVersion',
      );
    }

    // 5. Download into a temp file.
    final bucket = entry['bucket'] as String;
    final fileKey = entry['file'] as String;
    final expectedHash = entry['sha256'] as String;
    final tmpPath = '$localPath.tmp';

    try {
      await _downloadFile(bucket, fileKey, tmpPath);
    } catch (e) {
      if (File(tmpPath).existsSync()) File(tmpPath).deleteSync();
      // Graceful fallback: use existing local DB rather than crashing.
      if (File(localPath).existsSync()) {
        if (kDebugMode) {
          debugPrint('[DatabaseUpdater] Download failed — using local DB: $e');
        }
        return localPath;
      }
      rethrow;
    }

    // 6. Verify SHA-256.
    final actualHash = await _sha256(tmpPath);
    if (actualHash != expectedHash) {
      File(tmpPath).deleteSync();
      throw Exception(
        '[DatabaseUpdater] SHA-256 mismatch for "$operator" — '
        'expected $expectedHash, got $actualHash.',
      );
    }

    // 7. Atomic replace.
    if (File(localPath).existsSync()) File(localPath).deleteSync();
    File(tmpPath).renameSync(localPath);
    await prefs.setInt('$_prefKeyPrefix$operator', remoteVersion);

    if (kDebugMode) {
      debugPrint('[DatabaseUpdater] "$operator" updated to v$remoteVersion.');
    }
    return localPath;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _fetchManifest() async {
    try {
      final url = '${InsforgeConfig.baseUrl}'
          '/api/storage/buckets/${InsforgeConfig.manifestBucket}'
          '/objects/${InsforgeConfig.manifestKey}';
      final r = await Dio().get<dynamic>(
        url,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      if (r.statusCode != 200) return null;
      // Dio may already have decoded JSON; handle both cases.
      final data = r.data;
      if (data is Map<String, dynamic>) return data;
      if (data is String) return jsonDecode(data) as Map<String, dynamic>;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadFile(
    String bucket,
    String key,
    String destPath,
  ) async {
    final url = '${InsforgeConfig.baseUrl}'
        '/api/storage/buckets/$bucket/objects/$key';
    await Dio().download(
      url,
      destPath,
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
  }

  Future<String> _sha256(String path) async {
    final bytes = await File(path).readAsBytes();
    return sha256.convert(bytes).toString();
  }

  Future<Directory> _dbDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'operator_dbs'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Copies the bundled `assets/initial/{operator}.db` to [localPath].
  /// Silently skips if the asset is absent (network download will cover it).
  Future<void> _bootstrapFromAssets(
    String operator,
    String localPath,
    SharedPreferences prefs,
  ) async {
    try {
      final asset = await rootBundle.load('assets/initial/$operator.db');
      await File(localPath).writeAsBytes(asset.buffer.asUint8List(), flush: true);
      // Mark version=1 so a remote v1 is treated as up-to-date.
      await prefs.setInt('$_prefKeyPrefix$operator', 1);
      if (kDebugMode) {
        debugPrint('[DatabaseUpdater] Bootstrapped "$operator" from assets.');
      }
    } catch (_) {
      // Asset absent — will download from network on first run.
      if (kDebugMode) {
        debugPrint(
          '[DatabaseUpdater] No bundled asset for "$operator"; '
          'will download from network.',
        );
      }
    }
  }
}
