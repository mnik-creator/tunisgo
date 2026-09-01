// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages in-app review prompts (App Store / Google Play).
///
/// Triggers after [_triggerAfterSearches] successful searches that returned
/// results, then respects a [_minDaysBetweenRequests]-day cooldown before
/// prompting again. The OS (iOS/Android) has its own final say — it may
/// silently suppress the dialog based on its own quota rules.
class ReviewService {
  static const _kSearchCount = 'review_search_count';
  static const _kLastShownMs = 'review_last_shown_ms';
  static const _triggerAfterSearches = 5;
  static const _minDaysBetweenRequests = 90;

  /// Call after each successful search that returned results.
  ///
  /// Increments the persistent counter. Once the threshold is reached and the
  /// cooldown has passed, requests an in-app review from the OS.
  static Future<void> maybeRequest(SharedPreferences prefs) async {
    final lastShownMs = prefs.getInt(_kLastShownMs);
    if (lastShownMs != null) {
      final daysSince = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastShownMs))
          .inDays;
      if (daysSince < _minDaysBetweenRequests) return;
    }

    final count = (prefs.getInt(_kSearchCount) ?? 0) + 1;
    await prefs.setInt(_kSearchCount, count);

    if (count < _triggerAfterSearches) return;

    final inAppReview = InAppReview.instance;
    if (!await inAppReview.isAvailable()) return;

    await inAppReview.requestReview();

    await prefs.setInt(_kLastShownMs, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_kSearchCount, 0);
  }
}
