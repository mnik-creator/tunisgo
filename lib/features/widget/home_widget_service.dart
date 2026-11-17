// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/helpers/locale_provider.dart';
import '../../core/models/trip.dart';
import '../../core/repositories/providers.dart';
import '../../l10n/app_localizations.dart';
import '../favorites/favorites_provider.dart';

/// Android home-screen widget "next favourite train".
///
/// The app writes every favourite train (departure time at its first stop,
/// running-days bitmask, label) as JSON; the native provider
/// (`NextTrainWidgetProvider.kt`) picks the next departures itself, so the
/// widget stays right without the app running.
class HomeWidgetService {
  static const androidProvider = 'com.tunisgo.tunis_go.NextTrainWidgetProvider';
  static const kTrains = 'widget_trains';
  static const kTitle = 'widget_title';
  static const kEmpty = 'widget_empty';
  static const kTomorrow = 'widget_tomorrow';
  static const kDayNames = 'widget_day_names';

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> refresh(Ref ref) async {
    if (!_supported) return;
    try {
      final ids = ref.read(favoriteTripIdsProvider);
      final lang = ref.read(localeProvider).languageCode;
      final entries = await buildEntries(ref, ids, lang);
      final loc = lookupAppLocalizations(Locale(lang));

      await HomeWidget.saveWidgetData<String>(kTrains, jsonEncode(entries));
      await HomeWidget.saveWidgetData<String>(kTitle, loc.widget_title);
      await HomeWidget.saveWidgetData<String>(kEmpty, loc.widget_empty);
      await HomeWidget.saveWidgetData<String>(kTomorrow, loc.widget_tomorrow);
      await HomeWidget.saveWidgetData<String>(kDayNames, loc.widget_day_names);
      await HomeWidget.updateWidget(qualifiedAndroidName: androidProvider);
    } catch (e) {
      debugPrint('HomeWidgetService.refresh failed: $e');
    }
  }

  @visibleForTesting
  static Future<List<Map<String, Object>>> buildEntries(
    Ref ref,
    Set<String> tripIds,
    String lang,
  ) async {
    final trips = ref.read(tripRepositoryProvider);
    final stations = ref.read(stationRepositoryProvider);
    final entries = <Map<String, Object>>[];

    for (final id in tripIds) {
      final trip = await trips.getTripById(id);
      final stops = await trips.getStopTimesForTrip(id);
      if (trip == null || stops.length < 2) continue;

      final ends = await stations.getStationsByIds([
        stops.first.stationId,
        stops.last.stationId,
      ]);
      if (ends.length < 2) continue;

      entries.add(entryFor(
        trip,
        departureMinutes: stops.first.departureTime,
        from: ends.first.localizedName(lang),
        to: ends.last.localizedName(lang),
      ));
    }
    return entries;
  }

  @visibleForTesting
  static Map<String, Object> entryFor(
    Trip trip, {
    required int departureMinutes,
    required String from,
    required String to,
  }) =>
      {
        'number': trip.trainNumber,
        'from': from,
        'to': to,
        'dep': departureMinutes,
        'days': trip.serviceDays,
      };
}

/// Keeps the widget in sync with favourites and language. Read once at startup.
final homeWidgetSyncProvider = Provider<void>((ref) {
  ref.listen<Set<String>>(
    favoriteTripIdsProvider,
    (_, _) => HomeWidgetService.refresh(ref),
  );
  ref.listen<Locale>(localeProvider, (_, _) => HomeWidgetService.refresh(ref));
  HomeWidgetService.refresh(ref);
});
