# TunisGO — Public Transit Navigation for Tunisia

TunisGO is a mobile transit navigation app for Tunisia's transportation network (now SNCFT), built with Flutter. It provides offline-first access to train schedules, real-time journey planning, and notifications for the Tunisian railway network.

## Features

- **Offline schedules** — Full SNCFT timetable stored locally; no internet required to browse trains
- **Journey planner** — Point-to-point search across all 77 routes, 238 stops
- **Line browser** — Explore every line with departure times, days of operation, and fare information
- **Favorites** — Save frequent trips for quick access (requires account)
- **Schedule updates** — Download the latest timetable over-the-air without a full app update
- **Pro subscription** — Ad-free experience and premium features via RevenueCat
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
| RevenueCat iOS key | `lib/services/subscription_service.dart` (`_RC.apiKey`) | `appl_xxx` key from RC dashboard |
| RevenueCat Android key | `lib/services/subscription_service.dart` (`_RC.apiKey`) | `goog_xxx` key from RC dashboard |
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
    account/      # User account, settings, subscriptions
    favorites/    # Saved trips
  services/       # RevenueCat, DB update, auth services
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

### Account Features (Optional):
If you choose to create an account:
- Email and name are stored with InsForge (authentication provider)
- Favorites can be synced across devices
- Subscription status is managed via RevenueCat

### Third-Party Services:
- **InsForge**: Authentication (email/password, OAuth)
- **RevenueCat**: Subscription management
- **Google AdMob**: Displays ads (free tier only; removed with Pro subscription)

## License

### Business Source License 1.1 (BSL 1.1)

This project is licensed under the **Business Source License 1.1 (BSL 1.1)** with the following parameters:

| Parameter | Value |
|-----------|-------|
| **Licensor** | TunisGO |
| **Licensed Work** | TunisGO -  a transit navigation app for Tunisia's transportation network |
| **Additional Use Grant** | Personal use, educational use, and non-commercial research purposes |
| **Change Date** | 2031-01-01 |
| **Change License** | MIT License |

### What You Can Do:
- ✅ Use for **personal** purposes
- ✅ Use for **educational** purposes
- ✅ Use for **non-commercial research**
- ✅ Create derivative works for the above purposes

### What You Cannot Do (Without Permission):
- ❌ Use for **commercial purposes**
- ❌ **Sell** the software or derivative works
- ❌ Include in **commercial products** or services
- ❌ **Sublicense** or rent the software

### After the Change Date:
On **January 1, 2031**, this license will automatically convert to the **MIT License**, and you will be free to use the software under MIT terms.

For commercial licensing inquiries, please contact the copyright holder.

See the full [LICENSE](LICENSE) file for complete terms.
