// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/helpers/locale_provider.dart';

/// Things a rider can only keep a few of.
enum SlotKind { favorites, reminders }

/// Free slots per kind, without watching ads.
const kBaseSlots = 1;

/// Hard cap per kind, ads included.
const kMaxSlots = 5;

/// Extra slots earned with rewarded ads expire together this long after the
/// first one of a cycle, so the limit falls back to [kBaseSlots] weekly.
const kSlotBonusLifetime = Duration(days: 7);

/// Extra slots earned for one [SlotKind].
class SlotBonus {
  const SlotBonus({this.extra = 0, this.expiresAt});

  final int extra;
  final DateTime? expiresAt;

  bool isActive(DateTime now) => extra > 0 && expiresAt != null && now.isBefore(expiresAt!);

  int limit(DateTime now) => kBaseSlots + (isActive(now) ? extra : 0);
}

/// Rewarded-ad bonus slots, persisted in SharedPreferences as
/// `slots_<kind>` = `<extra>|<expires ISO-8601>`.
class SlotLimitsNotifier extends Notifier<Map<SlotKind, SlotBonus>> {
  static String _key(SlotKind kind) => 'slots_${kind.name}';

  @override
  Map<SlotKind, SlotBonus> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return {
      for (final kind in SlotKind.values) kind: _parse(prefs.getString(_key(kind))),
    };
  }

  static SlotBonus _parse(String? raw) {
    final parts = (raw ?? '').split('|');
    if (parts.length != 2) return const SlotBonus();
    return SlotBonus(
      extra: int.tryParse(parts[0]) ?? 0,
      expiresAt: DateTime.tryParse(parts[1]),
    );
  }

  /// Current number of slots for [kind].
  int limit(SlotKind kind, [DateTime? now]) =>
      state[kind]!.limit(now ?? DateTime.now());

  /// When the extra slots for [kind] run out; null without any.
  DateTime? bonusExpiry(SlotKind kind, [DateTime? now]) {
    final bonus = state[kind]!;
    return bonus.isActive(now ?? DateTime.now()) ? bonus.expiresAt : null;
  }

  bool canEarnMore(SlotKind kind, [DateTime? now]) => limit(kind, now) < kMaxSlots;

  /// One more slot for [kind] after a watched ad. A new cycle starts when the
  /// previous one expired; within a cycle the expiry stays put.
  Future<void> grant(SlotKind kind, [DateTime? now]) async {
    final t = now ?? DateTime.now();
    final bonus = state[kind]!;
    final next = bonus.isActive(t)
        ? SlotBonus(
            extra: (bonus.extra + 1).clamp(1, kMaxSlots - kBaseSlots),
            expiresAt: bonus.expiresAt,
          )
        : SlotBonus(extra: 1, expiresAt: t.add(kSlotBonusLifetime));
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key(kind), '${next.extra}|${next.expiresAt!.toIso8601String()}');
    state = {...state, kind: next};
  }
}

final slotLimitsProvider =
    NotifierProvider<SlotLimitsNotifier, Map<SlotKind, SlotBonus>>(
  SlotLimitsNotifier.new,
);
