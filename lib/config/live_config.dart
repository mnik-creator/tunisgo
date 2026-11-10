// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

/// Build-time constants for the live (real-time delay) layer.
///
/// Usage:
///   `flutter run --dart-define=LIVE_FEED_URL=https://tunisgo-live.<account>.workers.dev/live.json`
///
/// The URL points at the TunisGO Cloudflare Worker (`cloudflare/live-worker`),
/// never at sncft.com.tn directly. When it is empty every live feature stays
/// hidden and the app behaves exactly as the offline timetable.
class LiveConfig {
  LiveConfig._();

  static const String feedUrl = String.fromEnvironment('LIVE_FEED_URL');

  static bool get isEnabled => feedUrl.isNotEmpty;

  /// The Worker refreshes once a minute; polling faster gains nothing.
  static const Duration pollInterval = Duration(seconds: 60);

  /// A feed older than this is treated as unavailable (Worker or SNCFT down).
  static const Duration maxAge = Duration(minutes: 5);
}
