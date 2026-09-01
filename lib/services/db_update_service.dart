// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DbUpdateStatus {
  upToDate,
  updated,
  noConnection,
  serverError,
  checksumMismatch,
  unknown,
}

class DbUpdateService {
  DbUpdateService._();

  static const String _insforgeUrl = String.fromEnvironment(
    'INSFORGE_URL',
    defaultValue: 'https://your-project.region.insforge.app',
  );

  // Matches DatabaseUpdater constants so both services share state.
  static const String _operator = 'sncft';
  static const String _prefKey = 'db_version_$_operator';

  /// Call once at app startup or on-demand (fire-and-forget, safe to await).
  static Future<DbUpdateStatus> checkAndUpdate({
    void Function(double progress)? onProgress,
    bool silent = false,
  }) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      // 1. Fetch manifest from public storage bucket (no auth required).
      final manifestUrl =
          '$_insforgeUrl/api/storage/buckets/files/objects/sncft_manifest.json';
      final manifestResp = await dio.get<dynamic>(manifestUrl);

      if (manifestResp.statusCode != 200) return DbUpdateStatus.serverError;

      final data = manifestResp.data;
      final manifest = data is Map<String, dynamic>
          ? data
          : jsonDecode(data as String) as Map<String, dynamic>;

      final entry =
          manifest['databases']?[_operator] as Map<String, dynamic>?;
      if (entry == null) return DbUpdateStatus.serverError;

      final remoteVersion = entry['version'] as int;

      // 2. Compare with locally installed version.
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getInt(_prefKey) ?? 0;

      if (!silent && kDebugMode) {
        debugPrint('[DbUpdate] remote=v$remoteVersion local=v$localVersion');
      }

      if (localVersion >= remoteVersion) return DbUpdateStatus.upToDate;

      // 3. Download into a temp file.
      final bucket = entry['bucket'] as String;
      final fileKey = entry['file'] as String;
      final expectedHash = entry['sha256'] as String;

      final dir = await getApplicationDocumentsDirectory();
      final dbDir = Directory('${dir.path}/operator_dbs');
      if (!dbDir.existsSync()) dbDir.createSync(recursive: true);

      final finalPath = '${dbDir.path}/$_operator.db';
      final tempPath = '$finalPath.tmp';

      await dio.download(
        '$_insforgeUrl/api/storage/buckets/$bucket/objects/$fileKey',
        tempPath,
        options: Options(receiveTimeout: const Duration(minutes: 5)),
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
          if (!silent && kDebugMode) {
            debugPrint(
              '[DbUpdate] ${total > 0 ? (received / total * 100).toStringAsFixed(0) : '?'}%',
            );
          }
        },
      );

      // 4. Verify SHA-256.
      final tempFile = File(tempPath);
      final bytes = await tempFile.readAsBytes();
      final actualHash = crypto.sha256.convert(bytes).toString();
      if (actualHash != expectedHash) {
        await tempFile.delete();
        if (kDebugMode) debugPrint('[DbUpdate] Checksum mismatch — discarded');
        return DbUpdateStatus.checksumMismatch;
      }

      // 5. Atomic replace.
      if (File(finalPath).existsSync()) File(finalPath).deleteSync();
      tempFile.renameSync(finalPath);
      await prefs.setInt(_prefKey, remoteVersion);

      if (kDebugMode) debugPrint('[DbUpdate] Updated to v$remoteVersion');
      return DbUpdateStatus.updated;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return DbUpdateStatus.noConnection;
      }
      if (kDebugMode) debugPrint('[DbUpdate] DioException: ${e.type}');
      return DbUpdateStatus.serverError;
    } catch (e) {
      if (kDebugMode) debugPrint('[DbUpdate] Unexpected error: $e');
      return DbUpdateStatus.unknown;
    }
  }

  /// Returns the locally stored DB version string, or 'initial' if none.
  static Future<String> getLocalVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_prefKey) ?? 0;
    return v == 0 ? 'initial' : v.toString();
  }
}
