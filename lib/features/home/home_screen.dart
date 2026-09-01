// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/helpers/connectivity_provider.dart';
import '../../core/helpers/time_helpers.dart';
import '../../core/repositories/providers.dart';
import '../../l10n/app_localizations.dart';

final _isRamadanProvider = FutureProvider<bool>((ref) {
  return ref.read(tripRepositoryProvider).isRamadanActive();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isOnline = ref.watch(isOnlineProvider);
    final isRamadan = ref.watch(_isRamadanProvider);

    return Scaffold(
      appBar: AppBar(title: Text(loc.app_name)),
      body: Column(
        children: [
          // Offline banner
          isOnline.when(
            data: (online) => online
                ? const SizedBox.shrink()
                : _OfflineBanner(message: loc.offline_mode),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          // Ramadan banner
          isRamadan.when(
            data: (active) => active
                ? _RamadanBanner(message: loc.ramadan_schedule)
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const Expanded(child: _QuickSearchCard()),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade700,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}

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
          Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _QuickSearchCard extends ConsumerStatefulWidget {
  const _QuickSearchCard();

  @override
  ConsumerState<_QuickSearchCard> createState() => _QuickSearchCardState();
}

class _QuickSearchCardState extends ConsumerState<_QuickSearchCard> {
  String? _fromId;
  String? _fromName;
  String? _toId;
  String? _toName;
  TimeOfDay _time = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StationTile(
                label: loc.from_station,
                value: _fromName,
                onTap: () async {
                  final result = await context.push<Map<String, String>>(
                    '/search?mode=picker',
                  );
                  if (result != null) {
                    setState(() {
                      _fromId = result['id'];
                      _fromName = result['name'];
                    });
                  }
                },
              ),
              const Divider(height: 1),
              _StationTile(
                label: loc.to_station,
                value: _toName,
                onTap: () async {
                  final result = await context.push<Map<String, String>>(
                    '/search?mode=picker',
                  );
                  if (result != null) {
                    setState(() {
                      _toId = result['id'];
                      _toName = result['name'];
                    });
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(minutesToHHMM(_time.hour * 60 + _time.minute)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (picked != null) setState(() => _time = picked);
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.search),
                  label: Text(loc.search),
                  onPressed: _fromId != null && _toId != null
                      ? () => context.goNamed(
                            'results',
                            extra: {
                              'fromStationId': _fromId!,
                              'toStationId': _toId!,
                              'afterMinutes':
                                  _time.hour * 60 + _time.minute,
                            },
                          )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.train),
      title: Text(label),
      subtitle: value != null ? Text(value!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
