// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/helpers/time_helpers.dart';
import '../../core/models/station.dart';
import '../../core/models/stop_time.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_card.dart';
import '../../l10n/app_localizations.dart';
import '../favorites/favorites_provider.dart';
import '../notifications/notifications_service.dart';
import '../notifications/scheduled_trips_provider.dart';

final _stopTimesProvider =
    FutureProvider.family<List<StopTime>, String>((ref, tripId) {
  return ref.read(tripRepositoryProvider).getStopTimesForTrip(tripId);
});

final _stationsMapProvider =
    FutureProvider<Map<String, Station>>((ref) async {
  final stations = await ref.read(stationRepositoryProvider).getAllStations();
  return {for (final s in stations) s.id: s};
});

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final stopTimesAsync = ref.watch(_stopTimesProvider(tripId));
    final stationsAsync = ref.watch(_stationsMapProvider);
    final isFavorite = ref.watch(favoriteTripIdsProvider).contains(tripId);

    return Scaffold(
      body: Column(
        children: [
          // Gradient summary header
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.star : Icons.star_border,
                        color: Colors.white,
                      ),
                      tooltip: loc.save_favorite,
                      onPressed: () => ref
                          .read(favoriteTripIdsProvider.notifier)
                          .toggle(tripId),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        stopTimesAsync.when(
                          loading: () => const SizedBox(height: 60),
                          error: (e, _) => const SizedBox(height: 60),
                          data: (stops) {
                            if (stops.isEmpty) return const SizedBox(height: 60);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  minutesToHHMM(stops.first.departureTime),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                ),
                                Text(
                                  minutesToHHMM(stops.last.arrivalTime),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${loc.train_number} $tripId',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: stopTimesAsync.when(
              loading: () => ListView(
                children: const [
                  SkeletonCard(height: 60),
                  SkeletonCard(height: 60),
                  SkeletonCard(height: 60),
                ],
              ),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (stopTimes) {
                if (stopTimes.isEmpty) {
                  return EmptyState(icon: Icons.train_outlined, message: loc.no_results);
                }
                return stationsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (stationsMap) => ListView.builder(
                    itemCount: stopTimes.length,
                    itemBuilder: (context, i) {
                      final st = stopTimes[i];
                      final station = stationsMap[st.stationId];
                      final stationName = station?.nameFr ?? 'Station #${st.stationId}';
                      final isFirst = i == 0;
                      final isLast = i == stopTimes.length - 1;
                      return _StopTimelineTile(
                        stationName: stationName,
                        stopTime: st,
                        isFirst: isFirst,
                        isLast: isLast,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: stopTimesAsync.whenOrNull(
        data: (stopTimes) => stopTimes.isNotEmpty
            ? _NotifyFab(tripId: tripId, stopTimes: stopTimes)
            : null,
      ),
    );
  }
}

class _StopTimelineTile extends StatelessWidget {
  const _StopTimelineTile({
    required this.stationName,
    required this.stopTime,
    required this.isFirst,
    required this.isLast,
  });
  final String stationName;
  final StopTime stopTime;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    const dotSize = 12.0;
    const lineWidth = 2.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: lineWidth,
                      color: isFirst ? Colors.transparent : kEmerald500.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst || isLast ? kEmerald500 : Colors.white,
                    border: Border.all(
                      color: isFirst || isLast ? kEmerald500 : kEmerald500.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: lineWidth,
                      color: isLast ? Colors.transparent : kEmerald500.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      stationName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isFirst || isLast ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        minutesToHHMM(stopTime.arrivalTime),
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (stopTime.departureTime != stopTime.arrivalTime)
                        Text(
                          minutesToHHMM(stopTime.departureTime),
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifyFab extends ConsumerWidget {
  const _NotifyFab({required this.tripId, required this.stopTimes});
  final String tripId;
  final List<StopTime> stopTimes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isScheduled =
        ref.watch(scheduledNotifTripIdsProvider).contains(tripId);

    return FloatingActionButton.extended(
      backgroundColor: isScheduled ? Colors.amber : null,
      foregroundColor: isScheduled ? Colors.white : null,
      icon: Icon(isScheduled
          ? Icons.notifications_active
          : Icons.notifications_outlined),
      label: Text(loc.notify_me),
      onPressed: () => isScheduled
          ? _cancelNotification(context, ref)
          : _scheduleNotification(context, ref, loc),
    );
  }

  Future<void> _cancelNotification(BuildContext context, WidgetRef ref) async {
    await NotificationsService.instance.cancel(tripId.hashCode);
    ref.read(scheduledNotifTripIdsProvider.notifier).remove(tripId);
  }

  Future<void> _scheduleNotification(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations loc,
  ) async {
    final service = NotificationsService.instance;
    final granted = await service.requestPermission();
    if (!granted) return;
    final result = await service.scheduleDepartureNotification(
      isPro: true,
      id: tripId.hashCode,
      tripId: tripId,
      trainNumber: tripId,
      departureMinutes: stopTimes.first.departureTime,
    );
    if (!context.mounted) return;
    if (result == ScheduleNotificationResult.success) {
      ref.read(scheduledNotifTripIdsProvider.notifier).add(tripId);
    }
    final msg = switch (result) {
      ScheduleNotificationResult.success => loc.notification_scheduled,
      ScheduleNotificationResult.alreadyPassed => loc.notification_already_passed,
      ScheduleNotificationResult.departureTooSoon =>
        loc.notification_departure_imminent,
      ScheduleNotificationResult.failed => null,
    };
    if (msg != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}
