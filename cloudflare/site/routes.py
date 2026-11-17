"""Timetable pages for popular city pairs (e.g. /fr/train/tunis-sousse/),
generated from the app's bundled database so they match what TunisGO shows.
Used by build.py."""
import pathlib
import re
import sqlite3

DB = pathlib.Path(__file__).resolve().parents[2] / "assets/db/sncft.db"

# slug, station ids, names (en, fr, ar, ru)
CITIES = [
    ("tunis", [202], "Tunis", "Tunis", "تونس", "Тунис"),
    ("sousse", [182, 172, 173, 174], "Sousse", "Sousse", "سوسة", "Сусс"),
    ("sfax", [9], "Sfax", "Sfax", "صفاقس", "Сфакс"),
    ("monastir", [171], "Monastir", "Monastir", "المنستير", "Монастир"),
    ("monastir-airport", [179], "Monastir Airport", "Aéroport de Monastir", "مطار المنستير", "Аэропорт Монастир"),
    ("mahdia", [149], "Mahdia", "Mahdia", "المهدية", "Махдия"),
    ("el-jem", [14], "El Jem", "El Jem", "الجم", "Эль-Джем"),
    ("gabes", [3], "Gabès", "Gabès", "قابس", "Габес"),
    ("gafsa", [64], "Gafsa", "Gafsa", "قفصة", "Гафса"),
    ("metlaoui", [70], "Metlaoui", "Metlaoui", "المتلوي", "Метлауи"),
    ("tozeur", [63], "Tozeur", "Tozeur", "توزر", "Тозер"),
    ("bizerte", [213], "Bizerte", "Bizerte", "بنزرت", "Бизерта"),
    ("mateur", [77], "Mateur", "Mateur", "ماطر", "Матер"),
    ("nabeul", [124], "Nabeul", "Nabeul", "نابل", "Набёль"),
    ("hammamet", [121], "Hammamet", "Hammamet", "الحمامات", "Хаммамет"),
    ("grombalia", [27], "Grombalia", "Grombalia", "قرمبالية", "Громбалия"),
    ("beja", [189], "Béja", "Béja", "باجة", "Беджа"),
    ("jendouba", [193], "Jendouba", "Jendouba", "جندوبة", "Джендуба"),
    ("ghardimaou", [195], "Ghardimaou", "Ghardimaou", "غار الدماء", "Гардимау"),
    ("le-kef", [87], "Le Kef", "Le Kef", "الكاف", "Эль-Кеф"),
    ("dahmani", [112], "Dahmani", "Dahmani", "الدهماني", "Дахмани"),
    ("gaafour", [104], "Gaafour", "Gaâfour", "قعفور", "Гаафур"),
    ("hammam-lif", [33], "Hammam-Lif", "Hammam-Lif", "حمام الأنف", "Хаммам-Лиф"),
    ("borj-cedria", [132], "Borj Cédria", "Borj Cédria", "برج السدرية", "Бордж-Седрия"),
]
LANG_INDEX = {"en": 2, "fr": 3, "ar": 4, "ru": 5}

ALL, EXC_SUN, SUN, WEEKDAYS, WEEKENDS, EXC_SAT, MWF, TTS = 0x7F, 0x3F, 0x40, 0x1F, 0x60, 0x5F, 0x15, 0x4A
SERVICE = {"A": EXC_SUN, "B": SUN, "C": WEEKDAYS, "D": WEEKENDS, "D/*": WEEKENDS, "E": EXC_SAT, "F": MWF, "G": TTS}

DAY_NAMES = {
    "en": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
    "fr": ["lun", "mar", "mer", "jeu", "ven", "sam", "dim"],
    "ar": ["الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد"],
    "ru": ["пн", "вт", "ср", "чт", "пт", "сб", "вс"],
}
DAY_LABELS = {
    "en": {ALL: "Daily", EXC_SUN: "Except Sunday", SUN: "Sunday", WEEKDAYS: "Mon–Fri", WEEKENDS: "Sat–Sun", EXC_SAT: "Except Saturday"},
    "fr": {ALL: "Tous les jours", EXC_SUN: "Sauf dimanche", SUN: "Dimanche", WEEKDAYS: "Lun–ven", WEEKENDS: "Sam–dim", EXC_SAT: "Sauf samedi"},
    "ar": {ALL: "يوميًا", EXC_SUN: "ما عدا الأحد", SUN: "الأحد", WEEKDAYS: "الإثنين–الجمعة", WEEKENDS: "السبت–الأحد", EXC_SAT: "ما عدا السبت"},
    "ru": {ALL: "Ежедневно", EXC_SUN: "Кроме воскресенья", SUN: "Воскресенье", WEEKDAYS: "Пн–пт", WEEKENDS: "Сб–вс", EXC_SAT: "Кроме субботы"},
}

PREFIX = re.compile(
    r"^(mainlines_|banlieue_sahel_|banlieue_tunis_|banlieue_|tgm_|ligne_a_tunis_erriadh_|"
    r"ligne_d_tunis_gobaa_ville_|ligne_e_tunis_bougatfa_|ligne_[a-z]_[a-z_]+_|ligne_[a-z]_|ligne_)"
)


def days_label(mask, lang):
    if mask in DAY_LABELS[lang]:
        return DAY_LABELS[lang][mask]
    return ", ".join(d for i, d in enumerate(DAY_NAMES[lang]) if mask >> i & 1)


def minutes(t):
    h, m = t.split(":")[:2]
    return int(h) * 60 + int(m)


def hhmm(t):
    return t[:5]


def connections(db, a_ids, b_ids):
    qa, qb = ",".join("?" * len(a_ids)), ",".join("?" * len(b_ids))
    rows = db.execute(
        f"""
        SELECT t.id, t.trip_id, t.service_id, sa.departure_time, sb.arrival_time,
               sa.stop_days, sb.stop_days, sa.stop_sequence, sb.stop_sequence
        FROM trips t
        JOIN stop_times sa ON sa.trip_id = t.id AND sa.stop_id IN ({qa})
        JOIN stop_times sb ON sb.trip_id = t.id AND sb.stop_id IN ({qb})
        WHERE sa.stop_sequence < sb.stop_sequence
        ORDER BY t.id, sa.stop_sequence DESC, sb.stop_sequence ASC
        """,
        [*a_ids, *b_ids],
    ).fetchall()
    seen, out = set(), []
    for tid, code, service, dep, arr, da, db_, *_ in rows:
        if tid in seen:  # keep the latest boarding / earliest alighting per trip
            continue
        seen.add(tid)
        mask = SERVICE.get(service or "-", ALL) & (da if da is not None else ALL) & (db_ if db_ is not None else ALL)
        if not mask:
            continue
        dur = minutes(arr) - minutes(dep)
        if dur < 0:
            dur += 24 * 60
        out.append({"train": PREFIX.sub("", code), "dep": hhmm(dep), "arr": hhmm(arr), "dur": dur, "mask": mask})
    out.sort(key=lambda c: c["dep"])
    return out


def build_routes():
    """{(from_slug, to_slug): [connections]} for every pair with direct trains."""
    db = sqlite3.connect(DB)
    routes = {}
    for a in CITIES:
        for b in CITIES:
            if a[0] == b[0]:
                continue
            conns = connections(db, a[1], b[1])
            if conns:
                routes[(a[0], b[0])] = conns
    season = db.execute("SELECT value FROM metadata WHERE key='description'").fetchone()
    db.close()
    return routes, (season[0] if season else "")


def city(slug):
    return next(c for c in CITIES if c[0] == slug)


def name(slug, lang):
    return city(slug)[LANG_INDEX[lang]]
