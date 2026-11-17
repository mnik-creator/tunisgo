// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunis_go/core/helpers/locale_provider.dart';
import 'package:tunis_go/features/favorites/favorites_provider.dart';
import 'package:tunis_go/features/limits/slot_limits_provider.dart';

Future<ProviderContainer> _container([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(sp)]);
}

void main() {
  final t0 = DateTime(2026, 11, 12, 9);

  test('starts at one slot and grows by one per ad up to five', () async {
    final c = await _container();
    final limits = c.read(slotLimitsProvider.notifier);
    expect(limits.limit(SlotKind.favorites, t0), 1);
    for (var i = 0; i < 6; i++) {
      await limits.grant(SlotKind.favorites, t0.add(Duration(days: i % 3)));
    }
    expect(limits.limit(SlotKind.favorites, t0), kMaxSlots);
    expect(limits.canEarnMore(SlotKind.favorites, t0), isFalse);
    expect(limits.limit(SlotKind.reminders, t0), 1, reason: 'kinds are separate');
  });

  test('extra slots all expire 7 days after the first of the cycle', () async {
    final c = await _container();
    final limits = c.read(slotLimitsProvider.notifier);
    await limits.grant(SlotKind.reminders, t0);
    await limits.grant(SlotKind.reminders, t0.add(const Duration(days: 5)));
    expect(limits.limit(SlotKind.reminders, t0.add(const Duration(days: 6))), 3);
    expect(limits.bonusExpiry(SlotKind.reminders, t0), t0.add(kSlotBonusLifetime));
    final after = t0.add(const Duration(days: 7, minutes: 1));
    expect(limits.limit(SlotKind.reminders, after), 1);
    // A new cycle starts from scratch.
    await limits.grant(SlotKind.reminders, after);
    expect(limits.limit(SlotKind.reminders, after), 2);
    expect(limits.bonusExpiry(SlotKind.reminders, after), after.add(kSlotBonusLifetime));
  });

  test('bonus survives a restart', () async {
    final c = await _container();
    final now = DateTime.now();
    await c.read(slotLimitsProvider.notifier).grant(SlotKind.favorites, now);
    final sp = await SharedPreferences.getInstance();
    final c2 = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(sp)]);
    expect(c2.read(slotLimitsProvider.notifier).limit(SlotKind.favorites), 2);
  });

  test('favorites follow the limit and keep what was saved before', () async {
    final c = await _container({'favorite_trip_ids': ['a', 'b', 'c']});
    final favs = c.read(favoriteTripIdsProvider.notifier);
    expect(c.read(favoriteTripIdsProvider), {'a', 'b', 'c'});
    expect(await favs.add('d'), AddFavoriteResult.limitReached);
    await favs.remove('a');
    await favs.remove('b');
    await favs.remove('c');
    expect(await favs.add('d'), AddFavoriteResult.success);
    expect(await favs.add('e'), AddFavoriteResult.limitReached);
  });
}
