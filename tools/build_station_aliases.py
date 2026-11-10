#!/usr/bin/env python3
"""Regenerate lib/features/live/station_aliases.dart from the live feed + bundled DB.

The SNCFT live feed names stations its own way ("TUNIS VILLE", "Jebel Jelloud",
"SOUSSE BAB JEDID"), the app's GTFS-like `stops` table uses another ("Tunis
Ville", "Djebal Jelloud", "Sousse Bab Jdid").  This script observes every stop
name the feed currently emits, matches it against the DB (exact normalised match
first, then a conservative fuzzy pass), and writes a Dart const map so the app
never has to guess at runtime.

Run after every timetable DB rebuild:

    python3 tools/build_station_aliases.py --db assets/db/sncft.db

Requires only the standard library.  Review the printed "unresolved" list: those
are stops the feed knows about but the timetable lacks (add them to the DB, or
live trains calling there will simply have no coordinates).
"""
from __future__ import annotations

import argparse
import difflib
import json
import os
import re
import sqlite3
import sys
import unicodedata
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import quote

AJAX = "https://www.sncft.com.tn/wp-admin/admin-ajax.php"
UA = "Mozilla/5.0 (compatible; tunisgo-alias-builder/1.0)"

# Names the feed uses that the DB spells differently, verified by hand.
MANUAL_ALIASES = {
    "LYCEE EZZAHRA": "Ezzahra Lycée",
    "LA FACULTE MONASTIR": "La Faculte",
    "TEBOULBA ZONE INDUSTRIELLE": "Teboulba Zi",
    "SOUSSE BAB JEDID": "Sousse Bab Jdid",
}

TECHNICAL_PREFIXES = ("AIG",)  # aiguilles / junctions, no passengers


def normalize(name: str) -> str:
    s = unicodedata.normalize("NFKD", name or "").encode("ascii", "ignore").decode()
    s = s.upper()
    s = re.sub(r"\b(GARE|STATION|VILLE|VOYAGEURS|VOY)\b", "", s)
    return re.sub(r"[^A-Z0-9]", "", s)


def fetch(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.loads(r.read().decode("utf-8"))


def observe_stop_names() -> dict[str, str]:
    """LOC_NAME -> ANAME for every stop the feed is currently serving."""
    trains = fetch(f"{AJAX}?action=sncft_get_trains")
    with ThreadPoolExecutor(max_workers=6) as pool:
        details = list(
            pool.map(
                lambda t: fetch(f"{AJAX}?action=sncft_get_details&id={t['id']}"),
                trains,
            )
        )
    names: dict[str, str] = {}
    for rows in details:
        if isinstance(rows, list):
            for row in rows:
                names.setdefault(row.get("LOC_NAME", ""), row.get("ANAME", ""))
    names.pop("", None)
    return names


def dart_escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace("'", "\\'")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default="assets/db/sncft.db")
    ap.add_argument("--out", default="lib/features/live/station_aliases.dart")
    ap.add_argument("--cutoff", type=float, default=0.86, help="fuzzy match threshold")
    args = ap.parse_args()

    # Open read-only: the DB may live in a read-only checkout, and this tool
    # must never touch the shipped asset.
    db_uri = f"file:{quote(os.path.abspath(args.db))}?mode=ro&immutable=1"
    con = sqlite3.connect(db_uri, uri=True)
    stop_names = [row[0] for row in con.execute("SELECT name FROM stops")]
    by_key = {normalize(n): n for n in stop_names}

    live_names = observe_stop_names()
    aliases: dict[str, str] = {}
    technical: list[str] = []
    unresolved: list[str] = []

    for live_name in live_names:
        key = normalize(live_name)
        if key.startswith(TECHNICAL_PREFIXES) or "AIGUILLE" in key:
            technical.append(key)
            continue
        if key in by_key:
            aliases[key] = by_key[key]
            continue
        close = difflib.get_close_matches(key, list(by_key), n=1, cutoff=args.cutoff)
        if close:
            aliases[key] = by_key[close[0]]
        else:
            unresolved.append(live_name)

    for live_name, db_name in MANUAL_ALIASES.items():
        if db_name in stop_names:
            aliases[normalize(live_name)] = db_name

    unresolved = [n for n in unresolved if normalize(n) not in aliases]
    print(f"mapped {len(aliases)} · technical {len(technical)} · unresolved {len(unresolved)}")
    for name in unresolved:
        print(f"  unresolved: {name!r} (add it to the stops table)")

    entries = "\n".join(
        f"  '{k}': '{dart_escape(v)}'," for k, v in sorted(aliases.items())
    )
    tech_entries = "\n".join(f"  '{k}'," for k in sorted(technical))
    body = f"""// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
//
// GENERATED FILE — do not edit by hand.
// Regenerate after every timetable DB rebuild:
//   python3 tools/build_station_aliases.py --db assets/db/sncft.db
//
// Observed {len(live_names)} distinct stop names in the public SNCFT live feed.
// Coverage: {len(aliases)} mapped, {len(technical)} technical switch points ignored, {len(unresolved)} stops
// absent from the local timetable. Unknown names are passed through unchanged so
// a train never silently disappears.

/// Normalised live stop name -> canonical `stops.name` in the bundled DB.
const Map<String, String> kLiveStopAliases = <String, String>{{
{entries}
}};

/// Switch/junction points reported by the feed that carry no passengers.
const Set<String> kTechnicalStops = <String>{{
{tech_entries}
}};

/// Uppercase ASCII-only key: strips accents, punctuation and the noisy words
/// the feed sprinkles into station names (GARE, VILLE, VOYAGEURS).
String normalizeStationName(String raw) {{
  final upper = raw.toUpperCase();
  final withoutNoise = upper.replaceAll(
    RegExp(r'\\b(GARE|STATION|VILLE|VOYAGEURS|VOY)\\b'),
    '',
  );
  return withoutNoise.replaceAll(RegExp(r'[^A-Z0-9]'), '');
}}

/// Returns the bundled stop name, or null for technical (non-passenger) points.
String? resolveStopName(String liveName) {{
  final key = normalizeStationName(liveName);
  if (kTechnicalStops.contains(key)) return null;
  return kLiveStopAliases[key] ?? liveName;
}}
"""
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(body)
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
