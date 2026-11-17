// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

/// Rewarded ad the rider asks for (an extra favorite / reminder slot).
/// Loaded on demand: a user who never hits the limit never costs a request.
class RewardedAdService {
  RewardedAdService._();

  static RewardedAd? _ad;
  static DateTime? _loadedAt;
  static const _maxAge = Duration(minutes: 55);

  static bool get _isReady =>
      _ad != null && _loadedAt != null && DateTime.now().difference(_loadedAt!) < _maxAge;

  /// Warms up an ad while the rider reads the offer.
  static Future<void> preload() async {
    if (_isReady || !await AdService.canRequestAds()) return;
    final loaded = Completer<void>();
    await RewardedAd.load(
      adUnitId: AdService.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad?.dispose();
          _ad = ad;
          _loadedAt = DateTime.now();
          loaded.complete();
        },
        onAdFailedToLoad: (_) => loaded.complete(),
      ),
    );
    await loaded.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  /// Shows an ad and completes with true once the reward was earned, false
  /// when no ad could be loaded or the rider closed it early.
  static Future<bool> showForReward() async {
    if (!_isReady) await preload();
    if (!_isReady) return false;
    final ad = _ad!;
    _ad = null;
    _loadedAt = null;
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    return earned;
  }
}
