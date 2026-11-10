// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
//
// One comparable key for a train number, from either side:
//
//   live feed `num`   timetable trip_id                 key
//   205               ligne_a_tunis_erriadh_205         205
//   0005076           mainlines_5/76                    5-76
//   1305072           mainlines_13‑5/72                 13-5-72
//   0512079           mainlines_5-12/79                 5-12-79
//   00TA014           ligne_r_…_14                      14
//   00TM2             ligne_r_ghardimaou_tunis_TM2      TM2
//   TA01025           mainlines_1/25                    1-25
//
// Keys can collide across lines (Bir Aniba shuttle `00TA507` vs Sahel `507`),
// so a key match alone is never enough — see `matchTimetableRow`.

/// Key for a live-feed train number.
String liveTrainKey(String number) {
  final n = number.trim().toUpperCase();
  // 7-digit SNCFT code: AA BB CCC, zero parts omitted (`0005076` -> `5-76`).
  if (RegExp(r'^\d{7}$').hasMatch(n)) {
    return [n.substring(0, 2), n.substring(2, 4), n.substring(4)]
        .map(int.parse)
        .where((p) => p != 0)
        .join('-');
  }
  // `TA01025` -> `1-25` (TA + AA CCC, like the 7-digit code).
  final ta = RegExp(r'^0*TA(\d{2})(\d{3})$').firstMatch(n);
  if (ta != null) {
    return [ta.group(1)!, ta.group(2)!].map(int.parse).where((p) => p != 0).join('-');
  }
  // `00TA014` -> `14`, `00TM2` -> `TM2`.
  final t = RegExp(r'^0*T([AM])0*(\d+)$').firstMatch(n);
  if (t != null) return '${t.group(1) == 'M' ? 'TM' : ''}${t.group(2)}';
  return _joinParts(n);
}

/// Key for a timetable `trips.trip_id` (the number is the last `_` segment).
String timetableTrainKey(String tripCode) {
  final i = tripCode.lastIndexOf('_');
  return _joinParts((i >= 0 ? tripCode.substring(i + 1) : tripCode).toUpperCase());
}

/// Splits on any separator (`-`, `/`, non-breaking hyphen …) and drops
/// leading zeros from numeric parts.
String _joinParts(String s) => s
    .split(RegExp(r'[^A-Z0-9]+'))
    .where((p) => p.isNotEmpty)
    .map((p) => int.tryParse(p)?.toString() ?? p)
    .join('-');
