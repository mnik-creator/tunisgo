# Changelog

All notable changes to TunisGO will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Migrated license from BSL 1.1 to MIT License (Copyright (c) 2025 mnik-creator)

### Added
- Firebase integration (Analytics, Crashlytics) via Google services Gradle plugin

---

## [2.0.0] - 2026-04-18

### Added
- Direct report submission to InsForge backend (requires sign-in) as an alternative to email-based reports
- `report_service.dart` — new service for authenticated POST submissions to InsForge `/api/database/insert/records/reports`
- SHA-256 checksum validation support for OTA database downloads (`checksum_type` field detection)
- Localization keys for report submission flow (`report_issue_auto_submit`, `report_issue_submit`, `report_issue_submitted`, `report_issue_error`, `report_issue_auth_required`) across EN, FR, AR, RU

### Fixed
- Keyboard now dismisses when the search button is tapped on the journey planner screen
- Database version check corrected from `2.2.0` to `2.0.0` to match `metadata.json`
- Login/auth error messages were hardcoded in French — now fully localized
- Train type badges (`INTERCITY`, etc.) now display in the selected language
- Day labels (e.g., "Tous les jours") now use localized strings instead of hardcoded French
- Schedule update status messages now localized in all four languages

### Changed
- `db_update_service.dart` — enhanced checksum support; falls back to MD5 when `checksum_type` is absent
- Migrated license from MIT to Business Source License 1.1 (BSL 1.1); changes to MIT on 2031-01-01
- Added BSL copyright headers to all 53 source files and 5 test files

---

## [1.0.0] - Initial release

### Added
- Offline SNCFT timetable (77 routes, 238 stops, 356 trips, 4,696 stop times) stored in a bundled SQLite database
- Journey planner with point-to-point search and time filter
- Line browser with departure times, days of operation, and fare information
- Favourites — save frequent trips (synced to account when signed in)
- OTA schedule updates — download the latest timetable without a full app update
- Pro subscription via RevenueCat — removes ads and unlocks premium features
- Google AdMob integration for free-tier ad display
- Multi-language support: French, Arabic, English, Russian
- Dark mode — follows system appearance or manually toggled
- InsForge authentication (email/password and OAuth)
- Local notifications for departure reminders via `flutter_local_notifications`
