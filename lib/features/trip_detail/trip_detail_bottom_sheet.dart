// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/live_config.dart';
import '../../core/helpers/time_helpers.dart';
import '../../core/models/station.dart';
import '../../core/models/stop_time.dart';
import '../../core/models/trip.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_card.dart';
import '../../l10n/app_localizations.dart';
import '../../services/share_service.dart';
import '../favorites/favorites_provider.dart';
import '../limits/earn_slot.dart';
import '../limits/slot_limits_provider.dart';
import '../live/live_board.dart';
import '../live/live_models.dart';
import '../live/live_providers.dart';
import '../notifications/notifications_service.dart';
import '../notifications/notify_lead_picker.dart';
import '../notifications/scheduled_trips_provider.dart';

final _bottomSheetStopTimesProvider =
    FutureProvider.family<List<StopTime>, String>((ref, tripId) {
      return ref.read(tripRepositoryProvider).getStopTimesForTrip(tripId);
    });

final _allStationsMapProvider = FutureProvider<Map<String, Station>>((
  ref,
) async {
  final stations = await ref.read(stationRepositoryProvider).getAllStations();
  return {for (final s in stations) s.id: s};
});

class TripDetailBottomSheet extends ConsumerWidget {
  const TripDetailBottomSheet({
    required this.trip,
    this.isToday = true,
    super.key,
  });
  final Trip trip;

  /// Only today's trips get a train position on the timeline.
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final stopTimesAsync = ref.watch(_bottomSheetStopTimesProvider(trip.id));
    final stationsAsync = ref.watch(_allStationsMapProvider);
    final isFavorite = ref.watch(favoriteTripIdsProvider).contains(trip.id);
    final liveIndex = LiveConfig.isEnabled
        ? ref.watch(liveTrainIndexProvider)
        : const <String, List<LiveTrain>>{};
    // Wraps past midnight (23:45 -> 00:23 is 38 min, not -23h).
    final durationMin = (trip.arrivalTime - trip.departureTime) % (24 * 60);
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
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
                              child: Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 20,
                              ),
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
                        if (isEstimatedTrip(trip.tripCode)) ...[
                          const SizedBox(height: 6),
                          Text(
                            loc.schedule_estimated,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                    PositionedDirectional(
                      end: -12,
                      top: -10,
                      child: Builder(
                        builder: (buttonContext) => IconButton(
                          tooltip: loc.share,
                          icon: Icon(Icons.adaptive.share, color: Colors.white),
                          onPressed: () => shareText(
                            buttonContext,
                            _shareMessage(
                              loc,
                              stopTimesAsync.valueOrNull ?? const [],
                              stationsAsync.valueOrNull ?? const {},
                            ),
                          ),
                        ),
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
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text(e.toString())),
                      data: (stationsMap) {
                        // French names match the live feed; riders see
                        // their own language.
                        final names = [
                          for (final st in stopTimes)
                            stationsMap[st.stationId]?.nameFr ??
                                'Station #${st.stationId}',
                        ];
                        final shownNames = [
                          for (final (i, st) in stopTimes.indexed)
                            stationsMap[st.stationId]?.localizedName(
                                  loc.localeName,
                                ) ??
                                names[i],
                        ];
                        final located = isToday
                            ? _trainPosition(liveIndex, stopTimes, names)
                            : null;
                        final pos = located?.$1;
                        final passed = pos?.lastPassed ?? -1;
                        final atStation = pos?.atStation ?? false;
                        // A train between stops gets its own row halfway along.
                        final markerRow = pos != null && !atStation
                            ? passed + 1
                            : -1;
                        // Row 0 says where the position comes from.
                        final head = located != null ? 1 : 0;
                        return ListView.builder(
                          controller: scrollController,
                          physics: const ClampingScrollPhysics(),
                          itemCount:
                              head +
                              stopTimes.length +
                              (markerRow >= 0 ? 1 : 0),
                          itemBuilder: (context, listRow) {
                            if (head == 1 && listRow == 0) {
                              return _PositionSourceNote(isLive: located!.$2);
                            }
                            final row = listRow - head;
                            if (row == markerRow) {
                              return const _TrainBetweenStopsRow();
                            }
                            final i = markerRow >= 0 && row > markerRow
                                ? row - 1
                                : row;
                            return _StopTimelineTile(
                              stationName: shownNames[i],
                              stopTime: stopTimes[i],
                              isFirst: i == 0,
                              isLast: i == stopTimes.length - 1,
                              index: i,
                              total: stopTimes.length,
                              isPassed: i <= passed,
                              hasTrain: atStation && i == passed,
                              lineBelowPassed:
                                  i < passed || (i == passed && !atStation),
                            );
                          },
                        );
                      },
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
                            ref
                                .read(favoriteTripIdsProvider.notifier)
                                .remove(trip.id);
                            return;
                          }

                          // Full → offer a rewarded ad for one more slot.
                          final hasRoom = await ensureSlot(
                            context,
                            ref,
                            SlotKind.favorites,
                            ref.read(favoriteTripIdsProvider).length,
                          );
                          if (!hasRoom) return;
                          await ref
                              .read(favoriteTripIdsProvider.notifier)
                              .add(trip.id);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _NotifyButton(trip: trip, stopTimes: null)),
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

extension on TripDetailBottomSheet {
  /// "🚆 Train 5/87: Tunis 17:20 → Sousse 19:59" plus a link to the app.
  /// The rider's own stops are the ones matching this trip's times; the
  /// train's end stations stand in while stop times are still loading.
  String _shareMessage(
    AppLocalizations loc,
    List<StopTime> stopTimes,
    Map<String, Station> stations,
  ) {
    String nameAt(int i) =>
        stations[stopTimes[i].stationId]?.localizedName(loc.localeName) ?? '';
    var from = trip.fromStationName ?? '';
    var to = '';
    if (stopTimes.isNotEmpty) {
      var fi = stopTimes.indexWhere(
        (s) => s.departureTime == trip.departureTime,
      );
      if (fi < 0) fi = 0;
      var ti = stopTimes.lastIndexWhere(
        (s) => s.arrivalTime == trip.arrivalTime,
      );
      if (ti <= fi) ti = stopTimes.length - 1;
      from = nameAt(fi).isNotEmpty ? nameAt(fi) : from;
      to = nameAt(ti);
    }
    final line = loc.share_trip_text(
      trip.trainNumber,
      from,
      minutesToHHMM(trip.departureTime),
      to,
      minutesToHHMM(trip.arrivalTime),
    );
    return '$line\n${loc.share_trip_footer}';
  }

  /// Where this trip's train is now, and whether that comes from the live
  /// feed (true) or from the timetable clock (false). The feed is used once
  /// SNCFT reports the train as running; until then — and for trains the feed
  /// does not track at all — the position follows the printed times.
  (TrainPosition, bool)? _trainPosition(
    Map<String, List<LiveTrain>> liveIndex,
    List<StopTime> stopTimes,
    List<String> names,
  ) {
    final now = tunisNowMinutes();
    final call = liveIndex.isEmpty || trip.tripCode.isEmpty
        ? null
        : matchTimetableRow(
            liveIndex,
            tripCode: trip.tripCode,
            dbStationName: trip.fromStationName ?? names.first,
            plannedHhmm: minutesToHHMM(
              trip.fromStationName != null
                  ? trip.departureTime
                  : stopTimes.first.departureTime,
            ),
          );
    if (call != null) {
      if (call.isCancelled) return null;
      if (call.train.isRunning || call.train.isFinished) {
        final live = positionAlongStops(call.train, names, nowMinutes: now);
        if (live != null) return (live, true);
      }
    }
    final scheduled = positionBySchedule(
      [for (final st in stopTimes) st.arrivalTime],
      [for (final st in stopTimes) st.departureTime],
      nowMinutes: now,
      delayMinutes: call?.train.isRunning == true
          ? call!.train.delayMinutes
          : 0,
    );
    return scheduled == null ? null : (scheduled, false);
  }
}

/// One line above the timeline: live position or estimated from the timetable.
class _PositionSourceNote extends StatelessWidget {
  const _PositionSourceNote({required this.isLive});
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final color = isLive ? kEmerald500 : Colors.grey.shade600;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          Icon(isLive ? Icons.sensors : Icons.schedule, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isLive ? loc.position_live : loc.position_by_schedule,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _trainMarkerSize = 22.0;

/// Filled dot with a ring around it: where the train is now.
class _TrainMarker extends StatelessWidget {
  const _TrainMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _trainMarkerSize,
      height: _trainMarkerSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kEmerald500.withValues(alpha: 0.18),
        border: Border.all(color: kEmerald500, width: 2),
      ),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: kEmerald500,
        ),
      ),
    );
  }
}

class _TrainBetweenStopsRow extends StatelessWidget {
  const _TrainBetweenStopsRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Expanded(child: Container(width: 2, color: kEmerald500)),
                const _TrainMarker(),
                Expanded(
                  child: Container(
                    width: 2,
                    color: kEmerald500.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    required this.index,
    required this.total,
    this.isPassed = false,
    this.hasTrain = false,
    this.lineBelowPassed = false,
  });
  final String stationName;
  final StopTime stopTime;
  final bool isFirst;
  final bool isLast;
  final int index;
  final int total;

  /// The train has reached this stop: green dot and line, grey name.
  final bool isPassed;

  /// The train is standing at this stop.
  final bool hasTrain;

  /// The line below this stop is already covered.
  final bool lineBelowPassed;

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
                    color: isFirst
                        ? Colors.transparent
                        : isPassed
                        ? emerald
                        : emerald.withValues(alpha: 0.3),
                  ),
                ),
                if (hasTrain)
                  const _TrainMarker()
                else
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPassed || isFirst || isLast
                          ? emerald
                          : Colors.white,
                      border: Border.all(
                        color: isPassed || isFirst || isLast
                            ? emerald
                            : emerald.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  ),
                Expanded(
                  child: Container(
                    width: lineWidth,
                    color: isLast
                        ? Colors.transparent
                        : lineBelowPassed
                        ? emerald
                        : emerald.withValues(alpha: 0.3),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stationName,
                          style: TextStyle(
                            fontSize: 14,
                            color: isPassed ? Colors.grey.shade500 : null,
                            fontWeight: isFirst || isLast
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        // Served only on some days (poster `*`), e.g. Trika.
                        if (stopTime.stopDays case final days?)
                          Text(
                            AppLocalizations.of(context).stop_only_on(
                              servicesDaysLabel(
                                days,
                                AppLocalizations.of(context),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFD97706),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        minutesToHHMM(stopTime.arrivalTime),
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                          color: isPassed ? Colors.grey.shade500 : null,
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
    final isScheduled = ref
        .watch(scheduledNotifTripIdsProvider)
        .containsKey(trip.id);

    return OutlinedButton.icon(
      icon: Icon(
        isScheduled ? Icons.notifications_active : Icons.notifications_outlined,
        color: isScheduled ? Colors.amber : null,
      ),
      label: Text(
        loc.notify_me,
        style: TextStyle(color: isScheduled ? Colors.amber : null),
      ),
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
        final hasRoom = await ensureSlot(
          context,
          ref,
          SlotKind.reminders,
          ref.read(scheduledNotifTripIdsProvider).length,
        );
        if (!hasRoom || !context.mounted) return;
        final lead = await pickNotifyLeadMinutes(context, trip.departureTime);
        if (lead == null || !context.mounted) return;
        final service = NotificationsService.instance;
        final granted = await service.requestPermission();
        if (!granted) return;
        final result = await service.scheduleDepartureNotification(
          isPro: true,
          id: trip.id.hashCode,
          tripId: trip.id,
          trainNumber: trip.trainNumber,
          departureMinutes: trip.departureTime,
          minutesBefore: lead,
        );
        if (!context.mounted) return;
        if (result == ScheduleNotificationResult.success) {
          final today = DateTime.now();
          await ref
              .read(scheduledNotifTripIdsProvider.notifier)
              .add(
                trip.id,
                DateTime(
                  today.year,
                  today.month,
                  today.day,
                ).add(Duration(minutes: trip.departureTime - lead)),
              );
        }
        final msg = switch (result) {
          ScheduleNotificationResult.success => loc.notification_scheduled_at(
            minutesToHHMM(trip.departureTime - lead),
          ),
          ScheduleNotificationResult.alreadyPassed =>
            loc.notification_already_passed,
          ScheduleNotificationResult.departureTooSoon =>
            loc.notification_time_passed,
          ScheduleNotificationResult.failed => null,
        };
        if (msg != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      },
    );
  }
}
