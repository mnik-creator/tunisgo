// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunis_go/core/helpers/locale_provider.dart';
import 'package:tunis_go/features/limits/slot_limits_provider.dart';
import 'package:tunis_go/features/notifications/scheduled_trips_provider.dart';

Future<ProviderContainer> _container([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
  );
}

void main() {
  final later = DateTime.now().add(const Duration(hours: 1));

  test('one free reminder, more after earning slots', () async {
    final c = await _container();
    final notifier = c.read(scheduledNotifTripIdsProvider.notifier);
    expect(await notifier.add('0', later), isTrue);
    expect(notifier.isFull, isTrue);
    expect(await notifier.add('extra', later), isFalse);
    // Re-scheduling an existing one is still allowed.
    expect(await notifier.add('0', later), isTrue);

    await c.read(slotLimitsProvider.notifier).grant(SlotKind.reminders);
    expect(await notifier.add('extra', later), isTrue);
    expect(notifier.isFull, isTrue);
    await notifier.remove('0');
    expect(notifier.isFull, isFalse);
  });

  test('drops reminders whose time has passed', () async {
    final past = DateTime.now().subtract(const Duration(minutes: 1));
    final c = await _container({
      'scheduled_notification_trip_ids': ['old', 'new'],
      'scheduled_notification_times': jsonEncode({
        'old': past.toIso8601String(),
        'new': later.toIso8601String(),
      }),
    });
    expect(c.read(scheduledNotifTripIdsProvider).keys, ['new']);
  });
}
