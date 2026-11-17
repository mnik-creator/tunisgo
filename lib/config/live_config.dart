// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'worker_config.dart';

/// Build-time constants for the live (real-time delay) layer.
///
/// The feed comes from the TunisGO Cloudflare Worker (`cloudflare/live-worker`),
/// never from sncft.com.tn directly: `WORKER_URL` + `/live.json` (see
/// [WorkerConfig]), or an explicit `--dart-define=LIVE_FEED_URL=...` (tests,
/// local server). When both are empty every live feature stays hidden and the
/// app behaves exactly as the offline timetable.
class LiveConfig {
  LiveConfig._();

  static const String _explicitUrl = String.fromEnvironment('LIVE_FEED_URL');

  static const String feedUrl = _explicitUrl != ''
      ? _explicitUrl
      : WorkerConfig.baseUrl == ''
      ? ''
      : '${WorkerConfig.baseUrl}/live.json';

  static bool get isEnabled => feedUrl.isNotEmpty;

  /// The Worker refreshes once a minute (every 15 min on quiet nights, which
  /// the feed announces via `nextAt`); polling faster gains nothing.
  static const Duration pollInterval = Duration(seconds: 60);

  /// A feed older than this is treated as unavailable (Worker or SNCFT down).
  static const Duration maxAge = Duration(minutes: 5);
}
