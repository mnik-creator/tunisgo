// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunis_go/core/helpers/session_tracker_provider.dart';
import 'package:tunis_go/services/ad_service.dart';

void main() {
  // Midday, outside quiet hours (isQuietHours reads the real clock, so only
  // run the timing checks when the test machine is not in 22:00–05:00).
  final noon = DateTime(2026, 11, 12, 12);
  final skip = AdService.isQuietHours ? 'quiet hours on this machine' : null;

  Future<SessionTracker> tracker() async {
    SharedPreferences.setMockInitialValues({});
    return SessionTracker(await SharedPreferences.getInstance());
  }

  test('never on the first search', () async {
    final t = await tracker()..incrementSearch();
    expect(t.canShowInterstitial(noon), isFalse);
    t.incrementSearch();
    expect(t.canShowInterstitial(noon), isTrue);
  }, skip: skip);

  test('minimum gap between interstitials', () async {
    final t = await tracker()..incrementSearch()..incrementSearch();
    t.markInterstitialShown(noon);
    expect(t.canShowInterstitial(noon.add(const Duration(minutes: 3))), isFalse);
    expect(t.canShowInterstitial(noon.add(const Duration(minutes: 4))), isTrue);
  }, skip: skip);

  test('session cap', () async {
    final t = await tracker()..incrementSearch()..incrementSearch();
    var at = noon;
    for (var i = 0; i < AdService.maxInterstitialsPerSession; i++) {
      t.markInterstitialShown(at);
      at = at.add(const Duration(minutes: 10));
    }
    expect(t.canShowInterstitial(at), isFalse);
  }, skip: skip);
}
