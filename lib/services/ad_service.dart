// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
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

  // ─── FREQUENCY CAP ────────────────────────────────────────────────────────
  static const int maxInterstitialsPerSession = 1;
  static const int searchesBetweenInterstitials = 5;
  static const int maxRewardedPerSession = 3;

  // ─── QUIET HOURS (22:00–05:00) ────────────────────────────────────────────
  static bool get isQuietHours {
    final hour = DateTime.now().hour;
    return hour >= 22 || hour < 5;
  }

  // ─── INITIALIZATION ───────────────────────────────────────────────────────
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }
}
