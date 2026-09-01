// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:go_router/go_router.dart';

import '../features/favorites/favorites_screen.dart';
import '../features/lines/lines_screen.dart';
import '../features/results/results_screen.dart';
import '../features/search/trip_search_tab.dart';
import '../features/settings/settings_screen.dart';
import '../features/station_schedule/station_schedule_screen.dart';
import '../features/trip_detail/trip_detail_screen.dart';
import 'shell_scaffold.dart';

final appRouter = GoRouter(
  initialLocation: '/search',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ShellScaffold(child: child),
      routes: [
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) => const TripSearchTab(),
        ),
        GoRoute(
          path: '/lines',
          name: 'lines',
          builder: (context, state) => const LinesScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/results',
      name: 'results',
      redirect: (context, state) {
        final extra = state.extra;
        if (extra is! Map<String, dynamic> ||
            extra['fromStationId'] is! String ||
            extra['toStationId'] is! String) {
          return '/search';
        }
        return null;
      },
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ResultsScreen(
          fromStationId: extra['fromStationId'] as String,
          toStationId: extra['toStationId'] as String,
          afterMinutes: extra['afterMinutes'] as int?,
        );
      },
    ),
    GoRoute(
      path: '/trip/:id',
      name: 'trip',
      builder: (context, state) => TripDetailScreen(
        tripId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/station/:code',
      name: 'station',
      builder: (context, state) => StationScheduleScreen(
        stationCode: state.pathParameters['code']!,
      ),
    ),
    GoRoute(
      path: '/favorites',
      name: 'favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
  ],
);
