// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';

import '../../core/helpers/time_helpers.dart';
import '../../l10n/app_localizations.dart';

const _leadOptions = [5, 10, 15, 30, 45, 60];

/// Asks how long before [departureMinutes] (minutes since midnight, today) to
/// remind the rider. Returns the lead in minutes, or null when dismissed.
/// Options whose reminder time has already passed are disabled.
Future<int?> pickNotifyLeadMinutes(BuildContext context, int departureMinutes) {
  final loc = AppLocalizations.of(context);
  final now = TimeOfDay.now();
  final nowMinutes = now.hour * 60 + now.minute;
  if (departureMinutes <= nowMinutes) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.notification_already_passed)));
    return Future.value();
  }

  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    // Above the floating bottom navigation, and scrollable on short screens.
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.notify_pick_title,
              style: Theme.of(
                sheetContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final lead in _leadOptions)
              ListTile(
                dense: true,
                leading: const Icon(Icons.notifications_outlined),
                title: Text(loc.notify_minutes_before(lead)),
                trailing: Text(
                  minutesToHHMM(departureMinutes - lead),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                enabled: departureMinutes - lead > nowMinutes,
                onTap: () => Navigator.pop(sheetContext, lead),
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.access_time),
              title: Text(loc.notify_pick_time),
              onTap: () async {
                final initial = departureMinutes - 15;
                final picked = await showTimePicker(
                  context: sheetContext,
                  initialTime: TimeOfDay(
                    hour: initial ~/ 60 % 24,
                    minute: initial % 60,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  ),
                );
                if (picked == null || !sheetContext.mounted) return;
                final at = picked.hour * 60 + picked.minute;
                final message = at >= departureMinutes
                    ? loc.notify_time_after_departure
                    : at <= nowMinutes
                    ? loc.notification_time_passed
                    : null;
                if (message != null) {
                  ScaffoldMessenger.of(
                    sheetContext,
                  ).showSnackBar(SnackBar(content: Text(message)));
                  return;
                }
                Navigator.pop(sheetContext, departureMinutes - at);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
