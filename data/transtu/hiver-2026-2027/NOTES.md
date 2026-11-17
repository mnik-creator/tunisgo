# TRANSTU rail (métro léger 1–6 + TGM), Hiver 2026-2027

`transtu.db` is built by `tools/build_transtu_db.py` from this folder, and is separate from
`sncft.db`. The app attaches it (`DatabaseHelper.attachTranstu`) and reads both through TEMP views.
Checked 2026-11-17.

Files: `stations.csv` (code, names), `lines.csv` (official first/last + peak headway per
line), `patterns.csv` (stop order per line, run minutes from the previous stop),
`sources/` (official TRANSTU images).

## Official facts (TRANSTU)

Poster «توقيت سفرات خطوط المترو والخط ت.ح.م — شتاء 2026-2027»:
<https://www.transtu.tn/fr/0143-marche-horaire-hiver-2026-2027.html> →
`sources/MetroTGMH26-27.jpg` (sha256 12b5e435…87fa, unchanged on 2026-11-17).

| Line | Terminus | First out / in | Last out / in | Peak headway |
|---|---|---|---|---|
| M1 | Ben Arous | 03:52 / 04:26 | 22:30 / 23:00 | 32 |
| M2 | Ariana | 03:54 / 04:30 | 22:36 / 23:06 | 20 |
| M3 | Ibn Khaldoun | 06:40 / 07:15 | 18:30 / 19:02 | 30 |
| M4 | Kheireddine | 03:10 / 04:13 | 22:36 / 23:30 | 20 |
| M5 | Intilaka | 03:43 / 04:26 | 22:36 / 23:12 | 15 |
| M6 | El Mourouj 4 | 03:40 / 04:22 | 22:30 / 23:10 | 20 |
| TGM | La Marsa Plage | 03:30 / 04:15 | 23:45 / 00:30 | 45 |

"Out" (اتجاه الضواحي) is the departure from the central terminus. "In" (اتجاه المحطة) is the
departure **from the suburban terminus**, not the arrival in town. TRANSTU's Ramadan 2026
communiqué confirms this for the TGM: last trains "au départ de Tunis Marine" 22:30 and
"au départ de Marsa Plage" 23:00 (Kapitalis, Tunisie Numérique, La Presse, 2026-02-19).
On every line the first inbound train leaves 34–63 min after the first outbound one. That
is the run time plus a turnaround.

The poster title "(محطة تونس البحرية)" names the hub. Lines M1, M4 and M5 start at
Place de Barcelone and M2 at Place de la République, not at Tunis Marine.

TGM headway: 45 min because of single-track running Le Bac – Tunis Marine (works on the
Chikli bridge; full service resumed 2026-02-20, La Presse). If the second track reopens,
TRANSTU will change it.

Fares (`sources/tgm_fares.jpg`, `sources/metro_fares.jpg`, transtu.tn pages 0067/0068):
TGM 2nd class 0.500 (1 section) / 0.800 (2 sections). Tickets by zone are 0.500 / 1.000 /
1.500; the 1.500 ticket covers "1 ligne métro + 1 ligne bus de rabattement".

## Estimated (the app shows "Horaire estimé" on these trips)

- **All-day headway = the peak headway.** The poster gives only peak headways, so off-peak
  service is probably sparser than what the DB shows. Departures run every headway from the
  first, plus the official last one when it falls off the pattern. Every day, same timetable.
- **Run times:** metro 2 min per stop (no official or open distances without OSM). This is
  consistent with the poster: first inbound minus first outbound is 34–63 min, and the
  model gives 20–38 min plus a turnaround. TGM: 16 min Tunis Marine – Le Bac, then
  0.6 min + 1.5 min/km, 38 min end to end; the 03:30 train reaches La Marsa at 04:08,
  in time for the official 04:15.
- **Times after midnight** are wall-clock (`00:23:00`), like the SNCFT rows.
- **Route colours** in `lines.csv` are placeholders, not TRANSTU's official colours.

## Not included

- Fares, except TGM Tunis Marine ↔ La Marsa Plage (0.800). Section limits and a metro-only
  price are not published.
- Coordinates (NULL): unused by the app, and OSM positions would bring ODbL share-alike.
- Habib Thameur (closed since 2017–2019 according to Wikipedia; trains don't stop).
- Ramadan and summer timetables, and buses (bus posters on the same page also give only
  first/last + headway).

## Station lists and names

Order of stations: French and Arabic Wikipedia line articles (checked 2026-11-17),
cross-checked against thniya (identical order). French names have no diacritics (search
doesn't fold accents). Arabic follows TRANSTU usage ("المرسى الشاطئ", "14 جانفي 2011",
"13 أوت"). SNCFT has served stations named "Le Bardo" and "Mannouba", so the metro ones are
"Le Bardo (Metro)" and "Manouba (Metro)". The TGM's Khereddine is "Khereddine (La Goulette)",
to keep it apart from the metro M4 terminus Kheireddine. L'Aéroport is «المرسى الجوية»
(TRANSTU plan, Arabic Wikipedia), not «المطار».

## Rejected sources

- Official TRANSTU GTFS (`transtu_gtfs1.zip`, data4tunisia, updated 2026-08-15): host
  `data.transport.tn` times out. When it answers, it should replace the estimated times.
- thniya (github.com/mohamedelhafi/thniya): data is **ODbL**. Used only to cross-check;
  nothing copied.
- tunismapper.com: TGM about 68 min end to end, not plausible.
