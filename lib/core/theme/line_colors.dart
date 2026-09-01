// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';

enum LineCategory { main, suburbanTunis, suburbanSahel }

class LineColors {
  static Color forCategory(LineCategory cat) {
    switch (cat) {
      case LineCategory.main:
        return const Color(0xFFE53935);
      case LineCategory.suburbanTunis:
        return const Color(0xFF1E88E5);
      case LineCategory.suburbanSahel:
        return const Color(0xFF43A047);
    }
  }

  static LineCategory fromLineId(String lineId) {
    final upper = lineId.toUpperCase();
    if (upper.startsWith('T') || upper.contains('TUNIS')) {
      return LineCategory.suburbanTunis;
    }
    if (upper.startsWith('S') || upper.contains('SAHEL')) {
      return LineCategory.suburbanSahel;
    }
    return LineCategory.main;
  }

  static LineCategory fromLineCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'suburban_tunis':
      case 'tgm':
      case 'rfr':
        return LineCategory.suburbanTunis;
      case 'suburban_sahel':
        return LineCategory.suburbanSahel;
      case 'suburban':
        return LineCategory.suburbanTunis;
      default:
        return LineCategory.main;
    }
  }
}
