// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/helpers/time_helpers.dart';
import '../../core/models/station.dart';
import '../../core/models/trip.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_card.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ads/native_ad_widget.dart';

final _stationByCodeProvider =
    FutureProvider.family<Station?, String>((ref, code) async {
  final all = await ref.read(stationRepositoryProvider).getAllStations();
  for (final s in all) {
    if (s.slug == code) return s;
  }
  return null;
});

final _departuresProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, stationId) {
  return ref.read(tripRepositoryProvider).getDeparturesForStation(stationId);
});

enum _Direction { toTunis, toErriadh }

class StationScheduleScreen extends ConsumerStatefulWidget {
  const StationScheduleScreen({required this.stationCode, super.key});

  final String stationCode;

  @override
  ConsumerState<StationScheduleScreen> createState() =>
      _StationScheduleScreenState();
}

class _StationScheduleScreenState
    extends ConsumerState<StationScheduleScreen> {
  _Direction _direction = _Direction.toTunis;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final stationAsync = ref.watch(_stationByCodeProvider(widget.stationCode));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 16,
              bottom: 12,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: stationAsync.when(
                    data: (s) => Text(
                      s?.nameFr ?? widget.stationCode,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    loading: () => Text(widget.stationCode),
                    error: (_, _) => Text(widget.stationCode),
                  ),
                ),
              ],
            ),
          ),
          // Direction toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _DirectionToggle(
              direction: _direction,
              loc: loc,
              onChanged: (d) => setState(() => _direction = d),
            ),
          ),
          Expanded(
            child: stationAsync.when(
              loading: () => ListView(
                children: const [
                  SkeletonCard(height: 70),
                  SkeletonCard(height: 70),
                  SkeletonCard(height: 70),
                ],
              ),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (station) {
                if (station == null) {
                  return EmptyState(
                    icon: Icons.train_outlined,
                    message: loc.no_results,
                  );
                }
                return _DepartureList(stationId: station.id, loc: loc, isDark: isDark);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionToggle extends StatelessWidget {
  const _DirectionToggle({
    required this.direction,
    required this.loc,
    required this.onChanged,
  });
  final _Direction direction;
  final AppLocalizations loc;
  final ValueChanged<_Direction> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TogglePill(
              label: loc.direction_to_tunis,
              selected: direction == _Direction.toTunis,
              onTap: () => onChanged(_Direction.toTunis),
            ),
          ),
          Expanded(
            child: _TogglePill(
              label: loc.direction_to_erriadh,
              selected: direction == _Direction.toErriadh,
              onTap: () => onChanged(_Direction.toErriadh),
            ),
          ),
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kEmerald500 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _DepartureList extends ConsumerWidget {
  const _DepartureList({
    required this.stationId,
    required this.loc,
    required this.isDark,
  });

  final String stationId;
  final AppLocalizations loc;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departuresAsync = ref.watch(_departuresProvider(stationId));

    return departuresAsync.when(
      loading: () => ListView(
        children: const [
          SkeletonCard(height: 70),
          SkeletonCard(height: 70),
          SkeletonCard(height: 70),
        ],
      ),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (rows) {
        final now = DateTime.now();
        final nowMinutes = now.hour * 60 + now.minute;
        final filtered = rows.where((row) {
          final dep = hhmmToMinutes(row['departure_time'] as String);
          return dep >= nowMinutes - 15;
        }).toList();

        if (filtered.isEmpty) {
          return EmptyState(icon: Icons.train_outlined, message: loc.no_results);
        }
        const adSlot = 4;
        final hasNativeSlot = filtered.length > adSlot;
        final itemCount = filtered.length + (hasNativeSlot ? 1 : 0);
        return ListView.builder(
          itemCount: itemCount,
          itemBuilder: (context, i) {
            if (hasNativeSlot && i == adSlot) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: NativeAdWidget(),
              );
            }
            final rowIndex = hasNativeSlot && i > adSlot ? i - 1 : i;
            final row = filtered[rowIndex];
            final tripId = row['trip_id'] as String;
            final rawTripCode = row['train_number'] as String;
            final trainNumber = extractTrainNumber(rawTripCode);
            final departureMinutes =
                hhmmToMinutes(row['departure_time'] as String);
            final serviceDays = tripServiceDaysBitmask(
              row['service_id'] as String?,
              rawTripCode,
            );

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: const Icon(Icons.train_outlined, color: kEmerald500),
                title: Text(
                  minutesToHHMM(departureMinutes),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                subtitle: Text(
                  '${loc.train_number} $trainNumber · ${servicesDaysLabel(serviceDays, loc)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
                onTap: () => context.goNamed('trip', pathParameters: {'id': tripId}),
              ),
            );
          },
        );
      },
    );
  }
}
