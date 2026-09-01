// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/gradient_header.dart';
import '../core/helpers/locale_provider.dart';
import '../l10n/app_localizations.dart';

class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final location = GoRouterState.of(context).uri.toString();

    final tabs = [
      (
        path: '/search',
        label: loc.search,
        icon: Icons.search_outlined,
        activeIcon: Icons.search,
      ),
      (
        path: '/lines',
        label: loc.lines,
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
      ),
      (
        path: '/settings',
        label: loc.settings,
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
      ),
    ];

    int currentIndex = 0;
    for (var i = 0; i < tabs.length; i++) {
      if (location.startsWith(tabs[i].path)) {
        currentIndex = i;
      }
    }

    // Language cycle for header trailing button
    const langCodes = ['fr', 'ar', 'en', 'ru'];
    void cycleLanguage() {
      final current = locale.languageCode;
      final idx = langCodes.indexOf(current);
      final next = langCodes[(idx + 1) % langCodes.length];
      ref.read(localeProvider.notifier).setLocale(Locale(next));
    }

    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          GradientHeader(
            trailing: GestureDetector(
              onTap: cycleLanguage,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  locale.languageCode.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            type: MaterialType.transparency,
            child: _FloatingNavBar(
              tabs: tabs,
              currentIndex: currentIndex,
              onTap: (i) => context.go(tabs[i].path),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<({String path, String label, IconData icon, IconData activeIcon})>
      tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // True iOS liquid-glass tint — very low alpha so the blurred content shows through
    final glassTop = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.45);
    final glassBottom = isDark
        ? const Color(0xFF0D1117).withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.25);

    // Hairline border shimmer
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.80);

    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: borderColor, width: 1.0),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [glassTop, glassBottom],
                ),
                boxShadow: [
                  BoxShadow(
                    color: kEmerald500.withValues(alpha: isDark ? 0.12 : 0.08),
                    blurRadius: 24,
                    spreadRadius: -6,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(tabs.length, (i) {
                    final tab = tabs[i];
                    final isActive = i == currentIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(i),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? LinearGradient(
                                    colors: [
                                      kEmerald500.withValues(alpha: isDark ? 0.28 : 0.18),
                                      kTeal600.withValues(alpha: isDark ? 0.18 : 0.10),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(18),
                            border: isActive
                                ? Border.all(
                                    color: kEmerald500.withValues(
                                        alpha: isDark ? 0.30 : 0.25),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isActive ? tab.activeIcon : tab.icon,
                                  key: ValueKey(isActive),
                                  size: 22,
                                  color: isActive
                                      ? kEmerald500
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.45)
                                          : Colors.grey.shade500),
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isActive
                                      ? kEmerald500
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.45)
                                          : Colors.grey.shade500),
                                  letterSpacing: isActive ? 0.2 : 0,
                                ),
                                child: Text(tab.label),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
