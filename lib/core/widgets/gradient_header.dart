// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GradientHeader extends StatelessWidget {
  const GradientHeader({this.trailing, super.key});
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1F2937) : Colors.white,
      padding: EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.train, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'TunisGO',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
