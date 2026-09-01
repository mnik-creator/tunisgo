// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/helpers/connectivity_provider.dart';
import '../../core/helpers/locale_provider.dart';
import '../../core/helpers/session_tracker_provider.dart';
import '../../core/models/station.dart';
import '../../core/models/trip.dart';
import '../../core/repositories/providers.dart';
import '../../core/services/frequent_stations_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/skeleton_card.dart';
import '../../core/widgets/trip_result_card.dart';
import '../../l10n/app_localizations.dart';
import '../../services/interstitial_ad_service.dart';
import '../../services/review_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../widgets/ad_banner_widget.dart';
import '../../widgets/ads/native_ad_widget.dart';
import '../trip_detail/trip_detail_bottom_sheet.dart';

final _isRamadanProvider = FutureProvider<bool>((ref) {
  return ref.read(tripRepositoryProvider).isRamadanActive();
});

class TripSearchTab extends ConsumerStatefulWidget {
  const TripSearchTab({super.key});

  @override
  ConsumerState<TripSearchTab> createState() => _TripSearchTabState();
}

class _TripSearchTabState extends ConsumerState<TripSearchTab> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _fromFocusNode = FocusNode();
  final _toFocusNode = FocusNode();
  final _fromFieldKey = GlobalKey();
  final _toFieldKey = GlobalKey();
  final _fromLayerLink = LayerLink();
  final _toLayerLink = LayerLink();

  String? _fromId;
  String? _toId;

  // null = no filter (show all trains), otherwise filter from this time
  TimeOfDay? _time;
  DateTime? _date;
  bool _isDeparture = true;
  // true when user explicitly picked a different time via the picker
  bool _userChangedDateTime = false;

  bool _fromFocused = false;
  bool _toFocused = false;
  bool _isLoading = false;
  List<Trip>? _results;
  Trip? _previousTrain;
  bool _noConnection = false;

  List<Station> _fromSuggestions = [];
  List<Station> _toSuggestions = [];

  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _fromFocusNode.addListener(_onFromFocusChange);
    _toFocusNode.addListener(_onToFocusChange);
    // Default to current time
    _time = TimeOfDay.now();
    _date = DateTime.now();
    // Pre-load major stations for both fields
    _fetchSuggestions('', true);
    _fetchSuggestions('', false);
  }

  @override
  void dispose() {
    _fromFocusNode.removeListener(_onFromFocusChange);
    _toFocusNode.removeListener(_onToFocusChange);
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    _removeOverlay();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _onFromFocusChange() {
    if (!_fromFocusNode.hasFocus &&
        _fromId == null &&
        _fromController.text.isNotEmpty &&
        _fromSuggestions.isNotEmpty) {
      final langCode = ref.read(localeProvider).languageCode;
      _selectStation(_fromSuggestions.first, langCode, true);
    }
  }

  void _onToFocusChange() {
    if (!_toFocusNode.hasFocus &&
        _toId == null &&
        _toController.text.isNotEmpty &&
        _toSuggestions.isNotEmpty) {
      final langCode = ref.read(localeProvider).languageCode;
      _selectStation(_toSuggestions.first, langCode, false);
    }
  }

  // ─── Suggestions (state-based, avoids ref.watch inside OverlayEntry) ─────

  Future<void> _fetchSuggestions(String query, bool isFrom) async {
    final repo = ref.read(stationRepositoryProvider);
    final service = ref.read(frequentStationsServiceProvider);
    List<Station> stations;
    if (!isFrom && _fromId != null) {
      final reachable = await repo.getReachableStations(_fromId!, query: query.isEmpty ? null : query);
      if (query.isEmpty) {
        final topIds = service.getTopDestinationIds();
        final frequent = await repo.getStationsByIds(topIds);
        final reachableIds = {for (final s in reachable) s.id};
        final frequentReachable = frequent.where((s) => reachableIds.contains(s.id)).toList();
        final frequentIds = {for (final s in frequentReachable) s.id};
        stations = [...frequentReachable, ...reachable.where((s) => !frequentIds.contains(s.id))];
      } else {
        stations = reachable;
      }
    } else if (query.isEmpty && isFrom) {
      final topIds = service.getTopDepartureIds();
      final frequent = await repo.getStationsByIds(topIds);
      final all = await repo.getAllStations();
      final frequentIds = {for (final s in frequent) s.id};
      stations = [...frequent, ...all.where((s) => !frequentIds.contains(s.id))];
    } else if (query.isEmpty) {
      final topIds = service.getTopDestinationIds();
      final frequent = await repo.getStationsByIds(topIds);
      final all = await repo.getAllStations();
      final frequentIds = {for (final s in frequent) s.id};
      stations = [...frequent, ...all.where((s) => !frequentIds.contains(s.id))];
    } else {
      stations = await repo.searchByName(query);
    }
    if (!mounted) return;
    setState(() {
      if (isFrom) {
        _fromSuggestions = stations;
      } else {
        _toSuggestions = stations;
      }
    });
    _overlayEntry?.markNeedsBuild();
  }

  // ─── Overlay for suggestions ─────────────────────────────────────────────

  void _showOverlay(GlobalKey fieldKey, LayerLink layerLink, bool isFrom) {
    _removeOverlay();
    final renderBox =
        fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final fieldWidth = renderBox.size.width;
    final langCode = ref.read(localeProvider).languageCode;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final stations = isFrom ? _fromSuggestions : _toSuggestions;
        return Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: fieldWidth,
                child: _SuggestionsPanel(
                  stations: stations,
                  langCode: langCode,
                  maxHeight: 240,
                  onSelect: (s) => _selectStation(s, langCode, isFrom),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ─── Logic ───────────────────────────────────────────────────────────────

  List<Trip> _applyFilter(List<Trip> trips) {
    List<Trip> result = trips;

    if (_date != null) {
      final dayBit = 1 << (_date!.weekday - 1);
      result = result.where((t) => t.serviceDays & dayBit != 0).toList();
    }

    return result;
  }

  Future<void> _doSearch() async {
    if (_fromId == null || _toId == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _results = null;
      _previousTrain = null;
      _noConnection = false;
    });
    _removeOverlay();
    try {
      final minutes =
          _time != null ? _time!.hour * 60 + _time!.minute : null;
      final trips = await ref.read(tripRepositoryProvider).searchTrips(
        _fromId!,
        _toId!,
        afterMinutes: _isDeparture ? minutes : null,
        arrivalBeforeMinutes: _isDeparture ? null : minutes,
      );
      Trip? prevTrain;
      if (_isDeparture && minutes != null) {
        final prev = await ref
            .read(tripRepositoryProvider)
            .getPreviousTrain(_fromId!, _toId!, minutes);
        if (prev != null && minutes - prev.departureTime <= 15) {
          prevTrain = prev.copyWith(mayArriveLate: true);
        }
      }
      bool noConnection = false;
      if (trips.isEmpty) {
        noConnection = !await ref
            .read(tripRepositoryProvider)
            .hasAnyConnection(_fromId!, _toId!);
      }
      if (mounted) {
        setState(() {
          _results = trips;
          _previousTrain = prevTrain;
          _noConnection = noConnection;
        });
      }
      if (trips.isNotEmpty) {
        final prefs = ref.read(sharedPreferencesProvider);
        await ReviewService.maybeRequest(prefs);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    // Session tracking + interstitial frequency cap
    final tracker = ref.read(sessionTrackerProvider.notifier);
    tracker.incrementSearch();
    final session = ref.read(sessionTrackerProvider);
    if (session.canShowInterstitial) {
      await InterstitialAdService.show();
      tracker.markInterstitialShown();
    }
  }

  void _swapStations() {
    setState(() {
      final tempId = _fromId;
      final tempText = _fromController.text;
      _fromId = _toId;
      _fromController.text = _toController.text;
      _toId = tempId;
      _toController.text = tempText;
    });
  }

  void _selectStation(Station station, String langCode, bool isFrom) {
    final service = ref.read(frequentStationsServiceProvider);
    if (isFrom) {
      service.recordDeparture(station.id);
    } else {
      service.recordDestination(station.id);
    }
    final name = station.localizedName(langCode);
    setState(() {
      if (isFrom) {
        _fromId = station.id;
        _fromController.text = name;
        _fromFocused = false;
        // Reset the "to" field so the user picks from reachable stations only
        _toId = null;
        _toController.clear();
        _noConnection = false;
      } else {
        _toId = station.id;
        _toController.text = name;
        _toFocused = false;
      }
    });
    _removeOverlay();
    if (isFrom) {
      // Pre-load reachable stations for the "to" dropdown
      _fetchSuggestions('', false);
    }
  }

  Future<void> _pickDateTime() async {
    final result = await showModalBottomSheet<
        ({DateTime date, TimeOfDay time, bool isDeparture})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DateTimePickerSheet(
        initialDate: _date ?? DateTime.now(),
        initialTime: _time ?? TimeOfDay.now(),
        initialIsDeparture: _isDeparture,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _date = result.date;
      _time = result.time;
      _isDeparture = result.isDeparture;
      _userChangedDateTime = true;
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isOnline = ref.watch(isOnlineProvider);
    final isRamadan = ref.watch(_isRamadanProvider);

    return Scaffold(
      body: Column(
        children: [
          isOnline.when(
            data: (online) => online
                ? const SizedBox.shrink()
                : OfflineBanner(message: loc.offline_mode),
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          ),
          isRamadan.when(
            data: (active) => active
                ? _RamadanBanner(message: loc.ramadan_schedule)
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _fromFocused = false;
                  _toFocused = false;
                });
                _removeOverlay();
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.search_tab_title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // From field
                    _StationInputField(
                      fieldKey: _fromFieldKey,
                      layerLink: _fromLayerLink,
                      controller: _fromController,
                      focusNode: _fromFocusNode,
                      label: loc.from_station,
                      isFocused: _fromFocused,
                      onTap: () {
                        setState(() {
                          _fromFocused = true;
                          _toFocused = false;
                        });
                        _fetchSuggestions(_fromController.text, true);
                        _showOverlay(_fromFieldKey, _fromLayerLink, true);
                      },
                      onChanged: (q) {
                        setState(() {
                          _fromId = null;
                          _noConnection = false;
                        });
                        _fetchSuggestions(q, true);
                        // Reset "to" suggestions to all stations when from is cleared
                        _fetchSuggestions(_toController.text, false);
                        if (_fromFocused) {
                          _showOverlay(_fromFieldKey, _fromLayerLink, true);
                        }
                      },
                      dotColor: kEmerald500,
                    ),

                    // Swap button
                    Center(child: _SwapButton(onTap: _swapStations)),

                    // To field
                    _StationInputField(
                      fieldKey: _toFieldKey,
                      layerLink: _toLayerLink,
                      controller: _toController,
                      focusNode: _toFocusNode,
                      label: loc.to_station,
                      isFocused: _toFocused,
                      onTap: () {
                        setState(() {
                          _toFocused = true;
                          _fromFocused = false;
                        });
                        _fetchSuggestions(_toController.text, false);
                        _showOverlay(_toFieldKey, _toLayerLink, false);
                      },
                      onChanged: (q) {
                        setState(() => _toId = null);
                        _fetchSuggestions(q, false);
                        if (_toFocused) {
                          _showOverlay(_toFieldKey, _toLayerLink, false);
                        }
                      },
                      dotColor: Colors.grey.shade400,
                    ),

                    const SizedBox(height: 12),

                    // Date + Time row
                    _DateTimeRow(
                      time: _time,
                      date: _date,
                      isDeparture: _isDeparture,
                      userChanged: _userChangedDateTime,
                      onTap: _pickDateTime,
                      onSetNow: () => setState(() {
                        _time = TimeOfDay.now();
                        _date = DateTime.now();
                        _userChangedDateTime = false;
                      }),
                      onClear: () => setState(() {
                        _time = null;
                        _date = null;
                        _userChangedDateTime = false;
                      }),
                    ),

                    const SizedBox(height: 16),

                    // Search button
                    _SearchButton(
                      enabled: _fromId != null && _toId != null,
                      label: loc.search,
                      onTap: _doSearch,
                    ),

                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            loc.schedule_reference_note,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_results == null && !_isLoading) ...[
                      const SizedBox(height: 16),
                      const AdBannerWidget(size: AdSize.mediumRectangle),
                    ],

                    const SizedBox(height: 24),

                    // Results area
                    if (_isLoading) ...[
                      const SkeletonCard(height: 100),
                      const SkeletonCard(height: 100),
                      const SkeletonCard(height: 100),
                    ] else if (_results != null) ...[
                      if (_previousTrain != null)
                        TripResultCard(
                          trip: _previousTrain!,
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) =>
                                TripDetailBottomSheet(trip: _previousTrain!),
                          ),
                        ),
                      Builder(
                        builder: (_) {
                          final filtered = _applyFilter(_results!);
                          if (filtered.isEmpty) {
                            return EmptyState(
                              icon: Icons.train_outlined,
                              message: _noConnection
                                  ? loc.no_connection_found
                                  : loc.no_results,
                            );
                          }
                          // +1 slot for native ad between index 1 and 2
                          final hasNativeSlot = filtered.length > 2;
                          final itemCount = filtered.length + (hasNativeSlot ? 1 : 0);
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(0),
                            itemCount: itemCount,
                            itemBuilder: (context, i) {
                              // Insert native ad between 2nd and 3rd result
                              if (hasNativeSlot && i == 2) {
                                return const NativeAdWidget();
                              }
                              final tripIndex = hasNativeSlot && i > 2 ? i - 1 : i;
                              final trip = filtered[tripIndex];
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
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Combined Date+Time picker (bottom sheet) ────────────────────────────────

class _DateTimePickerSheet extends StatefulWidget {
  const _DateTimePickerSheet({
    required this.initialDate,
    required this.initialTime,
    required this.initialIsDeparture,
  });
  final DateTime initialDate;
  final TimeOfDay initialTime;
  final bool initialIsDeparture;

  @override
  State<_DateTimePickerSheet> createState() => _DateTimePickerSheetState();
}

class _DateTimePickerSheetState extends State<_DateTimePickerSheet> {
  late bool _isDeparture;
  late List<DateTime> _days;
  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late int _selectedDayIdx;
  late int _selectedHour;
  late int _selectedMinute;

  static const _itemExtent = 50.0;

  @override
  void initState() {
    super.initState();
    _isDeparture = widget.initialIsDeparture;
    final now = DateTime.now();
    _days = List.generate(10, (i) => now.add(Duration(days: i - 1)));

    int dayIdx = _days.indexWhere((d) => _isSameDay(d, widget.initialDate));
    if (dayIdx < 0) dayIdx = 1;
    _selectedDayIdx = dayIdx;
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;

    _dayCtrl = FixedExtentScrollController(initialItem: dayIdx);
    _hourCtrl = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _selectedMinute);
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime d, AppLocalizations loc, Locale locale) {
    final now = DateTime.now();
    if (_isSameDay(d, now)) return loc.today;
    return DateFormat('EEE d MMM', locale.toString()).format(d);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final loc = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Departure / Arrival toggle + reset
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF374151)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _ToggleOption(
                        label: loc.departure,
                        selected: _isDeparture,
                        isDark: isDark,
                        onTap: () => setState(() => _isDeparture = true),
                      ),
                      _ToggleOption(
                        label: loc.arrival,
                        selected: !_isDeparture,
                        isDark: isDark,
                        onTap: () => setState(() => _isDeparture = false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _selectedHour = now.hour;
                    _selectedMinute = now.minute;
                    _selectedDayIdx = 1;
                  });
                  _hourCtrl.animateToItem(
                    now.hour,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                  _minuteCtrl.animateToItem(
                    now.minute,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                  _dayCtrl.animateToItem(
                    1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF374151)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: isDark
                        ? Colors.grey.shade300
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Drum roller — Day | Hour | Minute
          SizedBox(
            height: _itemExtent * 5,
            child: Stack(
              children: [
                Row(
                  children: [
                    // Day column
                    Expanded(
                      flex: 5,
                      child: ListWheelScrollView.useDelegate(
                        controller: _dayCtrl,
                        itemExtent: _itemExtent,
                        perspective: 0.002,
                        diameterRatio: 2.0,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (idx) =>
                            setState(() => _selectedDayIdx = idx),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _days.length,
                          builder: (ctx, idx) => Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                _dayLabel(_days[idx], loc, locale),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: idx == _selectedDayIdx
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: idx == _selectedDayIdx
                                      ? textColor
                                      : textColor.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Hour column
                    Expanded(
                      flex: 3,
                      child: ListWheelScrollView.useDelegate(
                        controller: _hourCtrl,
                        itemExtent: _itemExtent,
                        perspective: 0.002,
                        diameterRatio: 2.0,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (idx) =>
                            setState(() => _selectedHour = idx),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 24,
                          builder: (ctx, idx) => Center(
                            child: Text(
                              idx.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: idx == _selectedHour
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: idx == _selectedHour
                                    ? textColor
                                    : textColor.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Minute column
                    Expanded(
                      flex: 3,
                      child: ListWheelScrollView.useDelegate(
                        controller: _minuteCtrl,
                        itemExtent: _itemExtent,
                        perspective: 0.002,
                        diameterRatio: 2.0,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (idx) =>
                            setState(() => _selectedMinute = idx),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 60,
                          builder: (ctx, idx) => Center(
                            child: Text(
                              idx.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: idx == _selectedMinute
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: idx == _selectedMinute
                                    ? textColor
                                    : textColor.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Center selection highlight band
                IgnorePointer(
                  child: Center(
                    child: Container(
                      height: _itemExtent,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                // Top fade
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: _itemExtent * 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [bgColor, bgColor.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom fade
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: _itemExtent * 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [bgColor, bgColor.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Save button
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
              onPressed: () => Navigator.pop(
                context,
                (
                  date: _days[_selectedDayIdx],
                  time: TimeOfDay(
                    hour: _selectedHour,
                    minute: _selectedMinute,
                  ),
                  isDeparture: _isDeparture,
                ),
              ),
              child: Text(
                loc.save,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              loc.cancel,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF1F2937) : Colors.white)
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected
                  ? (isDark ? Colors.white : const Color(0xFF111827))
                  : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _RamadanBanner extends StatelessWidget {
  const _RamadanBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.green.shade700,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(message, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _StationInputField extends StatelessWidget {
  const _StationInputField({
    required this.fieldKey,
    required this.layerLink,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.isFocused,
    required this.onTap,
    required this.onChanged,
    required this.dotColor,
  });
  final GlobalKey fieldKey;
  final LayerLink layerLink;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final bool isFocused;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: layerLink,
      child: KeyedSubtree(
        key: fieldKey,
        child: TextField(
        controller: controller,
        focusNode: focusNode,
        onTap: onTap,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: label,
          isDense: true,
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.location_on_outlined, size: 20),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _SwapButton extends StatefulWidget {
  const _SwapButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_SwapButton> createState() => _SwapButtonState();
}

class _SwapButtonState extends State<_SwapButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF111827) : Colors.white,
            border: Border.all(
              color: _hovered ? kEmerald500 : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: const Icon(Icons.swap_vert, size: 18),
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.time,
    required this.date,
    required this.isDeparture,
    required this.userChanged,
    required this.onTap,
    required this.onSetNow,
    required this.onClear,
  });
  final TimeOfDay? time;
  final DateTime? date;
  final bool isDeparture;
  final bool userChanged;
  final VoidCallback onTap;
  final VoidCallback onSetNow;
  final VoidCallback onClear;

  String _timeLabel(AppLocalizations loc) {
    if (time == null) return loc.all_trains;
    return '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
  }

  String _dateLabel(AppLocalizations loc, Locale locale) {
    if (date == null) return '';
    final now = DateTime.now();
    final d = date!;
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    if (isToday) return loc.today;
    return DateFormat('EEE d MMM', locale.toString()).format(d);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final hasFilter = time != null || date != null;
    // Show "Now" chip when: no filter (cleared) OR user changed from default
    final showNow = !hasFilter || userChanged;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF374151) : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 20, color: kEmerald500),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isDeparture ? loc.departure : loc.arrival,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: kEmerald500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _timeLabel(loc),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFamily: time != null ? 'monospace' : null,
                        color: time != null ? null : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                if (date != null)
                  Text(
                    _dateLabel(loc, locale),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showNow)
                  GestureDetector(
                    onTap: onSetNow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kEmerald500.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        loc.today,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kEmerald500,
                        ),
                      ),
                    ),
                  ),
                if (showNow && hasFilter) const SizedBox(width: 8),
                if (hasFilter)
                  GestureDetector(
                    onTap: onClear,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF374151)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey.shade600,
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

class _SearchButton extends StatefulWidget {
  const _SearchButton({
    required this.enabled,
    required this.label,
    required this.onTap,
  });
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  State<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends State<_SearchButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: widget.enabled ? AppTheme.primaryGradient : null,
            color: widget.enabled ? null : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                color: widget.enabled ? Colors.white : Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.enabled ? Colors.white : Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionsPanel extends StatelessWidget {
  const _SuggestionsPanel({
    required this.stations,
    required this.langCode,
    required this.onSelect,
    this.maxHeight = 240,
  });
  final List<Station> stations;
  final String langCode;
  final ValueChanged<Station> onSelect;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (stations.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: stations.length,
        itemBuilder: (context, i) {
          final s = stations[i];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.train_outlined, size: 18),
            title: Text(
              s.localizedName(langCode),
              style: const TextStyle(fontSize: 14),
            ),
            onTap: () => onSelect(s),
          );
        },
      ),
    );
  }
}
