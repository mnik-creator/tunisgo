// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/trip.dart';
import '../../core/repositories/providers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_card.dart';
import '../../core/widgets/trip_result_card.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ads/native_ad_widget.dart';
import '../trip_detail/trip_detail_bottom_sheet.dart';

final _resultsProvider =
    FutureProvider.family<
      List<Trip>,
      ({String fromId, String toId, int? afterMinutes})
    >((ref, params) async {
      final repo = ref.read(tripRepositoryProvider);
      final trips = await repo.searchTrips(
        params.fromId,
        params.toId,
        afterMinutes: params.afterMinutes,
      );
      if (params.afterMinutes != null) {
        final prev = await repo.getPreviousTrain(
          params.fromId,
          params.toId,
          params.afterMinutes!,
        );
        if (prev != null && params.afterMinutes! - prev.departureTime <= 15) {
          return [prev.copyWith(mayArriveLate: true), ...trips];
        }
      }
      return trips;
    });

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({
    required this.fromStationId,
    required this.toStationId,
    this.afterMinutes,
    super.key,
  });

  final String fromStationId;
  final String toStationId;
  final int? afterMinutes;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  static const int _pageSize = 5;
  int _displayedCount = 5;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      setState(() => _displayedCount += _pageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final params = (
      fromId: widget.fromStationId,
      toId: widget.toStationId,
      afterMinutes: widget.afterMinutes,
    );
    final tripsAsync = ref.watch(_resultsProvider(params));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  loc.search,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: tripsAsync.when(
              loading: () => ListView(
                children: const [
                  SkeletonCard(height: 100),
                  SkeletonCard(height: 100),
                  SkeletonCard(height: 100),
                ],
              ),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (trips) {
                if (trips.isEmpty) {
                  return EmptyState(
                    icon: Icons.train_outlined,
                    message: loc.no_results,
                  );
                }
                final displayedTrips = trips.take(_displayedCount).toList();
                final hasNativeSlot = displayedTrips.length > 2;
                final itemCount = displayedTrips.length + (hasNativeSlot ? 1 : 0);
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: itemCount,
                  itemBuilder: (context, i) {
                    if (hasNativeSlot && i == 2) return const NativeAdWidget();
                    final tripIndex = hasNativeSlot && i > 2 ? i - 1 : i;
                    final trip = displayedTrips[tripIndex];
                    return TripResultCard(
                      trip: trip,
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => TripDetailBottomSheet(trip: trip),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
