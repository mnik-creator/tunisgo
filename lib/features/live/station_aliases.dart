// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
//
// GENERATED FILE — do not edit by hand.
// Regenerate after every timetable DB rebuild:
//   python3 tools/build_station_aliases.py --db assets/db/sncft.db
//
// Source: 146 distinct stop names observed in the public SNCFT live feed
// (80 concurrent services), matched against the bundled `stops` table.
// Coverage: 141 mapped, 2 technical switch points ignored, 3 stops
// absent from the local timetable (RADES MELIANE, Sayada, M'Razga). Unknown names are
// passed through unchanged so a train never silently disappears.

/// Normalised live stop name -> canonical `stops.name` in the bundled DB.
const Map<String, String> kLiveStopAliases = <String, String>{
  'AEROPORTSKANESMONASTIR': 'Aeroport Skanes Monastir',
  'AINGHELAL': 'Ain Ghelal',
  'AINMESRIA': 'Ain Mesria',
  'AINRAHMA': 'Ain Rahma',
  'AOUINET': 'Aouinet',
  'ARRETDUSTADE': 'Arret Du Stade',
  'BAGHDADI': 'Baghdedi',
  'BEJA': 'Beja Voy',
  'BEKALTA': 'Bekalta',
  'BENBACHIR': 'Benbachir',
  'BIRANIBA': 'Bir Aniba',
  'BIRBOUREGBA': 'Bir Bourekba',
  'BIRELBEY': 'Bir El Bey',
  'BIRKASSA': 'Bir Kassa',
  'BIRMCHERGA': 'Bir M\'Cherga',
  'BIZERTE': 'Bizerte',
  'BORJARIF': 'Borj Arif',
  'BORJCEDRIA': 'Borj Cedria',
  'BORJTOUM': 'Borj Ettoum',
  'BOUARADA': 'Bou Arada',
  'BOUARKOUB': 'Bou Arkoub',
  'BOUFICHA': 'Bouficha',
  'BOUHJAR': 'Bouhjar',
  'BOUKORNINE': 'Bou Kornine',
  'BOUSALEM': 'Bou Salem',
  'CHAOUAT': 'Chaouat',
  'CHEYLUS': 'Cheylus',
  'CITEERRAOUDHA': 'Cité Erraoudha',
  'DAHMANI': 'Dahmani',
  'DEGUECHE': 'Degueche',
  'DEPIENNE': 'Depienne',
  'DEPOTFARHATHACHED': 'Depot Farhat Hached',
  'ELAKHOUAT': 'El Akhouat',
  'ELAROUSSA': 'El Aroussa',
  'ELJEM': 'El Jem',
  'ENFIDA': 'Enfida',
  'ERRIADH': 'Erriadh',
  'EZZAHRA': 'Ez-Zahra',
  'FEJTAMEUR': 'Fej Etameur',
  'FOUNDOUKJEDID': 'Fondouk Jedid',
  'FOUNI': 'Founi',
  'GAAFOUR': 'Gaafour',
  'GABES': 'Gabes',
  'GAFSA': 'Gafsa',
  'GHANNOUCH': 'Ghannouch',
  'GHARDIMAOU': 'Ghardimaou',
  'GHRAIBA': 'Ghraiba',
  'GOURAIA': 'Gouraia',
  'GROMBALIA': 'Grombalia',
  'HAMADA': 'Hamada',
  'HAMMAMCHAT': 'Hammam Chat',
  'HAMMAMET': 'Hammamet',
  'HAMMAMLIF': 'Hammam Lif',
  'JEBELJELLOUD': 'Djebal Jelloud',
  'JEDEIDA': 'Jedeida',
  'JENDOUBA': 'Jendouba V',
  'KALAAKHASBA': 'Kalaa Khasba',
  'KALAKEBIRA': 'Kalaa Kebira',
  'KALASGHIRA': 'kalaa Sghira',
  'KERKER': 'Kerker',
  'KHANGUET': 'Khanguet',
  'KHLEDIA': 'Khledia',
  'KHNISSBEMBLA': 'Khnis/Bembla',
  'KSARHELAL': 'Ksar Helal',
  'KSARHELLALZONEINDUSTRIELLE': 'Ksar Helal Zone Industrielle',
  'KSIBABENNANE': 'Ksiba Bennane',
  'LAFACULTEMONASTIR': 'La Faculte',
  'LAHENCHA': 'La Hencha',
  'LAMTA': 'Lamta',
  'LAPECHERIE': 'La Pecherie',
  'LEBARDO': 'Le Bardo',
  'LEKEF': 'Le Kef',
  'LEKRIB': 'Le Krib',
  'LESERS': 'Le Sers',
  'LESHOTELSMONASTIR': 'Les Hotels Monastir',
  'LESSALINES': 'Les Salines',
  'LESZOUARINES': 'Les Zouarines',
  'LYCEEEZZAHRA': 'Ezzahra Lycée',
  'LYCEETECHNIQUERADES': 'Lycee Technique Rades',
  'MAHARES': 'Mahares',
  'MAHDIA': 'Mahdia',
  'MAHDIAEZZAHRA': 'Mahdia Ezzahra',
  'MAHDIAZONETOURISTIQUE': 'Mahdia Zone Touristique',
  'MAKNASSY': 'Maknassy',
  'MANNOUBA': 'Mannouba',
  'MASTOUTA': 'Mastouta',
  'MATEUR': 'Mateur',
  'MEGRINE': 'Megrine',
  'MEGRINERYADH': 'Megrine Ryad',
  'MEJEZELBAB': 'Mejez El Bab',
  'MENZEL': 'Menzel Gare',
  'MENZELBOUZAIANE': 'Menzel Bouzaiane',
  'METLAOUI': 'Metlaoui',
  'MEZZOUNA': 'Mezzouna',
  'MOKNINE': 'Moknine Voyageurs',
  'MOKNINEGRIBAA': 'Moknine Griba',
  'MONASTIR': 'Monastir',
  'MONASTIRZONEINDUSTRIELLE': 'Monastir Zone Industrielle',
  'MSAKEN': 'M\'Saken',
  'NABEUL': 'Nabeul Voyageurs',
  'NABEULMARCHANDISES': 'Nabeul Marchandise',
  'NASSEN': 'Nassen',
  'OMARKHAYEM': 'Omar Khayem',
  'OUDNA': 'Oudna',
  'OUEDELLIL': 'Oued Ellil',
  'OUEDMELIZ': 'Oued Meliz',
  'OUEDSARRATH': 'Oued Sarrath',
  'OUEDZARGA': 'Oued Zarga',
  'PONTDUFAHS': 'Pont Du Fahs',
  'RADES': 'Rades',
  'SAHLINE': 'Sahline Ville',
  'SAHLINESEBKHA': 'Sahline Sebkha',
  'SAKIETEZZIT': 'Sakiet Ezzit',
  'SENED': 'Sened',
  'SFAX': 'Sfax',
  'SIDIAYED': 'Sidi Ayed',
  'SIDIBOUALI': 'Sidi Bou Ali',
  'SIDIBOUROUIS': 'Sidi Bou Rouis',
  'SIDIMESSAOUD': 'Sidi Masaoud',
  'SIDIMHIMECH': 'Sidi M\'Himech',
  'SIDIMTIR': 'Sidi Mtir',
  'SIDIOTHMAN': 'Sidi Othman',
  'SIDIREZIG': 'Sidi Rezig',
  'SIDISALAH': 'Sidi Salah',
  'SIDISMAIL': 'Sidi Smail',
  'SKHIRA': 'Skhira',
  'SOUSSE': 'Sousse Voyageurs',
  'SOUSSEBABJEDID': 'Sousse Bab Jdid',
  'SOUSSEMOHAMEDV': 'Sousse Mohamed V',
  'SOUSSESUD': 'Sousse Sud',
  'SOUSSEZONEINDUSTRIELLE': 'Sousse Zone Industrielle',
  'TAHARSFAR': 'Tahar Sfar',
  'TEBOULBA': 'Teboulba',
  'TEBOULBAZONEINDUSTRIELLE': 'Teboulba Zi',
  'TEBOURBA': 'Tebourba',
  'TINJA': 'Tinja',
  'TOZEUR': 'Tozeur',
  'TRIKA': 'Trika',
  'TUNIS': 'Tunis',
  'TURKI': 'Turki',
  'ZANNOUCH': 'Zannouch',
};

/// Switch/junction points reported by the feed that carry no passengers.
const Set<String> kTechnicalStops = <String>{
  'AIGMSAKENL5',
  'AIGSSL22',
};

/// Uppercase ASCII-only key: strips accents, punctuation and the noisy words
/// the feed sprinkles into station names (GARE, VILLE, VOYAGEURS).
String normalizeStationName(String raw) {
  final upper = raw.toUpperCase();
  final withoutNoise = upper.replaceAll(
    RegExp(r'\b(GARE|STATION|VILLE|VOYAGEURS|VOY)\b'),
    '',
  );
  return withoutNoise.replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

/// Returns the bundled stop name, or null for technical (non-passenger) points.
String? resolveStopName(String liveName) {
  final key = normalizeStationName(liveName);
  if (kTechnicalStops.contains(key)) return null;
  return kLiveStopAliases[key] ?? liveName;
}
