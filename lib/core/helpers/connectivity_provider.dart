// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple connectivity check — pings DNS to confirm internet access.
/// Returns false when offline or on failure.
final isOnlineProvider = FutureProvider<bool>((ref) async {
  try {
    final result = await InternetAddress.lookup('sncft.com.tn')
        .timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
});
