// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

/// Provider for SharedPreferences - must be overridden with a real instance at runtime.
/// In main.dart, this is overridden via:
///   sharedPreferencesProvider.overrideWithValue(prefs)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'sharedPreferencesProvider must be overridden in main.dart with a real SharedPreferences instance.',
  );
});

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_kLocaleKey);
    return saved != null ? Locale(saved) : const Locale('fr');
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
