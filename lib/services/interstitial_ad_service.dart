// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

/// One preloaded interstitial, shown at a natural break (between pressing
/// Search and seeing results). Failed loads retry with backoff; an ad older
/// than [_maxAge] is replaced, since AdMob stops paying for stale ones.
class InterstitialAdService {
  static InterstitialAd? _ad;
  static DateTime? _loadedAt;
  static bool _loading = false;
  static int _failures = 0;
  static Timer? _retry;

  static const _maxAge = Duration(minutes: 55);

  static bool get isReady =>
      _ad != null &&
      _loadedAt != null &&
      DateTime.now().difference(_loadedAt!) < _maxAge;

  /// Loads an interstitial unless one is ready or loading.
  static Future<void> preload() async {
    if (_loading || isReady || !await AdService.canRequestAds()) return;
    _ad?.dispose();
    _ad = null;
    _loading = true;
    await InterstitialAd.load(
      adUnitId: AdService.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _failures = 0;
          _ad = ad;
          _loadedAt = DateTime.now();
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (_) {
          _loading = false;
          _failures++;
          // 30 s, 60 s, 120 s … capped at 5 min.
          final wait = Duration(seconds: (30 << (_failures - 1).clamp(0, 4)).clamp(30, 300));
          _retry?.cancel();
          _retry = Timer(wait, preload);
        },
      ),
    );
  }

  /// Shows the ad and completes once it is closed (true) or could not be
  /// shown (false). Always preloads the next one.
  static Future<bool> showAndWait() async {
    if (!isReady) {
      unawaited(preload());
      return false;
    }
    final ad = _ad!;
    _ad = null;
    _loadedAt = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(true);
        unawaited(preload());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
        unawaited(preload());
      },
    );
    await ad.show();
    // Never leave the search hanging if a callback goes missing.
    return done.future.timeout(const Duration(minutes: 2), onTimeout: () => false);
  }
}
