// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/helpers/time_helpers.dart';
import '../../core/models/station.dart';
import '../../core/models/stop_time.dart';
import '../../core/models/trip.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_card.dart';
import '../../l10n/app_localizations.dart';
import '../favorites/favorites_provider.dart';
import '../notifications/notifications_service.dart';
import '../notifications/scheduled_trips_provider.dart';

final _bottomSheetStopTimesProvider =
    FutureProvider.family<List<StopTime>, String>((ref, tripId) {
  return ref.read(tripRepositoryProvider).getStopTimesForTrip(tripId);
});

final _allStationsMapProvider =
    FutureProvider<Map<String, Station>>((ref) async {
  final stations = await ref.read(stationRepositoryProvider).getAllStations();
  return {for (final s in stations) s.id: s};
});

class TripDetailBottomSheet extends ConsumerWidget {
  const TripDetailBottomSheet({required this.trip, super.key});
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final stopTimesAsync = ref.watch(_bottomSheetStopTimesProvider(trip.id));
    final stationsAsync = ref.watch(_allStationsMapProvider);
    final isFavorite = ref.watch(favoriteTripIdsProvider).contains(trip.id);
    final durationMin = trip.arrivalTime - trip.departureTime;
    final hours = durationMin ~/ 60;
    final mins = durationMin % 60;
    final durationStr = hours > 0
        ? '${hours}h${mins.toString().padLeft(2, '0')}'
        : '${mins}min';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1F2937)
                : Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Gradient summary bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          minutesToHHMM(trip.departureTime),
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
                          minutesToHHMM(trip.arrivalTime),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${loc.train_number} ${trip.trainNumber} · $durationStr',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Stop timeline
              Expanded(
                child: stopTimesAsync.when(
                  loading: () => ListView(
                    controller: scrollController,
                    physics: const ClampingScrollPhysics(),
                    children: const [
                      SkeletonCard(height: 60),
                      SkeletonCard(height: 60),
                      SkeletonCard(height: 60),
                    ],
                  ),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (stopTimes) {
                    if (stopTimes.isEmpty) {
                      return EmptyState(
                        icon: Icons.train_outlined,
                        message: loc.no_results,
                      );
                    }
                    return stationsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text(e.toString())),
                      data: (stationsMap) => ListView.builder(
                        controller: scrollController,
                        physics: const ClampingScrollPhysics(),
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
                            index: i,
                            total: stopTimes.length,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              // Action buttons
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: isFavorite ? Icons.star : Icons.star_border,
                        label: loc.save_favorite,
                        color: isFavorite ? Colors.amber : null,
                        onTap: () async {
                          // Already saved → remove
                          if (isFavorite) {
                            ref.read(favoriteTripIdsProvider.notifier).remove(trip.id);
                            return;
                          }

                          final result = await ref
                              .read(favoriteTripIdsProvider.notifier)
                              .add(trip.id);

                          if (result == AddFavoriteResult.success) return;

                          // Hit the free-tier limit
                          if (result == AddFavoriteResult.limitReached &&
                              context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Limite de favoris atteinte'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NotifyButton(trip: trip, stopTimes: null),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StopTimelineTile extends StatelessWidget {
  const _StopTimelineTile({
    required this.stationName,
    required this.stopTime,
    required this.isFirst,
    required this.isLast,
    required this.index,
    required this.total,
  });
  final String stationName;
  final StopTime stopTime;
  final bool isFirst;
  final bool isLast;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    const dotSize = 12.0;
    const lineWidth = 2.0;
    const emerald = kEmerald500;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: lineWidth,
                    color: isFirst ? Colors.transparent : emerald.withValues(alpha: 0.3),
                  ),
                ),
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst || isLast ? emerald : Colors.white,
                    border: Border.all(
                      color: isFirst || isLast ? emerald : emerald.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: lineWidth,
                    color: isLast ? Colors.transparent : emerald.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      stationName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isFirst || isLast
                            ? FontWeight.w600
                            : FontWeight.normal,
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
    );
  }
}

class _NotifyButton extends ConsumerWidget {
  const _NotifyButton({required this.trip, required this.stopTimes});
  final Trip trip;
  final List<StopTime>? stopTimes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isScheduled =
        ref.watch(scheduledNotifTripIdsProvider).contains(trip.id);

    return OutlinedButton.icon(
      icon: Icon(
        isScheduled ? Icons.notifications_active : Icons.notifications_outlined,
        color: isScheduled ? Colors.amber : null,
      ),
      label: Text(loc.notify_me,
          style: TextStyle(color: isScheduled ? Colors.amber : null)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () async {
        if (isScheduled) {
          await NotificationsService.instance.cancel(trip.id.hashCode);
          ref.read(scheduledNotifTripIdsProvider.notifier).remove(trip.id);
          return;
        }
        final service = NotificationsService.instance;
        final granted = await service.requestPermission();
        if (!granted) return;
        final result = await service.scheduleDepartureNotification(
          isPro: true,
          id: trip.id.hashCode,
          tripId: trip.id,
          trainNumber: trip.trainNumber,
          departureMinutes: trip.departureTime,
        );
        if (!context.mounted) return;
        if (result == ScheduleNotificationResult.success) {
          ref.read(scheduledNotifTripIdsProvider.notifier).add(trip.id);
        }
        final msg = switch (result) {
          ScheduleNotificationResult.success => loc.notification_scheduled,
          ScheduleNotificationResult.alreadyPassed =>
            loc.notification_already_passed,
          ScheduleNotificationResult.departureTooSoon =>
            loc.notification_departure_imminent,
          ScheduleNotificationResult.failed => null,
        };
        if (msg != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      },
    );
  }
}
