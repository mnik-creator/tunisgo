// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ad_service.dart';

final sessionTrackerProvider =
    StateNotifierProvider<SessionTracker, SessionState>((ref) {
  return SessionTracker();
});

class SessionState {
  final int searchCount;
  final int interstitialsShown;
  final int rewardedShown;
  final DateTime sessionStart;

  const SessionState({
    this.searchCount = 0,
    this.interstitialsShown = 0,
    this.rewardedShown = 0,
    required this.sessionStart,
  });

  /// True when the interstitial conditions are met:
  /// - not exceeded per-session cap
  /// - at least one search done
  /// - divisible by the search interval
  /// - not quiet hours
  bool get canShowInterstitial =>
      !AdService.isQuietHours &&
      interstitialsShown < AdService.maxInterstitialsPerSession &&
      searchCount > 0 &&
      searchCount % AdService.searchesBetweenInterstitials == 0;

  bool get canShowRewarded =>
      !AdService.isQuietHours &&
      rewardedShown < AdService.maxRewardedPerSession;

  SessionState copyWith({
    int? searchCount,
    int? interstitialsShown,
    int? rewardedShown,
  }) =>
      SessionState(
        searchCount: searchCount ?? this.searchCount,
        interstitialsShown: interstitialsShown ?? this.interstitialsShown,
        rewardedShown: rewardedShown ?? this.rewardedShown,
        sessionStart: sessionStart,
      );
}

class SessionTracker extends StateNotifier<SessionState> {
  SessionTracker() : super(SessionState(sessionStart: DateTime.now()));

  void incrementSearch() =>
      state = state.copyWith(searchCount: state.searchCount + 1);

  void markInterstitialShown() =>
      state = state.copyWith(interstitialsShown: state.interstitialsShown + 1);

  void markRewardedShown() =>
      state = state.copyWith(rewardedShown: state.rewardedShown + 1);
}
