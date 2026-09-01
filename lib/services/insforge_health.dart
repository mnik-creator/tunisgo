// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'package:dio/dio.dart';

import '../config/insforge_config.dart';

/// Lightweight connectivity probe for the InsForge backend.
///
/// Fetches the manifest object header to verify reachability without
/// downloading the full manifest body.
Future<bool> pingInsforge() async {
  try {
    final url = '${InsforgeConfig.baseUrl}'
        '/api/storage/buckets/${InsforgeConfig.manifestBucket}'
        '/objects/${InsforgeConfig.manifestKey}';
    final r = await Dio().head<void>(
      url,
      options: Options(
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        // 404 is still a reachable server response
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}
