// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/providers.dart';
import '../notifications/notifications_service.dart';
import 'favorites_provider.dart';

/// Watches [favoriteTripIdsProvider] and keeps daily departure notifications
/// in sync: schedules on add, cancels on remove.
/// Must be read once at app startup to activate the listener.
final favoritesNotificationsManagerProvider = Provider<void>((ref) {
  ref.listen<Set<String>>(favoriteTripIdsProvider, (previous, next) async {
    final prev = previous ?? {};
    final added = next.difference(prev);
    final removed = prev.difference(next);

    for (final tripId in removed) {
      await NotificationsService.instance.cancel(_dailyId(tripId));
    }

    for (final tripId in added) {
      await _scheduleDailyForTrip(ref, tripId);
    }
  });

  // Schedule notifications for any favorites that already exist at startup.
  _initializeFavoritesNotifications(ref);
});

int _dailyId(String tripId) => 'daily_$tripId'.hashCode;

Future<void> _initializeFavoritesNotifications(Ref ref) async {
  final favorites = ref.read(favoriteTripIdsProvider);
  for (final tripId in favorites) {
    await _scheduleDailyForTrip(ref, tripId);
  }
}

Future<void> _scheduleDailyForTrip(Ref ref, String tripId) async {
  final stopTimes =
      await ref.read(tripRepositoryProvider).getStopTimesForTrip(tripId);
  if (stopTimes.isEmpty) return;
  await NotificationsService.instance.scheduleDailyDepartureNotification(
    id: _dailyId(tripId),
    tripId: tripId,
    trainNumber: tripId,
    departureMinutes: stopTimes.first.departureTime,
  );
}
