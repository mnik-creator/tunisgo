// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/station.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import 'live_board.dart';
import 'live_models.dart';
import 'live_providers.dart';
import 'station_aliases.dart';

/// Bundled stations keyed by normalised French name, to show live stop names
/// (French, as SNCFT sends them) in the rider's language.
final _stationsByNameProvider = FutureProvider<Map<String, Station>>((ref) async {
  final stations = await ref.read(stationRepositoryProvider).getAllStations();
  return {for (final s in stations) normalizeStationName(s.nameFr): s};
});

/// [stop]'s name in [lang]: SNCFT's Arabic for `ar`, otherwise the bundled
/// station's translation; the raw feed name when the stop is unknown.
String liveStopName(LiveStopTime stop, String lang, Map<String, Station>? byName) {
  if (lang == 'ar' && stop.nameAr.isNotEmpty) return stop.nameAr;
  final resolved = resolveStopName(stop.name);
  final station = resolved == null ? null : byName?[normalizeStationName(resolved)];
  return station?.localizedName(lang) ?? stop.name;
}

/// Opens the live board for one station.
Future<void> showLiveBoard(
  BuildContext context, {
  required String dbStationName,
  required String displayName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => LiveBoardSheet(
      dbStationName: dbStationName,
      displayName: displayName,
    ),
  );
}

class LiveBoardSheet extends ConsumerWidget {
  const LiveBoardSheet({
    required this.dbStationName,
    required this.displayName,
    super.key,
  });

  /// `stops.name` in the bundled database (`Station.nameFr`).
  final String dbStationName;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final feedAsync = ref.watch(liveFeedProvider);
    final feed = ref.watch(freshLiveFeedProvider);
    final byName = ref.watch(_stationsByNameProvider).valueOrNull;
    String stopName(LiveStopTime stop) => liveStopName(stop, loc.localeName, byName);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        Widget body;
        if (feedAsync.isLoading && !feedAsync.hasValue) {
          body = const Center(child: CircularProgressIndicator());
        } else if (feed == null) {
          body = _Message(icon: Icons.cloud_off, text: loc.live_unavailable);
        } else {
          final rows = buildStationBoard(
            feed,
            dbStationName,
            nowMinutes: tunisNowMinutes(),
          );
          body = rows.isEmpty
              ? _Message(icon: Icons.train_outlined, text: loc.live_empty)
              : ListView.separated(
                  controller: scrollController,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _Row(call: rows[i], loc: loc, stopName: stopName),
                );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.sensors, color: kEmerald500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${loc.live_title} · $displayName',
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [
                            if (feed?.generatedAt != null)
                              loc.live_updated_at(_tunisHhmm(feed!.generatedAt!)),
                            loc.live_source,
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

String _tunisHhmm(DateTime utc) {
  final m = tunisNowMinutes(utc);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

class _Row extends StatelessWidget {
  const _Row({required this.call, required this.loc, required this.stopName});

  final LiveCall call;
  final AppLocalizations loc;
  final String Function(LiveStopTime stop) stopName;

  /// "Gabès – Tunis" in the rider's language; SNCFT's own route name as a
  /// fallback.
  String get _route {
    final train = call.train;
    if (loc.localeName == 'ar' && train.routeNameAr.isNotEmpty) return train.routeNameAr;
    if (train.stops.length < 2) return train.routeName;
    return '${stopName(train.stops.first)} – ${stopName(train.stops.last)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheduled = call.stop.scheduled;
    final eta = call.eta;
    final shifted = !call.isCancelled && eta != null && eta != scheduled;

    return ListTile(
      leading: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shifted ? eta : (scheduled ?? '--:--'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: call.delayMinutes > 0 ? theme.colorScheme.error : null,
              ),
            ),
            if (shifted && scheduled != null)
              Text(
                scheduled,
                style: theme.textTheme.labelSmall?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ),
      title: Text(
        '${call.train.number.replaceFirst(RegExp(r'^0+'), '')} → '
        '${call.train.stops.isEmpty ? call.terminus : stopName(call.train.stops.last)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _route,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: LiveStatusBadge(call: call, loc: loc),
    );
  }
}

/// Small pill with the live state of one call: cancelled, departed, late or
/// on time. Renders nothing while the train has not started reporting.
class LiveStatusBadge extends StatelessWidget {
  const LiveStatusBadge({required this.call, required this.loc, super.key});

  final LiveCall call;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String text;
    final Color color;
    if (call.isCancelled) {
      text = loc.live_cancelled;
      color = theme.colorScheme.error;
    } else if (call.isPassed) {
      text = loc.live_departed;
      color = Colors.grey.shade600;
    } else if (!call.hasLiveDelay) {
      return const SizedBox.shrink();
    } else if (call.delayMinutes > 0) {
      text = loc.live_delay(call.delayMinutes);
      color = call.delayMinutes >= 5 ? theme.colorScheme.error : Colors.orange.shade800;
    } else {
      text = loc.live_on_time;
      color = kEmerald500;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
