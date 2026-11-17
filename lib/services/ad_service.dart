// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'dart:async';
import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // ─── AD UNIT IDs ──────────────────────────────────────────────────────────
  static String get bannerAdUnitId => Platform.isIOS
      ? 'ca-app-pub-5314813801565109/4430868080'
      : 'ca-app-pub-5314813801565109/4028012594';

  static String get interstitialAdUnitId => Platform.isIOS
      ? 'ca-app-pub-5314813801565109/4219584289'
      : 'ca-app-pub-5314813801565109/7775685913';

  static String get rewardedAdUnitId => Platform.isIOS
      ? 'ca-app-pub-5314813801565109/9280339279'
      : 'ca-app-pub-5314813801565109/8928304267';

  static String get nativeAdUnitId => Platform.isIOS
      ? 'ca-app-pub-5314813801565109/5879681125'
      : 'ca-app-pub-5314813801565109/7615222595';

  // ─── INTERSTITIAL PACING ──────────────────────────────────────────────────
  // Time-based, not "every Nth search": a rider checking two trains on the
  // platform sees at most one ad, a heavy user a few per hour.

  /// No interstitial on the first search of a session (first impression).
  static const int interstitialFromSearch = 2;

  /// Minimum gap between two interstitials, across app restarts.
  static const Duration interstitialMinGap = Duration(minutes: 4);

  static const int maxInterstitialsPerSession = 3;
  static const int maxInterstitialsPerDay = 8;

  // ─── QUIET HOURS (22:00–05:00): no full-screen ads at night ───────────────
  static bool get isQuietHours {
    final hour = DateTime.now().hour;
    return hour >= 22 || hour < 5;
  }

  // ─── CONSENT + INITIALIZATION ─────────────────────────────────────────────
  static final Completer<void> _ready = Completer<void>();

  /// Asks for consent where the law requires it (EEA, UK, Switzerland — via
  /// Google's UMP; elsewhere this returns at once), then starts the SDK.
  /// Without a consent answer AdMob serves few or no ads to those users.
  static Future<void> initialize() async {
    try {
      final info = ConsentInformation.instance;
      final asked = Completer<void>();
      info.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => ConsentForm.loadAndShowConsentFormIfRequired((_) => asked.complete()),
        (_) => asked.complete(),
      );
      await asked.future.timeout(const Duration(seconds: 15), onTimeout: () {});
      await MobileAds.instance.initialize();
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  /// `--dart-define=NO_ADS=true` builds an ad-free copy for store screenshots.
  static const bool _noAds = bool.fromEnvironment('NO_ADS');

  /// True once consent (if needed) allows ad requests.
  static Future<bool> canRequestAds() async {
    if (_noAds) return false;
    await _ready.future;
    return ConsentInformation.instance.canRequestAds();
  }

  /// Whether the user must be offered a way to change their consent choice.
  static Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  static Future<void> showPrivacyOptions() {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) => done.complete());
    return done.future;
  }
}
