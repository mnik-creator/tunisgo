// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

/// Base URL of the TunisGO Cloudflare Worker (`cloudflare/live-worker`),
/// which serves the live feed (`/live.json`) and timetable database updates
/// (`/db/manifest.json`).
///
/// Usage:
///   `flutter build appbundle --dart-define=WORKER_URL=https://tunisgo-live.tunisgo.workers.dev`
///
/// When empty, live data stays hidden and the app keeps its bundled timetable.
class WorkerConfig {
  WorkerConfig._();

  static const String baseUrl = String.fromEnvironment('WORKER_URL');

  static bool get isEnabled => baseUrl != '';

  static const String dbManifestUrl = baseUrl == '' ? '' : '$baseUrl/db/manifest.json';
}
