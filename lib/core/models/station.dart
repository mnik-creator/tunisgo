// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
class Station {
  const Station({
    required this.id,
    required this.slug,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    required this.nameRu,
    required this.isActive,
  });

  factory Station.fromMap(Map<String, dynamic> map) => Station(
    id: map['id'] as String,
    slug: map['slug'] as String,
    nameFr: map['nameFr'] as String,
    nameAr: (map['nameAr'] as String?) ?? '',
    nameEn: (map['nameEn'] as String?) ?? '',
    nameRu: (map['nameRu'] as String?) ?? '',
    isActive: map['isActive'] == 1 || map['isActive'] == true,
  );

  final String id;
  final String slug;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final String nameRu;
  final bool isActive;

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
