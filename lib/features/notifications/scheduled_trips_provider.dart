// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/helpers/locale_provider.dart';
import '../limits/slot_limits_provider.dart';

const _kScheduledKey = 'scheduled_notification_trip_ids';
const _kScheduledTimesKey = 'scheduled_notification_times';

/// One-off departure reminders: trip id → when the reminder fires (null for
/// reminders saved before times were stored). Past reminders drop on load.
class ScheduledNotifTripIdsNotifier extends Notifier<Map<String, DateTime?>> {
  @override
  Map<String, DateTime?> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final ids = prefs.getStringList(_kScheduledKey) ?? const [];
    final raw = prefs.getString(_kScheduledTimesKey);
    final times = raw == null
        ? const <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    final now = DateTime.now();
    final live = <String, DateTime?>{};
    for (final id in ids) {
      final at = DateTime.tryParse('${times[id]}');
      if (at == null || at.isAfter(now)) live[id] = at;
    }
    if (live.length != ids.length) _persist(live);
    return live;
  }

  /// No room under the current slot limit (1, plus slots earned with
  /// rewarded ads — see [slotLimitsProvider]).
  bool get isFull =>
      state.length >= ref.read(slotLimitsProvider.notifier).limit(SlotKind.reminders);

  /// False when the limit is reached.
  Future<bool> add(String tripId, DateTime notifyAt) async {
    if (!state.containsKey(tripId) && isFull) return false;
    final updated = {...state, tripId: notifyAt};
    await _persist(updated);
    state = updated;
    return true;
  }

  Future<void> remove(String tripId) async {
    final updated = {...state}..remove(tripId);
    await _persist(updated);
    state = updated;
  }

  Future<void> _persist(Map<String, DateTime?> entries) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(_kScheduledKey, entries.keys.toList());
    await prefs.setString(
      _kScheduledTimesKey,
      jsonEncode({
        for (final e in entries.entries)
          if (e.value != null) e.key: e.value!.toIso8601String(),
      }),
    );
  }
}

final scheduledNotifTripIdsProvider =
    NotifierProvider<ScheduledNotifTripIdsNotifier, Map<String, DateTime?>>(
  ScheduledNotifTripIdsNotifier.new,
);
