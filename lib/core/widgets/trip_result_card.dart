// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/live_config.dart';
import '../../features/live/live_board.dart';
import '../../features/live/live_board_sheet.dart';
import '../../features/live/live_models.dart';
import '../../features/live/live_providers.dart';
import '../helpers/time_helpers.dart';
import '../models/trip.dart';
import '../theme/line_colors.dart';
import '../../l10n/app_localizations.dart';
import 'train_type_badge.dart';

class TripResultCard extends ConsumerWidget {
  const TripResultCard({required this.trip, required this.onTap, super.key});

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final liveIndex = LiveConfig.isEnabled
        ? ref.watch(liveTrainIndexProvider)
        : const <String, List<LiveTrain>>{};
    final live = trip.fromStationName == null || trip.tripCode.isEmpty
        ? null
        : matchTimetableRow(
            liveIndex,
            tripCode: trip.tripCode,
            dbStationName: trip.fromStationName!,
            plannedHhmm: minutesToHHMM(trip.departureTime),
          );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Wraps past midnight (23:45 -> 00:23 is 38 min, not -23h).
    final durationMin = (trip.arrivalTime - trip.departureTime) % (24 * 60);
    final hours = durationMin ~/ 60;
    final mins = durationMin % 60;
    final durationStr = hours > 0
        ? '${hours}h${mins.toString().padLeft(2, '0')}'
        : '${mins}min';
    final lineColor = LineColors.forCategory(
      isEstimatedTrip(trip.tripCode)
          ? LineCategory.transtu
          : LineColors.fromLineId(trip.lineId),
    );

    final isLate = trip.mayArriveLate;
    final isCancelled = live?.isCancelled ?? false;
    // Cancelled wins over late: the rider must not wait for this train.
    final accent = isCancelled
        ? const Color(0xFFDC2626)
        : isLate
        ? const Color(0xFFD97706)
        : null;
    final cardColor = isCancelled
        ? (isDark ? const Color(0xFF2D0A0A) : const Color(0xFFFEF2F2))
        : isLate
        ? (isDark ? const Color(0xFF2D2007) : const Color(0xFFFFF8EC))
        : (isDark ? const Color(0xFF1F2937) : Colors.white);
    final borderColor = isCancelled
        ? const Color(0xFFDC2626).withValues(alpha: 0.5)
        : isLate
        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
        : Colors.transparent;
    final timeStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
      color: accent,
      decoration: isCancelled ? TextDecoration.lineThrough : null,
      decorationColor: accent,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLate || isCancelled) ...[
              Row(
                children: [
                  Icon(
                    isCancelled ? Icons.cancel_outlined : Icons.schedule,
                    size: 13,
                    color: accent,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      isCancelled
                          ? loc.live_cancelled_header
                          : live != null && live.eta != null
                          ? loc.live_running_late(live.delayMinutes, live.eta!)
                          : loc.may_arrive_late,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: accent,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ] else if (isEstimatedTrip(trip.tripCode)) ...[
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 13,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      loc.schedule_estimated,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Text(minutesToHHMM(trip.departureTime), style: timeStyle),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color:
                        accent?.withValues(alpha: 0.7) ?? Colors.grey.shade400,
                  ),
                ),
                Text(minutesToHHMM(trip.arrivalTime), style: timeStyle),
                const Spacer(),
                TrainTypeBadge(type: trip.trainType),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: lineColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        trip.fullTrainNumber,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (live != null) LiveStatusBadge(call: live, loc: loc),
                      Text(
                        durationStr,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '· ${servicesDaysLabel(trip.serviceDays, loc)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trip.approximatePrice != null)
                  Container(
                    margin: const EdgeInsetsDirectional.only(start: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '~${trip.approximatePrice!.toStringAsFixed(2)} TND',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
