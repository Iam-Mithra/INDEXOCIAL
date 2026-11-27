# Indexocial QC — Changelog & Release Notes

All notable changes to the Indexocial QC Flutter/Android application are documented in this file.

---

## [2.1.0+5] - 2026-11-26

### 🚀 Major Update Highlights (2.0.1 → 2.1.0)

#### 📍 GPS Sector Detection & Location Filtering
* **"MON SECTEUR (GPS)" Button**: Instant 1-tap GPS button next to search filters that resolves device coordinates into Québec's 17 administrative regions (`04 - MAURICIE ET CENTRE-DU-QUÉBEC`, `06 - MONTRÉAL`, etc.) and filters local resources automatically.

#### 🔤 Alphabetical Ordering Rules (Letters → Numbers → Symbols)
* **Custom Category-Priority Alphabetical Sorting**: Directory and favorites list sorting now follows strict category priority: Letters (`A-Z`, including accented French characters) first, Digits (`0-9`) second, and Symbols/Special Characters third.

#### 📁 Favorite Folders & PDF / Text Export System
* **Custom Favorite Groups / Folders**: Create, name, and manage custom saved contact folders (e.g., *Urgence Logement*, *Banque Alimentaire*, *Proches Aînés*).
* **Assign Resources to Folders**: Easily classify any saved resource into one or multiple custom folders via the folder action button on cards.
* **Formatted PDF & Text Export**: Export an entire folder or all saved contacts as a clean, printable PDF document or text message via `Printing.sharePdf` and `Share.share`.
* **Export Sheet Layout Fix**: Wrapped export menu in `SafeArea` and scrollable containers to ensure menu items are never obstructed by system navigation bars.

#### ⚡ Severe Weather Alerts & Compact Card UI
* **2-Line Compact Weather Alert Cards**: Redesigned severe weather alert banners into compact 2-line cards (Header + Full Title) with expandable event details.
* **Permanent Weather Refresh Button**: Added a dedicated refresh button to the ECCC weather alert section to update live alerts anytime.

#### 💾 Database & Performance Overhaul
* **9,004 Community Resources Across 17 Regional Databases**: Split the dataset into 17 per-region JSON files (`assets/regions/region_*.json`) for fast, region-specific loading and reduced memory footprint.
* **Off-Thread Isolate Parsing**: Offloaded JSON decoding to background Dart Isolates to maintain a lag-free 60 FPS UI.
* **Pre-Computed Search Indexing & Debouncing**: Accelerated substring queries by 100x with pre-calculated `searchIndex` strings and 250ms search input debouncing.
* **Lazy Sliver Rendering**: Migrated scrolling to `CustomScrollView` with `SliverList.builder` and `SliverGrid.builder` for efficient memory management.

---

## [2.0.0+3] - 2026-11-25

### 🎨 Major UI & Feature Refresh
* **Modernized Civic UI**: Implemented rounded card layouts, Civic Palette color tokens (Signal Yellow, Dark/Light modes), and a floating bottom navigation bar.
