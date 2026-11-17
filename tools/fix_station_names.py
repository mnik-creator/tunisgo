#!/usr/bin/env python3
"""Align stop names in sncft.db with the names SNCFT itself uses.

Source of truth: the SNCFT live feed (www.sncft.com.tn, LOC_NAME / ANAME), checked
2026-11-16. The original import invented some names ("Sousse Voyageurs") and
machine-transliterated many Arabic names ("مقنيز" for Moknine). Stop ids are kept,
so favourites and reminders stored by id are unaffected.

    python3 tools/fix_station_names.py assets/db/sncft.db assets/initial/sncft.db

Idempotent. Remember to update ALIASES in build_timetable_db.py and regenerate
lib/features/live/station_aliases.dart when names change.
"""
import re
import sqlite3
import sys

# old name -> (new name, new Arabic or None to keep, new Russian or None to keep)
FIXES = {
    "Sousse Voyageurs": ("Sousse", "سوسة", "Сусс"),
    "Moknine Voyageurs": ("Moknine", "مكنين", "Мокнин"),
    "Moknine Griba": ("Moknine Gribaa", "مكنين قريبعة", "Мокнин-Грибаа"),
    "Moknine Marchandises": (None, "مكنين البضائع", None),
    "Moknine Zone Industrielle": (None, "مكنين المنطقة الصناعية", None),
    "Teboulba": (None, "طبلبة", None),
    "Teboulba Zi": ("Teboulba Zone Industrielle", "طبلبة المنطقة الصناعية", None),
    "Sahline Ville": ("Sahline", "ساحلين", "Сахлин"),
    "Sahline Sebkha": (None, "ساحلين سبخة", None),
    "Ksar Helal": ("Ksar Hellal", None, None),
    "Ksar Helal Zone Industrielle": ("Ksar Hellal Zone Industrielle", None, None),
    "Ezzahra Lycée": ("Lycée Ezzahra", "معهد الزهراء", None),
    "Baghdedi": ("Baghdadi", "البغدادي", None),
    "Benbachir": ("Ben Bachir", "بن باشير", None),
    "Bir Bourekba": ("Bir Bou Regba", "بئر بورقبة", None),
    "Borj Ettoum": ("Borj Toum", "برج التومي", None),
    "Djebal Jelloud": ("Jebel Jelloud", None, None),
    "Fej Etameur": ("Fej Tameur", "فج التمر", None),
    "Fondouk Jedid": ("Foundouk Jedid", "فندق الجديد", None),
    "kalaa Sghira": ("Kalaa Sghira", None, None),
    "Khnis/Bembla": ("Khniss Bembla", "خنيس بنبلة", None),
    "Megrine Ryad": ("Megrine Riadh", None, None),
    "Sidi Masaoud": ("Sidi Messaoud", None, "Сиди-Мессауд"),
    "Beja Voy": ("Beja Voyageurs", "باجة", None),
    "Nabeul Voyageurs": (None, "نابل", None),
    # Arabic only, as spelled by SNCFT.
    "Ain Mesria": (None, "عين مسرية", None),
    "Aouinet": (None, "العوينات", None),
    "Arret Du Stade": (None, "محطة الستاد", None),
    "Bekalta": (None, "البقالطة", None),
    "Bir El Bey": (None, "بئر الباي", None),
    "Bir Kassa": (None, "بئر القصعة", None),
    "Bir M'Cherga": (None, "بئر مشارقة", None),
    "Borj Arif": (None, "برج العريف", None),
    "Bou Arada": (None, "بوعرادة", None),
    "Bou Arkoub": (None, "بوعرقوب", None),
    "Bouficha": (None, "بوفيشة", None),
    "Bou Kornine": (None, "بوقرنين", None),
    "Bou Salem": (None, "بوسالم", None),
    "Cité Erraoudha": (None, "حي الروضة", None),
    "Dahmani": (None, "الدهماني", None),
    "Depienne": (None, "سمنجة", None),
    "Depot Farhat Hached": (None, "مستودع فرحات حشاد", None),
    "El Akhouat": (None, "الاخوات", None),
    "Gaafour": (None, "قعفور", None),
    "Ghannouch": (None, "غنوش", None),
    "Ghardimaou": (None, "غار الدماء", None),
    "Ghraiba": (None, "الغريبة", None),
    "Gouraia": (None, "القراعية", None),
    "Grombalia": (None, "قرمبالية", None),
    "Hamada": (None, "الحمادة", None),
    "Jedeida": (None, "الجديدة", None),
    "Kalaa Khasba": (None, "قلعة خصبة", None),
    "Khanguet": (None, "الخنقات", None),
    "Khledia": (None, "الخليدية", None),
    "Le Krib": (None, "الكريب", None),
    "Le Sers": (None, "السرس", None),
    "Les Hotels Monastir": (None, "النزل", None),
    "Les Salines": (None, "الملاحات", None),
    "Lycee Technique Rades": (None, "معهد رادس التقني", None),
    "Mahares": (None, "المحرس", None),
    "Maknassy": (None, "المكناسي", None),
    "Mannouba": (None, "منوبة", None),
    "Mastouta": (None, "مستوتة", None),
    "Mejez El Bab": (None, "مجاز الباب", None),
    "Nassen": (None, "نعسان", None),
    "Omar Khayem": (None, "عمر الخيام", None),
    "Oudna": (None, "الودنة", None),
    "Oued Ellil": (None, "واد الليل", None),
    "Oued Meliz": (None, "واد مليز", None),
    "Oued Sarrath": (None, "واد سراط", None),
    "Oued Zarga": (None, "واد الزرقاء", None),
    "Pont Du Fahs": (None, "الفحص", None),
    "Sakiet Ezzit": (None, "ساقية الزيت", None),
    "Sened": (None, "السند", None),
    "Sidi Ayed": (None, "سيدي عياد", None),
    "Sidi Bou Ali": (None, "سيدي بوعلي", None),
    "Sidi Rezig": (None, "سيدي رزيق", None),
    "Sidi Smail": (None, "سيدي إسماعيل", None),
    "Sousse Bab Jdid": (None, "سوسة باب الجديد", None),
    "Sousse Sud": (None, "سوسة الجنوبية", None),
    "Tahar Sfar": (None, "الطاهر صفر", None),
    "Tebourba": (None, "طبربة", None),
    "Trika": (None, "تريكة", None),
    "Turki": (None, "التركي", None),
}


def apply(path: str) -> int:
    con = sqlite3.connect(path)
    changed = 0
    for old, (name, ar, ru) in FIXES.items():
        row = con.execute("SELECT id FROM stops WHERE name = ?", (old,)).fetchone()
        if not row:
            continue
        sid = row[0]
        if name:
            con.execute("UPDATE stops SET name = ? WHERE id = ?", (name, sid))
        if ar:
            con.execute("UPDATE stops SET name_ar = ? WHERE id = ?", (ar, sid))
        if ru:
            con.execute("UPDATE stops SET name_ru = ? WHERE id = ?", (ru, sid))
        changed += 1
    # Route names repeat stop names ("Tunis Ville-Sousse Voyageurs").
    renames = [(re.compile(rf"(?<!\w){re.escape(o)}(?!\w)"), n) for o, (n, _, _) in FIXES.items() if n]
    for rid, long_name in con.execute("SELECT id, long_name FROM routes").fetchall():
        fixed = long_name or ""
        for rx, n in renames:
            fixed = rx.sub(n, fixed)
        if fixed != (long_name or ""):
            con.execute("UPDATE routes SET long_name = ? WHERE id = ?", (fixed, rid))
    con.commit()
    con.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    con.close()
    return changed


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(p, apply(p), "stops updated")
