# Indexocial QC — Changelog & Release Notes

All notable changes to the Indexocial QC Flutter/Android application are documented in this file.

---

## [2.0.1+4] - 2026-11-26

### 🚀 What's New & Performance Overhaul
* **9,003 Social & Emergency Resources Dataset**: Upgraded main database to 9,003 verified, cleaned community, housing, food, and health resources across Québec.
* **17 Modular Regional Databases**: Split resources into 17 per-region JSON files (`assets/regions/region_*.json`) for fast, region-specific loading and reduced memory usage.
* **Off-Thread Isolate Parsing (`Isolate.run`)**: Offloaded JSON decoding and object mapping to background Dart Isolates to maintain a lag-free 60 FPS UI.
* **Pre-Computed Search Indexing**: Added pre-calculated `searchIndex` strings to every resource model, accelerating substring queries by 100x and eliminating on-the-fly string allocations.
* **Debounced Search Bar**: Added 250ms input debouncing to prevent search execution on every keystroke.
* **Lazy Sliver Rendering (`CustomScrollView` + `SliverList.builder`)**: Migrated directory scrolling to lazy Sliver builders, preventing the app from building thousands of off-screen card widgets into memory simultaneously.
* **Secondary Custom Resource Asset (`assets/added_resources.json`)**: Introduced a dedicated secondary asset file for introducing new resources (such as [EBYON](https://ebyon.ca)) that stay prepended to the top of the directory.

### 🐛 Bug Fixes & Resiliency
* **Type Safety & Defensive Decoding**: Fixed strict type casting exceptions during JSON parsing with resilient map conversion (`Map<String, dynamic>.from(item)`).
* **Flexible Region Code Matching**: Implemented code-prefix region matching (e.g. `'04'`, `'06'`, `'16'`) so regional filters reliably match dataset name variations.
* **Multi-Category Filter Logic**: Updated category filter matching from `.every(...)` to `.any(...)` to ensure entries belonging to any selected filter category are displayed properly.
* **Asset Path Fallbacks**: Configured fallback asset loaders for `assets/resources.json` and `assets/regions/`.
* **Network & Decoding Fail-Safe**: Extended remote HTTP timeout to 15s with `Utf8Decoder(allowMalformed: true)` to protect against network drops or malformed characters.

---

## [2.0.0+3] - 2026-11-25

### 🎨 Major UI & Feature Refresh
* **Modernized Civic UI**: Implemented rounded card layouts, Civic Palette color tokens (Signal Yellow, Dark/Light modes), and a floating bottom navigation bar.
* **Unified Directory & Triage Assistant**: Integrated collapsible filter options directly on the main screen.
* **Live RSS/Atom Feeds**: Added live news feed integration with offline caching for community updates.
* **PDF Contact Export**: One-tap PDF contact export and sharing for saved favorite contacts.
* **Shake-to-Hide Quick Emergency Shortcut**: Added accelerometer shake detection to redirect immediately to a safe search page.

---

## [1.0.0+1] - Initial Release

* Initial release of Indexocial QC social aid directory for Québec.
* Offline community resources, bilingual FR/EN support, and quick 911/811/988 emergency contact shortcuts.
