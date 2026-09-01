// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

class InterstitialAdService {
  static InterstitialAd? _ad;
  static bool _isLoaded = false;

  /// Preload an interstitial. Call once on app start.
  static Future<void> preload() async {
    await InterstitialAd.load(
      adUnitId: AdService.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoaded = true;
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (_) {
          _isLoaded = false;
          _ad = null;
        },
      ),
    );
  }

  /// Show the ad if loaded, then preload the next one.
  /// Returns immediately if not loaded or during quiet hours.
  static Future<void> show() async {
    if (!_isLoaded || _ad == null || AdService.isQuietHours) return;

    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        _isLoaded = false;
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _ad = null;
        _isLoaded = false;
      },
    );

    await _ad!.show();
  }
}
