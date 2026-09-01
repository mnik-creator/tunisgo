// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
class Line {
  const Line({
    required this.id,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    required this.nameRu,
    required this.color,
    required this.lineCategory,
    this.reverseId,
  });

  factory Line.fromMap(Map<String, dynamic> map) {
    final nameFr = map['nameFr'] as String;

    // If the map contains endpoint station names (from getAllLines subqueries),
    // build localized line names as "StartStation — EndStation".
    String buildLocalized(String? start, String? end) {
      if (start != null && start.isNotEmpty && end != null && end.isNotEmpty) {
        return '$start — $end';
      }
      return '';
    }

    final nameAr = (map['nameAr'] as String?)?.isNotEmpty == true
        ? map['nameAr'] as String
        : buildLocalized(
            map['startNameAr'] as String?,
            map['endNameAr'] as String?,
          );
    final nameRu = (map['nameRu'] as String?)?.isNotEmpty == true
        ? map['nameRu'] as String
        : buildLocalized(
            map['startNameRu'] as String?,
            map['endNameRu'] as String?,
          );
    // English uses the French (Latin) name as fallback since no en-specific
    // translations exist in the SNCFT database.
    final nameEn = (map['nameEn'] as String?)?.isNotEmpty == true
        ? map['nameEn'] as String
        : nameFr;

    return Line(
      id: map['id'] as String,
      nameFr: nameFr,
      nameAr: nameAr,
      nameEn: nameEn,
      nameRu: nameRu,
      color: (map['color'] as String?) ?? '#000000',
      lineCategory: (map['lineType'] as String?) ?? 'mainline',
      reverseId: map['reverseId'] as String?,
    );
  }

  final String id;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final String nameRu;
  final String color;
  final String lineCategory;
  /// ID of the route representing the reverse direction, or null if one-way.
  final String? reverseId;

  String localizedName(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return nameAr.isNotEmpty ? nameAr : nameFr;
      case 'en':
        return nameEn.isNotEmpty ? nameEn : nameFr;
      case 'ru':
        return nameRu.isNotEmpty ? nameRu : nameFr;
      default:
        return nameFr;
    }
  }
}
