# TunisGO — Public Transit Navigation for Tunisia

TunisGO is an unofficial mobile transit navigation app for Tunisia's transportation network (now SNCFT), built with Flutter. It provides offline-first access to train schedules, real-time journey planning, and notifications for the Tunisian railway network.

## Features

- **Offline schedules** — Full SNCFT timetable stored locally; no internet required to browse trains
- **Journey planner** — Point-to-point search across all 77 routes, 238 stops
- **Line browser** — Explore every line with departure times, days of operation, and fare information
- **Favorites** — Save frequent trips for quick access (requires account)
- **Schedule updates** — Download the latest timetable over-the-air without a full app update
- **Multi-language** — French, Arabic, English, Russian
- **Dark mode** — Follows system appearance or manually toggled

## Platforms

| Platform | Status |
|----------|--------|
| Android  | Supported |
| iOS      | Comming Soon |

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.1`
- Dart SDK `^3.11.1`
- Android Studio / Xcode for native builds

### Setup

```bash
# Install dependencies
flutter pub get

# Generate Riverpod providers and other code
dart run build_runner build --delete-conflicting-outputs

# Run in debug mode
flutter run
```

### Environment / Secrets

Before building for release, set the following:

| Key | Location | Description |
|-----|----------|-------------|

| Android signing config | `android/app/build.gradle.kts` | Release keystore for Play Store |

### Running Tests

```bash
flutter test
```

## Project Structure

```
lib/
  core/           # Shared utilities, theme, database, widgets
  features/       # Screen-level feature modules
    home/         # Home / search screen
    lines/        # Line detail and schedule browser
    account/      # User account, settings
    favorites/    # Saved trips
  services/       # DB update, auth services
  l10n/           # Localisation ARB files
assets/
  db/             # Bundled SNCFT SQLite database
  images/         # App icons and images
```

## Data

Train schedule data is sourced from SNCFT public timetables and compiled into a SQLite database bundled with the app. The database is versioned and can be updated OTA via the in-app update feature.

**Disclaimer:** This is an unofficial app. TunisGO is not affiliated with, endorsed by, or officially connected to SNCFT (Société Nationale des Chemins de Fer Tunisiens).

## Privacy & Data Collection

**TunisGO does not collect, store, or transmit any personal data.** All data is stored locally on your device. Here's what you should know:

### What We DON'T Collect:
- ❌ No analytics or tracking
- ❌ No advertising identifiers
- ❌ No personal information sent to external servers
- ❌ No usage data or crash reports

### What Is Stored Locally:
- ✅ Favorites (saved on your device; synced to account if you sign in)
- ✅ App preferences (theme, language settings)
- ✅ Authentication tokens (stored securely in device keychain/keystore)



### Third-Party Services:
- **InsForge**: database schedule updating;
- **Google AdMob**: Displays ads (free tier only;

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### Copyright

Copyright (c) 2025 mnik-creator

### What You Can Do:
- ✅ Use for **personal** purposes
- ✅ Use for **commercial** purposes
- ✅ **Modify** and distribute the software
- ✅ **Sell** the software or derivative works
- ✅ **Sublicense** the software

You only need to include the original copyright notice and license in all copies or substantial portions of the software.

See the full [LICENSE](LICENSE) file for complete terms.
