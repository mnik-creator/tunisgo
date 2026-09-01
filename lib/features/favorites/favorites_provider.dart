// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/helpers/locale_provider.dart';

const _kFavKey = 'favorite_trip_ids';

enum AddFavoriteResult { success, limitReached, alreadyExists }

class FavoriteTripIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getStringList(_kFavKey)?.toSet() ?? {};
  }

  /// Adds [tripId] respecting the per-tier limit.
  /// Returns an [AddFavoriteResult] indicating the outcome.
  Future<AddFavoriteResult> add(String tripId) async {
    if (state.contains(tripId)) return AddFavoriteResult.alreadyExists;

    const maxAllowed = 5;

    if (state.length >= maxAllowed) return AddFavoriteResult.limitReached;

    final updated = {...state, tripId};
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(_kFavKey, updated.toList());
    state = updated;
    return AddFavoriteResult.success;
  }

  Future<void> remove(String tripId) async {
    final updated = {...state}..remove(tripId);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(_kFavKey, updated.toList());
    state = updated;
  }

  /// Legacy toggle — adds if absent (respecting limit), removes if present.
  /// Callers that need to show a paywall should use [add] directly.
  Future<AddFavoriteResult> toggle(String tripId) async {
    if (state.contains(tripId)) {
      await remove(tripId);
      return AddFavoriteResult.success;
    }
    return add(tripId);
  }
}

final favoriteTripIdsProvider =
    NotifierProvider<FavoriteTripIdsNotifier, Set<String>>(
  FavoriteTripIdsNotifier.new,
);
