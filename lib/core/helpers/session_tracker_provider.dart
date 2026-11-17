// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/ad_service.dart';
import 'locale_provider.dart';

const _kLastInterstitial = 'ads_last_interstitial_at';
const _kDayCount = 'ads_interstitial_day_count';

final sessionTrackerProvider =
    StateNotifierProvider<SessionTracker, SessionState>((ref) {
  return SessionTracker(ref.read(sharedPreferencesProvider));
});

class SessionState {
  final int searchCount;
  final int interstitialsShown;
  final DateTime sessionStart;

  const SessionState({
    this.searchCount = 0,
    this.interstitialsShown = 0,
    required this.sessionStart,
  });

  SessionState copyWith({
    int? searchCount,
    int? interstitialsShown,
  }) =>
      SessionState(
        searchCount: searchCount ?? this.searchCount,
        interstitialsShown: interstitialsShown ?? this.interstitialsShown,
        sessionStart: sessionStart,
      );
}

class SessionTracker extends StateNotifier<SessionState> {
  SessionTracker(this._prefs) : super(SessionState(sessionStart: DateTime.now()));

  final SharedPreferences _prefs;

  void incrementSearch() =>
      state = state.copyWith(searchCount: state.searchCount + 1);

  /// Interstitial pacing — see [AdService] for the numbers.
  bool canShowInterstitial([DateTime? now]) {
    final t = now ?? DateTime.now();
    if (AdService.isQuietHours) return false;
    if (state.searchCount < AdService.interstitialFromSearch) return false;
    if (state.interstitialsShown >= AdService.maxInterstitialsPerSession) return false;
    final last = DateTime.tryParse(_prefs.getString(_kLastInterstitial) ?? '');
    if (last != null && t.difference(last) < AdService.interstitialMinGap) return false;
    return _todayCount(t) < AdService.maxInterstitialsPerDay;
  }

  void markInterstitialShown([DateTime? now]) {
    final t = now ?? DateTime.now();
    _prefs.setString(_kLastInterstitial, t.toIso8601String());
    _prefs.setString(_kDayCount, '${_day(t)}:${_todayCount(t) + 1}');
    state = state.copyWith(interstitialsShown: state.interstitialsShown + 1);
  }

  /// A rewarded ad the rider just watched also counts for the interstitial
  /// gap, so it is never followed by a forced one.
  void markRewardedShown([DateTime? now]) =>
      _prefs.setString(_kLastInterstitial, (now ?? DateTime.now()).toIso8601String());

  int _todayCount(DateTime t) {
    final parts = (_prefs.getString(_kDayCount) ?? '').split(':');
    return parts.length == 2 && parts[0] == _day(t) ? int.tryParse(parts[1]) ?? 0 : 0;
  }

  static String _day(DateTime t) => '${t.year}-${t.month}-${t.day}';
}
