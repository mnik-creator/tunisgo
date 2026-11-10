// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/live_config.dart';
import 'live_board.dart';
import 'live_models.dart';

class LiveFeedService {
  LiveFeedService({Dio? dio, String? url})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: const {'Accept': 'application/json'},
            ),
          ),
      _url = url ?? LiveConfig.feedUrl;

  final Dio _dio;
  final String _url;

  Future<LiveFeed> fetch() async {
    final response = await _dio.get<dynamic>(_url);
    final data = response.data;
    final json = data is String ? jsonDecode(data) : data;
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Unexpected live feed payload');
    }
    return LiveFeed.fromJson(json);
  }
}

final liveFeedServiceProvider = Provider<LiveFeedService>(
  (ref) => LiveFeedService(),
);

/// Latest live feed while any screen listens; null when the feed is disabled
/// or has not loaded. Polls every [LiveConfig.pollInterval], backing off to
/// 5 minutes while unreachable, and keeps the last good value on errors so a
/// flaky network never blanks the screen.
final liveFeedProvider = StreamProvider.autoDispose<LiveFeed?>((ref) async* {
  if (!LiveConfig.isEnabled) {
    yield null;
    return;
  }
  final service = ref.watch(liveFeedServiceProvider);
  var interval = LiveConfig.pollInterval;
  LiveFeed? last;

  while (true) {
    try {
      last = await service.fetch();
      interval = LiveConfig.pollInterval;
      yield last;
    } catch (e) {
      if (kDebugMode) debugPrint('[Live] feed fetch failed: $e');
      interval = Duration(
        seconds: (interval.inSeconds * 2).clamp(60, 300).toInt(),
      );
      if (last == null) yield null;
    }
    await Future<void>.delayed(interval);
  }
});

/// Fresh feed or null (disabled, not loaded yet, or older than
/// [LiveConfig.maxAge]).
final freshLiveFeedProvider = Provider.autoDispose<LiveFeed?>((ref) {
  final feed = ref.watch(liveFeedProvider).valueOrNull;
  if (feed == null || feed.isStale(LiveConfig.maxAge)) return null;
  return feed;
});

/// Train-number index used to overlay delays on timetable rows.
final liveTrainIndexProvider = Provider.autoDispose((ref) {
  final feed = ref.watch(freshLiveFeedProvider);
  return feed == null ? const <String, List<LiveTrain>>{} : indexByTrainKey(feed);
});
