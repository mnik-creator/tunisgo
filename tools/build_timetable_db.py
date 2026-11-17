#!/usr/bin/env python3
"""Rebuild the trips/stop_times of sncft.db from transcribed poster CSVs.

    python3 tools/build_timetable_db.py \
        --src assets/db/sncft.db \
        --csv data/timetables/hiver-2026-2027 \
        --out build/db/sncft.db \
        --version 2.3.0

Keeps stops, routes, fares and fare_rules from --src; replaces every trip and
stop time with the CSVs. A train whose trip_id already exists keeps its old
`trips.id`, so favourites and scheduled notifications (stored by id) survive
the update. Stdlib only. TRANSTU (métro, TGM) lives in transtu.db instead
(tools/build_transtu_db.py).

CSV formats (see data/timetables/*/):
  * poster layout — rows `station,<train>…`, `type,…`, `days,…`, then one row
    per station; `X ARRIVEE` / `X DEPART` rows merge into one stop; a trailing
    `*` marks a stop served only on some days, per the poster legend in
    STAR_DAYS, stored as a weekday bitmask in `stop_times.stop_days` (NULL =
    whenever the train runs).
  * table layout — header `days,train,<station>…`, one row per train.
"""
from __future__ import annotations

import argparse
import csv
import re
import shutil
import sqlite3
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

# Poster day legends -> calendar.service_id.
DAYS = {
    '-': '-',       # tous les jours
    'X-SUN': 'A',   # sauf dimanches et fêtes
    'SUN': 'B',     # dimanches et fêtes seulement
    'WD': 'C',      # lundi–vendredi non fériés
    'WE': 'D',      # samedis, dimanches et fêtes
    'X-SAT': 'E',   # sauf samedis et veilles de fêtes
    'MWF': 'F',     # lundis, mercredis et vendredis
    'TTS': 'G',     # mardis, jeudis et dimanches
}
CALENDAR = {
    'E': 'Sauf samedi et veilles de fêtes',
    'F': 'Lundi, mercredi, vendredi',
    'G': 'Mardi, jeudi, dimanche',
}

# Weekday bitmask (Mon=1 … Sun=64) for stops marked `*`, per CSV file prefix.
STAR_DAYS = {
    'L6_': 4 | 64,  # TRIKA: arrêt les dimanches et mercredis seulement
}

# trip_id prefix per CSV file (by file-name prefix), following the existing DB.
PREFIXES = [
    ('BL-A_', 'ligne_a_tunis_erriadh_'),
    ('BL-E_', 'ligne_e_tunis_bougatfa_'),
    ('BL-D_', 'ligne_d_tunis_gobaa_ville_'),
    ('BL-S_', 'banlieue_sahel_'),
    ('LTA_tunis_annaba', 'ligne_r_tunis_ghardimaou_'),
    ('LTA_annaba_tunis', 'ligne_r_ghardimaou_tunis_'),
    ('L5_redeyef_metlaoui', 'ligne_r_redeyef_metlaoui_'),
    ('L5_metlaoui_redeyef', 'ligne_r_metlaoui_redeyef_'),
    ('', 'mainlines_'),
]

# Poster spelling -> stops.name, where normalisation alone is not enough.
ALIASES = {
    'AL HRAIRIYA': 'El Hrayria',
    'BAGHDADI': 'Baghdadi',
    'BEN BECHIR': 'Ben Bachir',
    'BIR BOU REGBA': 'Bir Bou Regba',
    'BIR KASSAA': 'Bir Kassa',
    'BORJ EL ARIF': 'Borj Arif',
    'BORJ TOUM': 'Borj Toum',
    'BOU ARGOUB': 'Bou Arkoub',
    'DEPEINNE': 'Depienne',
    'EL KRIB': 'Le Krib',
    'EL OUEDIANE': 'El Oudiane',
    'ENFIDHA': 'Enfida',
    'ERRAOUDHA': 'Cité Erraoudha',
    'EZZAHRA': 'Mahdia Ezzahra',       # Metro du Sahel
    'EZ-ZAHRA': 'Ez-Zahra',            # banlieue sud de Tunis
    'EZZOUHOUR': 'Ezzouhour 2',
    'FEJ ET TAMEUR': 'Fej Tameur',
    'FOUNDOUK JEDID': 'Foundouk Jedid',
    'GOBAA': 'Gobaa',
    'GOBAA VILLE': 'Gobaa Ville',
    'HAMMAM CHATT': 'Hammam Chat',
    'JBEL JELLOUD': 'Jebel Jelloud',
    'JEBEL JELLOUD': 'Jebel Jelloud',
    'JENDOUBA': 'Jendouba V',
    'K MED BENNANE': 'Ksiba Bennane',
    'KALAA SEGHIRA': 'Kalaa Sghira',
    'KHELIDIA': 'Khledia',
    'KHNISS-BEMBLA': 'Khniss Bembla',
    'KSAR HELLAL': 'Ksar Hellal',
    'KSAR HELLAL Z IND': 'Ksar Hellal Zone Industrielle',
    "L'AEROPORT": 'Aeroport Skanes Monastir',
    'LA FACULTE 2': 'La Faculte 2',
    'LES HOTELS': 'Les Hotels Monastir',
    'LYCEE EZZAHRA': 'Lycée Ezzahra',
    'LYCEE RADES': 'Lycee Technique Rades',
    "M'RAZGA": "M'Razka",
    'MAHDIA Z TOURIS': 'Mahdia Zone Touristique',
    'MAHRES': 'Mahares',
    'MANOUBA': 'Mannouba',
    'MEGRINE': 'Megrine',
    'MEGRINE RYADH': 'Megrine Riadh',
    'MELLASSINE': 'Mallassine',
    'MESSAADINE': "M'seken Messadine",
    'MOKNINE GRIBAA': 'Moknine Gribaa',
    'MOKNINE Z IND': 'Moknine Zone Industrielle',
    'MONASTIR Z IND': 'Monastir Zone Industrielle',
    'NAASSEN': 'Nassen',
    'RADES MELIANE': 'Rades Mel',
    'SAHLINE SABKHA': 'Sahline Sebkha',
    'SAYADA': 'Sayeda',
    'SAYADA MANNOUBIA': 'Saida Manoubia',
    'SIDI MESSOUD': 'Sidi Messaoud',
    'SOUSSE BAB JEDID': 'Sousse Bab Jdid',
    'SOUSSE MED V': 'Sousse Mohamed V',
    'SOUSSE Z IND': 'Sousse Zone Industrielle',
    'TABEDDIT (ARRET 1)': 'Tabeddit',
    'TABEDDIT (ARRET 2)': 'Tabeddit',
    'TEBOULBA Z IND': 'Teboulba Zone Industrielle',
}

NB_HYPHEN = '‑'  # keeps "5-13/57" whole in the app's train-number display


def norm(name: str) -> str:
    s = unicodedata.normalize('NFKD', name).encode('ascii', 'ignore').decode().upper()
    s = s.replace('_', ' ')
    s = re.sub(r'\b(GARE|STATION|VILLE|VOYAGEURS|VOY)\b', '', s)
    return re.sub(r'[^A-Z0-9]', '', s)


def hhmmss(t: str) -> str:
    h, m = t.split(':')
    return f'{int(h):02d}:{int(m):02d}:00'


def read_csv(path: Path):
    """Yields (train, days_token, [(poster_station, arr, dep, starred)])."""
    rows = list(csv.reader(path.open(encoding='utf-8')))
    if rows[0][0] == 'station':
        trains = rows[0][1:]
        days = rows[2][1:]
        for col, train in enumerate(trains):
            stops: list[list[str]] = []
            index: dict[str, int] = {}
            for row in rows[3:]:
                cell = row[col + 1].strip() if col + 1 < len(row) else ''
                starred = cell.endswith('*')
                cell = cell.rstrip('*')
                if not cell:
                    continue
                raw = row[0].strip()
                base = re.sub(r'\s+(ARRIVEE|DEPART)$', '', raw)
                if base in index and raw.endswith('DEPART'):
                    stops[index[base]][2] = cell
                    stops[index[base]][3] |= starred
                    continue
                index[base] = len(stops)
                stops.append([base, cell, cell, starred])
            yield train, days[col], [tuple(s) for s in stops]
    else:
        header = rows[0]
        for row in rows[1:]:
            stops = [(header[i], v.rstrip('*'), v.rstrip('*'), v.strip().endswith('*'))
                     for i, v in enumerate(row[2:], 2) if v.strip()]
            yield row[1], row[0], stops


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', default='assets/db/sncft.db')
    ap.add_argument('--csv', default='data/timetables/hiver-2026-2027')
    ap.add_argument('--out', default='build/db/sncft.db')
    ap.add_argument('--version', required=True)
    args = ap.parse_args()

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.src, out)
    con = sqlite3.connect(out)
    con.execute('PRAGMA foreign_keys = OFF')

    stops = {name: sid for sid, name in con.execute('SELECT id, name FROM stops')}
    stop_names = {sid: name for name, sid in stops.items()}
    by_norm: dict[str, list[str]] = {}
    for name in stops:
        by_norm.setdefault(norm(name), []).append(name)

    def resolve(poster: str) -> int:
        if poster in ALIASES:
            return stops[ALIASES[poster]]
        exact = [n for n in stops if n.upper() == poster.upper()]
        if exact:
            return stops[exact[0]]
        candidates = by_norm.get(norm(poster), [])
        if len(candidates) == 1:
            return stops[candidates[0]]
        raise SystemExit(f'Unresolved station {poster!r} (candidates: {candidates})')

    routes = list(con.execute(
        'SELECT r.id, r.long_name, (SELECT COUNT(*) FROM trips t WHERE t.route_id = r.id) FROM routes r'))
    stop_codes = {sid: code for sid, code in con.execute('SELECT id, code FROM stops')}

    def route_for(first: int, last: int, line_default: int | None) -> int:
        """Route with these endpoints (one that already had trips first), else
        the route this line's trains used before (suburban short turns stay on
        their line), else a new one."""
        a, b = norm(stop_names[first]), norm(stop_names[last])
        matches = []
        for rid, long_name, used in routes:
            parts = (long_name or '').split('-')
            if len(parts) == 2 and norm(parts[0]) == a and norm(parts[1]) == b:
                matches.append((-used, rid))
        if matches:
            return min(matches)[1]
        if line_default is not None:
            return line_default
        label = lambda sid: 'Tunis Ville' if stop_names[sid] == 'Tunis' else stop_names[sid]
        cur = con.execute(
            'INSERT INTO routes (operator_id, short_name, long_name, type, color, text_color) '
            "VALUES (1, ?, ?, 2, '808080', 'FFFFFF')",
            (f'{stop_codes[first]}-{stop_codes[last]}', f'{label(first)}-{label(last)}'))
        routes.append((cur.lastrowid, f'{label(first)}-{label(last)}', 1))
        print(f'  new route {cur.lastrowid}: {label(first)}-{label(last)}')
        return cur.lastrowid

    old_ids = {code: tid for tid, code in con.execute('SELECT id, trip_id FROM trips')}
    old_routes = {code: rid for code, rid in con.execute('SELECT trip_id, route_id FROM trips')}
    next_id = max(old_ids.values(), default=0) + 1

    if 'stop_days' not in [c[1] for c in con.execute('PRAGMA table_info(stop_times)')]:
        con.execute('ALTER TABLE stop_times ADD COLUMN stop_days INTEGER')
    con.execute('DELETE FROM stop_times')
    con.execute('DELETE FROM trips')
    for code, desc in CALENDAR.items():
        con.execute('INSERT OR IGNORE INTO calendar (service_id, description) VALUES (?, ?)', (code, desc))

    kept = added = n_stop_times = 0
    seen: set[str] = set()
    for path in sorted(Path(args.csv).glob('*.csv')):
        prefix = next(p for key, p in PREFIXES if path.name.startswith(key))
        star_days = next((d for key, d in STAR_DAYS.items() if path.name.startswith(key)), None)
        file_trains = list(read_csv(path))
        previous = [old_routes[prefix + t.replace('-', NB_HYPHEN)] for t, _, _ in file_trains
                    if prefix + t.replace('-', NB_HYPHEN) in old_routes]
        suburban = path.name.startswith('BL-') or 'banlieue' in path.name
        line_default = max(set(previous), key=previous.count) if previous and suburban else None
        for train, days, calls in file_trains:
            trip_code = prefix + train.replace('-', NB_HYPHEN)
            if trip_code in seen:
                raise SystemExit(f'Duplicate trip {trip_code} in {path.name}')
            seen.add(trip_code)
            if len(calls) < 2:
                raise SystemExit(f'{trip_code}: fewer than two stops')
            stop_ids = [resolve(name) for name, _, _, _ in calls]
            if any(c[3] for c in calls) and star_days is None:
                raise SystemExit(f'{path.name}: `*` stop but no STAR_DAYS legend for this file')
            if trip_code in old_ids:
                tid = old_ids[trip_code]
                kept += 1
            else:
                tid = next_id
                next_id += 1
                added += 1
            con.execute(
                'INSERT INTO trips (id, trip_id, route_id, service_id) VALUES (?, ?, ?, ?)',
                (tid, trip_code, route_for(stop_ids[0], stop_ids[-1], line_default), DAYS[days]))
            for seq, (sid, (_, arr, dep, starred)) in enumerate(zip(stop_ids, calls), 1):
                con.execute(
                    'INSERT INTO stop_times (trip_id, stop_id, arrival_time, departure_time, stop_sequence, stop_days) '
                    'VALUES (?, ?, ?, ?, ?, ?)',
                    (tid, sid, hhmmss(arr), hhmmss(dep), seq, star_days if starred else None))
                n_stop_times += 1

    stats = {t: con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]
             for t in ('routes', 'stops', 'trips', 'stop_times', 'fares')}
    meta = {
        'version': args.version,
        'last_updated': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'description': f'Hiver 2026-2027 timetable (01/09/2026-30/06/2027) rebuilt from SNCFT posters '
                       f'({Path(args.csv).name}). Ramadan schedule not included.',
        'stats': str(stats).replace("'", '"'),
    }
    for key, value in meta.items():
        con.execute('INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)', (key, value))
    con.commit()
    con.execute('VACUUM')
    con.close()

    print(f'trips: {kept} kept id, {added} new · stop_times: {n_stop_times}')
    print(f'stats: {stats}')
    print(f'wrote {out}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
