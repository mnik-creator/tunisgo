// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

/// Build-time constants injected via --dart-define.
///
/// Usage:
///   flutter run \
///     --dart-define=INSFORGE_URL=https://your-project.insforge.app \
///     --dart-define=INSFORGE_ANON_KEY=eyJhbGci...
///
/// Never hardcode real values here — keep them in CI secrets or local .env.
class InsforgeConfig {
  InsforgeConfig._();

  static const String baseUrl = String.fromEnvironment(
    'INSFORGE_URL',
    defaultValue: 'https://your-project.region.insforge.app',
  );

  /// Anon key (public, safe for mobile). Never put the admin/service key here.
  static const String anonKey = String.fromEnvironment(
    'INSFORGE_ANON_KEY',
    defaultValue: 'your-anon-key-here',
  );

  /// Bucket that holds manifest.json and other system configs.
  static const String manifestBucket = 'files';

  static const String manifestKey = 'sncft_manifest.json';
}
