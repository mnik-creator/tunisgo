// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import '../../l10n/app_localizations.dart';

/// Parses a "HH:MM" string from the DB into minutes since midnight.
/// e.g. "08:30" → 510
/// Returns 0 for empty, null, or malformed values.
int hhmmToMinutes(String hhmm) {
  final trimmed = hhmm.trim();
  if (trimmed.isEmpty) return 0;
  final parts = trimmed.split(':');
  if (parts.length < 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}

/// Converts minutes since midnight to "HH:MM" string.
/// e.g. 510 → "08:30"
String minutesToHHMM(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Bitmask interpretation:
/// bit 0 = Monday … bit 5 = Saturday, bit 6 = Sunday
///   0x7F (127) = all days
///   0x3F  (63) = Mon–Sat (except Sunday)
///   0x40  (64) = Sunday only
String servicesDaysLabel(int bitmask, AppLocalizations loc) {
  const allDays = 0x7F; // 127
  const exceptSunday = 0x3F; // 63
  const sundayOnly = 0x40; // 64

  const weekdays = 0x1F; // 31 = Mon-Fri
  const weekends = 0x60; // 96 = Sat-Sun

  if (bitmask == allDays) return loc.all_days;
  if (bitmask == exceptSunday) return loc.except_sunday;
  if (bitmask == sundayOnly) return loc.sunday_only;
  if (bitmask == weekdays) return loc.filter_weekdays;
  if (bitmask == weekends) return loc.filter_weekend;
  return loc.all_days;
}
