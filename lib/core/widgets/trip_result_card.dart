// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';

import '../helpers/time_helpers.dart';
import '../models/trip.dart';
import '../theme/line_colors.dart';
import '../../l10n/app_localizations.dart';
import 'train_type_badge.dart';

class TripResultCard extends StatelessWidget {
  const TripResultCard({required this.trip, required this.onTap, super.key});

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final durationMin = trip.arrivalTime - trip.departureTime;
    final hours = durationMin ~/ 60;
    final mins = durationMin % 60;
    final durationStr = hours > 0
        ? '${hours}h${mins.toString().padLeft(2, '0')}'
        : '${mins}min';
    final lineColor = LineColors.forCategory(
      LineColors.fromLineId(trip.lineId),
    );

    final isLate = trip.mayArriveLate;
    final cardColor = isLate
        ? (isDark
            ? const Color(0xFF2D2007)
            : const Color(0xFFFFF8EC))
        : (isDark ? const Color(0xFF1F2937) : Colors.white);
    final borderColor = isLate
        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
        : Colors.transparent;

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
            if (isLate) ...[
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 13,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    loc.may_arrive_late,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD97706),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Text(
                  minutesToHHMM(trip.departureTime),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: isLate ? const Color(0xFFD97706) : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: isLate
                        ? const Color(0xFFD97706).withValues(alpha: 0.7)
                        : Colors.grey.shade400,
                  ),
                ),
                Text(
                  minutesToHHMM(trip.arrivalTime),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: isLate ? const Color(0xFFD97706) : null,
                  ),
                ),
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
                      Text(
                        durationStr,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      Text(
                        '· ${servicesDaysLabel(trip.serviceDays, loc)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
