// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/helpers/session_tracker_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/rewarded_ad_service.dart';
import 'slot_limits_provider.dart';

/// True when one more [kind] item fits next to the [used] ones — right away,
/// or after the rider accepted and watched a rewarded ad for an extra slot.
/// Shows the matching message otherwise.
Future<bool> ensureSlot(
  BuildContext context,
  WidgetRef ref,
  SlotKind kind,
  int used,
) async {
  if (used < ref.read(slotLimitsProvider.notifier).limit(kind)) return true;
  return earnSlot(context, ref, kind);
}

/// Offers a rewarded ad for one more [kind] slot. True once it was granted.
Future<bool> earnSlot(BuildContext context, WidgetRef ref, SlotKind kind) async {
  final loc = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final limits = ref.read(slotLimitsProvider.notifier);
  final tracker = ref.read(sessionTrackerProvider.notifier);
  void say(String text) => messenger.showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );

  if (!limits.canEarnMore(kind) || kIsWeb) {
    say(kind == SlotKind.favorites
        ? loc.favorites_limit_reached
        : loc.notifications_limit_reached);
    return false;
  }

  unawaited(RewardedAdService.preload());
  final watch = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.ondemand_video_outlined),
      title: Text(loc.slot_limit_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kind == SlotKind.favorites
              ? loc.slot_offer_favorites
              : loc.slot_offer_reminders),
          const SizedBox(height: 12),
          Text(
            loc.slot_offer_rules,
            style: Theme.of(dialogContext).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(loc.slot_watch_ad),
        ),
      ],
    ),
  );
  if (watch != true) return false;

  if (!await RewardedAdService.showForReward()) {
    say(loc.slot_ad_unavailable);
    return false;
  }
  tracker.markRewardedShown();
  await limits.grant(kind);
  final until = limits.bonusExpiry(kind);
  if (until != null) say(loc.slot_earned(DateFormat.MMMd(loc.localeName).format(until)));
  return true;
}
