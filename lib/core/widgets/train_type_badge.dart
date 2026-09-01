// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class TrainTypeBadge extends StatelessWidget {
  const TrainTypeBadge({required this.type, super.key});
  final String type;

  static const _colors = {
    'EXPRESS': Color(0xFFEF4444),
    'INTERCITY': Color(0xFF8B5CF6),
    'SUBURBAN': Color(0xFF3B82F6),
    'REGULAR': Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final color = _colors[type] ?? const Color(0xFF6B7280);
    
    final label = switch (type) {
      'EXPRESS' => loc.train_type_express,
      'INTERCITY' => loc.train_type_intercity,
      'SUBURBAN' => loc.train_type_suburban,
      'REGULAR' => loc.train_type_regular,
      _ => type,
    };
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
