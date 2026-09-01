// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/locale_provider.dart';

const _kFrequentFromKey = 'frequent_from_station_ids';
const _kFrequentToKey = 'frequent_to_station_ids';
const _kMaxFrequent = 5;

class FrequentStationsService {
  const FrequentStationsService(this._prefs);

  final SharedPreferences _prefs;

  Future<void> recordDeparture(String stationId) async {
    final counts = _loadCounts(_kFrequentFromKey);
    counts[stationId] = (counts[stationId] ?? 0) + 1;
    await _saveCounts(_kFrequentFromKey, counts);
  }

  Future<void> recordDestination(String stationId) async {
    final counts = _loadCounts(_kFrequentToKey);
    counts[stationId] = (counts[stationId] ?? 0) + 1;
    await _saveCounts(_kFrequentToKey, counts);
  }

  // Returns up to _kMaxFrequent station IDs sorted by usage frequency descending.
  List<String> getTopDepartureIds() => _getTopIds(_kFrequentFromKey);
  List<String> getTopDestinationIds() => _getTopIds(_kFrequentToKey);

  List<String> _getTopIds(String key) {
    final counts = _loadCounts(key);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(_kMaxFrequent).map((e) => e.key).toList();
  }

  Map<String, int> _loadCounts(String key) {
    final list = _prefs.getStringList(key) ?? [];
    final map = <String, int>{};
    for (final entry in list) {
      final sep = entry.lastIndexOf(':');
      if (sep > 0) {
        map[entry.substring(0, sep)] = int.tryParse(entry.substring(sep + 1)) ?? 1;
      }
    }
    return map;
  }

  Future<void> _saveCounts(String key, Map<String, int> counts) async {
    final list = counts.entries.map((e) => '${e.key}:${e.value}').toList();
    await _prefs.setStringList(key, list);
  }
}

final frequentStationsServiceProvider = Provider<FrequentStationsService>(
  (ref) => FrequentStationsService(ref.read(sharedPreferencesProvider)),
);
