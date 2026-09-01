// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import 'line_repository.dart';
import 'station_repository.dart';
import 'trip_repository.dart';

final stationRepositoryProvider = Provider<StationRepository>(
  (ref) => StationRepository(DatabaseHelper.instance),
);

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(
    DatabaseHelper.instance,
    stationRepo: ref.watch(stationRepositoryProvider),
  ),
);

final lineRepositoryProvider = Provider<LineRepository>(
  (ref) => LineRepository(DatabaseHelper.instance),
);
