#!/usr/bin/env python3
"""Build transtu.db: the TRANSTU rail lines (métro léger 1–6 and the TGM).

    python3 tools/build_transtu_db.py --out build/db/transtu.db --version 1.0.0

The app attaches this file next to sncft.db (DatabaseHelper) and reads both
through TEMP views, so the tables copy sncft.db's schema (--schema-from) and
every id lives in its own range:
  operators.id 2 · stops.id 10000 + code number (T001 -> 10001) ·
  routes.id 1000 + 10*line + 1/2 · trips.id 100000 + 1000*line + 500*dir + n ·
  stop_times.id 1000001+ · fares.id 101.

TRANSTU publishes no stop-by-stop timetables, only first/last departures and
the peak headway per line (poster "Marche horaire hiver 2026-2027"). Trips are
generated from lines.csv at that headway all day; stop times use the estimated
run times in patterns.csv. See data/transtu/hiver-2026-2027/NOTES.md. Stdlib only.
"""
from __future__ import annotations

import argparse
import csv
import json
import sqlite3
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'data' / 'transtu' / 'hiver-2026-2027'

OPERATOR_ID = 2
STOP_ID_BASE = 10000
STOP_TIME_ID_BASE = 1_000_000
TRIP_PREFIX = {'metro': 'metro_', 'tgm': 'tgm_'}
TABLES = ('operators', 'routes', 'stops', 'trips', 'stop_times', 'calendar',
          'fares', 'metadata', 'fare_rules')
# The end-to-end TGM fare is the only certain one (2e classe, 2 sections, official
# TRANSTU table). Section limits and a metro-only ticket price are not published.
FARES = [(101, 0.8, 'TGM', 'T001', 'T118')]
DESCRIPTION = ('TRANSTU métro léger lines 1-6 and TGM, Hiver 2026-2027. Generated from the official '
               'first/last departures and peak headway (transtu.tn poster); stop times estimated.')


def _minutes(hhmm: str) -> int:
    h, m = hhmm.split(':')
    return int(h) * 60 + int(m)


def _clock(minutes: int) -> str:
    """Wall-clock HH:MM:SS, wrapping after midnight like the SNCFT rows."""
    minutes %= 24 * 60
    return f'{minutes // 60:02d}:{minutes % 60:02d}:00'


def _read(name: str, data: Path) -> list[dict[str, str]]:
    with open(data / name, encoding='utf-8') as f:
        return list(csv.DictReader(f))


def departures(first: str, last: str, headway: int) -> list[int]:
    """Every `headway` minutes from first, plus the official last one."""
    a, b = _minutes(first), _minutes(last)
    if b < a:                       # last departure after midnight
        b += 24 * 60
    times = list(range(a, b + 1, headway))
    if times[-1] != b:
        times.append(b)
    return times


def build(out: Path, schema_from: Path, version: str, data: Path = DATA) -> dict[str, int]:
    if out.exists():
        out.unlink()
    src = sqlite3.connect(schema_from)
    ddl = [sql for name, sql in src.execute(
        "SELECT name, sql FROM sqlite_master WHERE type = 'table'") if name in TABLES]
    src.close()

    con = sqlite3.connect(out)
    for sql in ddl:
        con.execute(sql)
    for sql in ('CREATE INDEX idx_trips_route ON trips(route_id)',
                'CREATE INDEX idx_stop_times_trip ON stop_times(trip_id)',
                'CREATE INDEX idx_stop_times_stop ON stop_times(stop_id)',
                'CREATE INDEX idx_stop_times_trip_seq ON stop_times(trip_id, stop_sequence)',
                'CREATE INDEX idx_stops_name ON stops(name)'):
        con.execute(sql)

    con.execute('INSERT INTO operators (id, name, name_fr, name_ar, timezone, lang) VALUES (?, ?, ?, ?, ?, ?)',
                (OPERATOR_ID, 'TRANSTU', 'Société des Transports de Tunis', 'شركة نقل تونس', 'Africa/Tunis', 'fr'))

    stations = {s['code']: s for s in _read('stations.csv', data)}
    for code, s in stations.items():
        # Coordinates stay NULL: unused by the app, and OpenStreetMap positions
        # would bring ODbL share-alike.
        con.execute(
            'INSERT INTO stops (id, code, name, name_ar, name_ru, latitude, longitude, zone_id) '
            "VALUES (?, ?, ?, ?, ?, NULL, NULL, 'TRANSTU')",
            (STOP_ID_BASE + int(code[1:]), code, s['name'], s['name_ar'], s['name_ru']))

    patterns: dict[str, list[tuple[str, int]]] = {}
    for row in _read('patterns.csv', data):
        if row['code'] not in stations:
            raise SystemExit(f"patterns.csv: unknown stop {row['code']} on {row['line']}")
        patterns.setdefault(row['line'], []).append((row['code'], int(row['min_from_prev'] or 0)))

    used = {c for p in patterns.values() for c, _ in p}
    if unused := set(stations) - used:
        raise SystemExit(f'stations.csv: stops on no line: {sorted(unused)}')

    stop_time_id = STOP_TIME_ID_BASE
    n_trips = 0
    for li, line in enumerate(_read('lines.csv', data), 1):
        label, kind = line['line'], line['kind']
        stops = patterns[label]
        codes = [c for c, _ in stops]
        run = [m for _, m in stops]          # run[i]: minutes from stop i-1 to stop i
        for d, (direction, first, last) in enumerate(
                (('out', line['first_out'], line['last_out']), ('in', line['first_in'], line['last_in']))):
            order = list(range(len(codes))) if d == 0 else list(range(len(codes) - 1, -1, -1))
            offsets, acc = [0], 0
            for prev, cur in zip(order, order[1:]):
                acc += run[max(prev, cur)]
                offsets.append(acc)
            route_id = 1000 + 10 * li + d + 1
            a, b = stations[codes[order[0]]]['name'], stations[codes[order[-1]]]['name']
            con.execute(
                'INSERT INTO routes (id, operator_id, short_name, long_name, type, color, text_color) '
                "VALUES (?, ?, ?, ?, ?, ?, 'FFFFFF')",
                (route_id, OPERATOR_ID, f'{codes[order[0]]}-{codes[order[-1]]}', f'{label} {a}-{b}',
                 0 if kind == 'metro' else 2, line['color']))
            for n, dep in enumerate(departures(first, last, int(line['headway_min'])), 1):
                tid = 100000 + 1000 * li + 500 * d + n
                con.execute('INSERT INTO trips (id, trip_id, route_id, service_id) VALUES (?, ?, ?, ?)',
                            (tid, f'{TRIP_PREFIX[kind]}{label}-{d + 1}{n:03d}', route_id, line['days']))
                for seq, (i, off) in enumerate(zip(order, offsets), 1):
                    stop_time_id += 1
                    t = _clock(dep + off)
                    con.execute(
                        'INSERT INTO stop_times (id, trip_id, stop_id, arrival_time, departure_time, '
                        'stop_sequence, stop_days) VALUES (?, ?, ?, ?, ?, ?, NULL)',
                        (stop_time_id, tid, STOP_ID_BASE + int(codes[i][1:]), t, t, seq))
                n_trips += 1

    rule_id = 100000
    for fid, price, label, o, d in FARES:
        con.execute("INSERT INTO fares (id, fare_id, price, currency_type) VALUES (?, ?, ?, 'TND')",
                    (fid, str(fid), price))
        for origin, dest in ((o, d), (d, o)):
            rule_id += 1
            route = con.execute(
                'SELECT id FROM routes WHERE short_name = ?', (f'{origin}-{dest}',)).fetchone()
            con.execute('INSERT INTO fare_rules (id, fare_id, route_id, origin_id, destination_id) '
                        'VALUES (?, ?, ?, ?, ?)', (rule_id, fid, route[0] if route else None, origin, dest))

    stats = {t: con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]
             for t in ('routes', 'stops', 'trips', 'stop_times', 'fares')}
    meta = {
        'operator': 'TRANSTU',
        'version': version,
        'last_updated': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'description': DESCRIPTION,
        'stats': json.dumps(stats),
    }
    con.executemany('INSERT INTO metadata (key, value) VALUES (?, ?)', meta.items())
    con.commit()
    con.execute('VACUUM')
    con.close()
    return stats


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='build/db/transtu.db')
    ap.add_argument('--schema-from', default='assets/db/sncft.db')
    ap.add_argument('--version', required=True)
    args = ap.parse_args()
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    stats = build(out, Path(args.schema_from), args.version)
    print(f'stats: {stats}')
    print(f'wrote {out}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
