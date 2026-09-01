// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/helpers/locale_provider.dart';

const _kScheduledKey = 'scheduled_notification_trip_ids';

class ScheduledNotifTripIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getStringList(_kScheduledKey)?.toSet() ?? {};
  }

  Future<void> add(String tripId) async {
    if (state.contains(tripId)) return;
    final updated = {...state, tripId};
    await ref.read(sharedPreferencesProvider).setStringList(_kScheduledKey, updated.toList());
    state = updated;
  }

  Future<void> remove(String tripId) async {
    final updated = {...state}..remove(tripId);
    await ref.read(sharedPreferencesProvider).setStringList(_kScheduledKey, updated.toList());
    state = updated;
  }
}

final scheduledNotifTripIdsProvider =
    NotifierProvider<ScheduledNotifTripIdsNotifier, Set<String>>(
  ScheduledNotifTripIdsNotifier.new,
);
