// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/helpers/locale_provider.dart';
import '../../core/helpers/time_helpers.dart';
import '../../core/models/line.dart';
import '../../core/models/station.dart';
import '../../core/models/trip.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/line_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_card.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ads/native_ad_widget.dart';

final _allLinesProvider = FutureProvider<List<Line>>((ref) {
  return ref.read(lineRepositoryProvider).getAllLines();
});

// Full schedule data: stations + trips + time matrix
class _ScheduleData {
  const _ScheduleData({
    required this.stations,
    required this.trips,
    required this.times,
  });
  final List<Station> stations;
  final List<Trip> trips;
  // tripId → stationId → "HH:MM" (empty string if no stop)
  final Map<String, Map<String, String>> times;
}

final _lineScheduleProvider = FutureProvider.family<
    _ScheduleData,
    ({String lineId, String? reverseId, int direction})>((ref, params) async {
  // When direction=1 and a reverse route exists, use that route's data
  // (direction=0) so we get the real reverse-direction trips and stations.
  final effectiveLineId =
      (params.direction == 1 && params.reverseId != null)
      ? params.reverseId!
      : params.lineId;
  final effectiveDirection =
      (params.direction == 1 && params.reverseId != null) ? 0 : params.direction;

  final stationPairs = await ref
      .read(lineRepositoryProvider)
      .getStationsForLine(effectiveLineId, direction: effectiveDirection);
  final stations = stationPairs.map((p) => p.station).toList();
  final trips = await ref
      .read(tripRepositoryProvider)
      .getTripsForLine(effectiveLineId, direction: effectiveDirection);

  final timesMap = <String, Map<String, String>>{};
  for (final trip in trips) {
    final stopTimes = await ref
        .read(tripRepositoryProvider)
        .getStopTimesForTrip(trip.id);
    timesMap[trip.id] = {};
    for (final st in stopTimes) {
      timesMap[trip.id]![st.stationId] = minutesToHHMM(st.departureTime);
    }
  }
  return _ScheduleData(stations: stations, trips: trips, times: timesMap);
});

class LinesScreen extends ConsumerWidget {
  const LinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final linesAsync = ref.watch(_allLinesProvider);

    return linesAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ScreenTitle(title: loc.lines_tab_title),
          const SizedBox(height: 16),
          const SkeletonCard(height: 60),
          const SkeletonCard(height: 60),
          const SkeletonCard(height: 60),
        ],
      ),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (lines) {
        if (lines.isEmpty) {
          return EmptyState(
            icon: Icons.train_outlined,
            message: loc.no_results,
          );
        }

        final mainLines = lines
            .where(
              (l) =>
                  LineColors.fromLineCategory(l.lineCategory) ==
                  LineCategory.main,
            )
            .toList();
        final subTunisLines = lines
            .where(
              (l) =>
                  LineColors.fromLineCategory(l.lineCategory) ==
                  LineCategory.suburbanTunis,
            )
            .toList();
        final subSahelLines = lines
            .where(
              (l) =>
                  LineColors.fromLineCategory(l.lineCategory) ==
                  LineCategory.suburbanSahel,
            )
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _ScreenTitle(title: loc.lines_tab_title),
            const SizedBox(height: 20),
            if (mainLines.isNotEmpty) ...[
              _CategoryHeader(
                label: loc.line_main,
                color: LineColors.forCategory(LineCategory.main),
              ),
              const SizedBox(height: 8),
              ...mainLines.map((l) => _LineCard(line: l)),
              const SizedBox(height: 20),
            ],
            if (mainLines.isNotEmpty && subTunisLines.isNotEmpty)
              const NativeAdWidget(),
            if (subTunisLines.isNotEmpty) ...[
              _CategoryHeader(
                label: loc.line_suburban_tunis,
                color: LineColors.forCategory(LineCategory.suburbanTunis),
              ),
              const SizedBox(height: 8),
              ...subTunisLines.map((l) => _LineCard(line: l)),
              const SizedBox(height: 20),
            ],
            if (subSahelLines.isNotEmpty) ...[
              _CategoryHeader(
                label: loc.line_suburban_sahel,
                color: LineColors.forCategory(LineCategory.suburbanSahel),
              ),
              const SizedBox(height: 8),
              ...subSahelLines.map((l) => _LineCard(line: l)),
            ],
          ],
        );
      },
    );
  }
}

class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}

// ─── Line Card — tap opens schedule sheet directly ────────────────────────────

class _LineCard extends ConsumerWidget {
  const _LineCard({required this.line});
  final Line line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    final lineColor = LineColors.forCategory(
      LineColors.fromLineCategory(line.lineCategory),
    );

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ScheduleBottomSheet(line: line, lineColor: lineColor),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: lineColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                line.localizedName(locale.languageCode),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Schedule Bottom Sheet ────────────────────────────────────────────────────

enum _Direction {
  forward(0), // Tunis → Erriadh
  backward(1); // Erriadh → Tunis

  const _Direction(this.value);
  final int value;
}

class _ScheduleBottomSheet extends ConsumerStatefulWidget {
  const _ScheduleBottomSheet({required this.line, required this.lineColor});
  final Line line;
  final Color lineColor;

  @override
  ConsumerState<_ScheduleBottomSheet> createState() =>
      _ScheduleBottomSheetState();
}

class _ScheduleBottomSheetState extends ConsumerState<_ScheduleBottomSheet> {
  _Direction _direction = _Direction.forward;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Always watch forward direction so toggle labels remain stable.
    final forwardAsync = ref.watch(
      _lineScheduleProvider((
        lineId: widget.line.id,
        reverseId: widget.line.reverseId,
        direction: 0,
      )),
    );
    final scheduleAsync = ref.watch(
      _lineScheduleProvider((
        lineId: widget.line.id,
        reverseId: widget.line.reverseId,
        direction: _direction.value,
      )),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
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

              // Header: line name + stop count + duration
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Close button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF374151)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.line.localizedName(locale.languageCode),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    scheduleAsync.whenData((data) {
                          final count = data.stations.length;
                          final dur = _totalDuration(data);
                          final loc = AppLocalizations.of(context);
                          final durStr = dur > 0
                              ? '~${dur ~/ 60}h${dur % 60 > 0 ? ' ${dur % 60}min' : ''}'
                              : '';
                          return Text(
                            '$count ${loc.schedule_stops}${durStr.isNotEmpty ? ' · $durStr' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          );
                        }).value ??
                        const SizedBox.shrink(),
                  ],
                ),
              ),

              // Info banner (line color tinted)
              scheduleAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (data) {
                  final daysInfo = _getTrafficDaysSummary(data.trips);
                  if (daysInfo.isEmpty) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: widget.lineColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: widget.lineColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.train,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).schedule_source,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                              ),
                              if (daysInfo.isNotEmpty)
                                Text(
                                  daysInfo,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),

              // Direction toggle — only shown for bidirectional routes.
              if (widget.line.reverseId != null)
                forwardAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (fwdData) {
                    if (fwdData.stations.length < 2) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: _DirectionToggle(
                        direction: _direction,
                        stations: fwdData.stations,
                        locale: locale.languageCode,
                        onChanged: (d) => setState(() => _direction = d),
                      ),
                    );
                  },
                ),

              Container(
                height: 1,
                color: isDark ? const Color(0xFF374151) : Colors.grey.shade200,
              ),

              // Schedule grid
              Expanded(
                child: scheduleAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (data) {
                    if (data.trips.isEmpty) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context).schedule_no_trains,
                        ),
                      );
                    }
                    return _ScheduleGrid(
                      data: data,
                      lineColor: widget.lineColor,
                      langCode: locale.languageCode,
                      scrollController: scrollController,
                    );
                  },
                ),
              ),

              // Footer legend + close
              _SheetFooter(
                lineColor: widget.lineColor,
                isDark: isDark,
                onClose: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  int _totalDuration(_ScheduleData data) {
    if (data.trips.isEmpty || data.stations.isEmpty) return 0;
    final firstTrip = data.times[data.trips.first.id] ?? {};
    int? start;
    int last = 0;
    for (final s in data.stations) {
      final t = firstTrip[s.id];
      if (t != null && t.isNotEmpty) {
        final m = hhmmToMinutes(t);
        start ??= m;
        last = m;
      }
    }
    return start != null ? last - start : 0;
  }

  String _getTrafficDaysSummary(List<Trip> trips) {
    if (trips.isEmpty) return '';
    final allDays = <int>{};
    for (final t in trips) {
      allDays.add(t.serviceDays);
    }
    if (allDays.length == 1) {
      final d = allDays.first;
      if (d == 0x7F) return '';
      if (d == 0x3F) return 'Monday - Saturday';
      if (d == 0x40) return 'Sundays & holidays';
      if (d == 0x1F) return 'Monday - Friday';
    }
    return '';
  }
}

// ─── Schedule grid ────────────────────────────────────────────────────────────

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({
    required this.data,
    required this.lineColor,
    required this.langCode,
    required this.scrollController,
  });
  final _ScheduleData data;
  final Color lineColor;
  final String langCode;
  final ScrollController scrollController;

  static const _leftW = 88.0;
  static const _colW = 54.0;
  static const _timeW = 36.0;
  static const _deltaW = 32.0;
  static const _hdrH = 28.0;
  static const _rowH = 40.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cumulative = _computeCumulative();
    final bgHeader = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);

    return LayoutBuilder(
      builder: (context, constraints) {
        final midW = constraints.maxWidth - _leftW - (_timeW + _deltaW);
        return SingleChildScrollView(
          controller: scrollController,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left fixed column (station names) ──
              SizedBox(
                width: _leftW,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Train № header
                    Container(
                      height: _hdrH,
                      color: bgHeader,
                      padding: const EdgeInsets.only(left: 8),
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        AppLocalizations.of(context).schedule_col_train,
                        style: _subHdrStyle,
                      ),
                    ),
                    // Traffic days header
                    Container(
                      height: _hdrH,
                      color: bgHeader,
                      padding: const EdgeInsets.only(left: 8),
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        AppLocalizations.of(context).schedule_col_days,
                        style: _subHdrStyle,
                      ),
                    ),
                    // Station rows
                    ...List.generate(data.stations.length, (i) {
                      final s = data.stations[i];
                      final isFirst = i == 0;
                      final isLast = i == data.stations.length - 1;
                      final isMain = isFirst || isLast;
                      return SizedBox(
                        height: _rowH,
                        width: _leftW,
                        child: Row(
                          children: [
                            // Timeline indicator
                            SizedBox(
                              width: 20,
                              height: _rowH,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (!isFirst)
                                    Positioned(
                                      top: 0,
                                      bottom: _rowH / 2,
                                      child: Container(
                                        width: 2,
                                        color: lineColor.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  if (!isLast)
                                    Positioned(
                                      top: _rowH / 2,
                                      bottom: 0,
                                      child: Container(
                                        width: 2,
                                        color: lineColor.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  Container(
                                    width: isMain ? 10 : 8,
                                    height: isMain ? 10 : 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isMain
                                          ? lineColor
                                          : (isDark
                                                ? const Color(0xFF1F2937)
                                                : Colors.white),
                                      border: Border.all(
                                        color: lineColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Station name
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  s.localizedName(langCode),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isMain
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isMain ? null : Colors.grey.shade600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // ── Middle scrollable (train times) ──
              SizedBox(
                width: midW,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Train numbers header row
                      Row(
                        children: data.trips
                            .map(
                              (t) => Container(
                                width: _colW,
                                height: _hdrH,
                                color: bgHeader,
                                alignment: Alignment.center,
                                child: Text(
                                  t.trainNumber,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0EA5E9),
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      // Traffic days header row
                      Row(
                        children: data.trips.map((t) {
                          final sym = _daySymbol(t.serviceDays);
                          return Container(
                            width: _colW,
                            height: _hdrH,
                            color: bgHeader,
                            alignment: Alignment.center,
                            child: Text(
                              sym.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: sym.color,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // Station time rows
                      ...data.stations.map(
                        (s) => Row(
                          children: data.trips.map((t) {
                            final time = data.times[t.id]?[s.id] ?? '';
                            return Container(
                              width: _colW,
                              height: _rowH,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF374151)
                                        : Colors.grey.shade100,
                                  ),
                                ),
                              ),
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: time.isEmpty
                                      ? Colors.transparent
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Right fixed column (cumulative + delta) ──
              SizedBox(
                width: _timeW + _deltaW,
                child: Column(
                  children: [
                    // Header cells (aligned with train № and jours rows)
                    Container(
                      height: _hdrH,
                      color: bgHeader,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        AppLocalizations.of(context).schedule_col_time,
                        style: _subHdrStyle,
                      ),
                    ),
                    Container(
                      height: _hdrH,
                      color: bgHeader,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        AppLocalizations.of(context).schedule_col_min,
                        style: _subHdrStyle,
                      ),
                    ),
                    // Cumulative rows
                    ...List.generate(data.stations.length, (i) {
                      final cum = cumulative[i];
                      final delta =
                          i > 0 && cumulative[i] >= 0 && cumulative[i - 1] >= 0
                          ? cumulative[i] - cumulative[i - 1]
                          : -1;
                      return Container(
                        height: _rowH,
                        width: _timeW + _deltaW,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark
                                  ? const Color(0xFF374151)
                                  : Colors.grey.shade100,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: _timeW,
                              child: Text(
                                cum >= 0 ? "$cum'" : '',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: _deltaW,
                              child: Text(
                                delta > 0 ? '+$delta' : '',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<int> _computeCumulative() {
    if (data.trips.isEmpty || data.stations.isEmpty) {
      return List.filled(data.stations.length, -1);
    }
    final firstTripTimes = data.times[data.trips.first.id] ?? {};
    int? startMin;
    return data.stations.map((s) {
      final t = firstTripTimes[s.id];
      if (t == null || t.isEmpty) return -1;
      final m = hhmmToMinutes(t);
      startMin ??= m;
      return m - startMin!;
    }).toList();
  }

  static const _subHdrStyle = TextStyle(
    fontSize: 10,
    color: Color(0xFF6B7280),
    fontWeight: FontWeight.w500,
  );

  ({String label, Color color}) _daySymbol(int serviceDays) {
    switch (serviceDays) {
      case 0x7F: return (label: '-', color: const Color(0xFF6B7280)); // all days
      case 0x3F: return (label: 'A', color: const Color(0xFFD97706)); // Mon–Sat
      case 0x40: return (label: 'B', color: const Color(0xFF059669)); // Sun only
      case 0x1F: return (label: 'C', color: const Color(0xFF7C3AED)); // Mon–Fri
      case 0x60: return (label: 'D', color: const Color(0xFFDC2626)); // Sat–Sun
      case 0: return (label: '?', color: Colors.grey);
    }
    // Generic fallback for non-standard bitmasks
    final hasWeekdays = serviceDays & 0x3F != 0;
    final hasSunday = serviceDays & 0x40 != 0;
    if (hasWeekdays && hasSunday) return (label: '-', color: const Color(0xFF6B7280));
    if (hasWeekdays) return (label: 'A', color: const Color(0xFFD97706));
    if (hasSunday) return (label: 'B', color: const Color(0xFF059669));
    return (label: '?', color: Colors.grey);
  }
}

// ─── Direction toggle ─────────────────────────────────────────────────────────

class _DirectionToggle extends StatelessWidget {
  const _DirectionToggle({
    required this.direction,
    required this.stations,
    required this.locale,
    required this.onChanged,
  });
  final _Direction direction;
  final List<Station> stations;
  final String locale;
  final ValueChanged<_Direction> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (stations.isEmpty) return const SizedBox.shrink();
    final firstName = stations.first.localizedName(locale);
    final lastName = stations.last.localizedName(locale);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: '→ $lastName',
              selected: direction == _Direction.forward,
              onTap: () => onChanged(_Direction.forward),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              label: '← $firstName',
              selected: direction == _Direction.backward,
              onTap: () => onChanged(_Direction.backward),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? const Color(0xFF374151) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? (isDark ? Colors.white : const Color(0xFF111827))
                : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ─── Footer with legend ───────────────────────────────────────────────────────

class _SheetFooter extends StatelessWidget {
  const _SheetFooter({
    required this.lineColor,
    required this.isDark,
    required this.onClose,
  });
  final Color lineColor;
  final bool isDark;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final bgFooter = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bgFooter,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF374151) : Colors.grey.shade200,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Legend (3 columns × 3 rows)
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: _LegendItem(symbol: '-', color: const Color(0xFF6B7280), label: loc.schedule_every_day)),
                      Expanded(child: _LegendItem(symbol: 'A', color: const Color(0xFFD97706), label: loc.schedule_except_holidays)),
                      Expanded(child: _LegendItem(symbol: 'B', color: const Color(0xFF059669), label: loc.schedule_sun_holidays)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _LegendItem(symbol: 'C', color: const Color(0xFF7C3AED), label: loc.schedule_special_depart)),
                      Expanded(child: _LegendItem(symbol: 'D', color: const Color(0xFFDC2626), label: loc.schedule_sat_sun_holidays)),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _StationLegendItem(filled: true, label: loc.schedule_main_station)),
                      Expanded(child: _StationLegendItem(filled: false, label: loc.schedule_secondary_station)),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: kEmerald500,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: onClose,
                      child: Text(
                        loc.close,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.symbol,
    required this.color,
    required this.label,
  });
  final String symbol;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          symbol,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StationLegendItem extends StatelessWidget {
  const _StationLegendItem({required this.filled, required this.label});
  final bool filled;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? const Color(0xFF0EA5E9) : Colors.transparent,
            border: Border.all(color: const Color(0xFF0EA5E9), width: 2),
          ),
          child: filled
              ? const Center(
                  child: CircleAvatar(radius: 3, backgroundColor: Colors.white),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
