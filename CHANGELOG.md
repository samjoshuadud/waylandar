# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [1.4.0] - 2026-07-01

### Added
- Centralized network error helper (`core/errors.py`) to properly classify offline connection failures.
- Warning banner component at the top of the agenda list to alert users of offline/sync failures.
- Hover tooltips for the sidebar sync status button to display detailed per-account errors.
- Matugen-compatible error color token `Theme.error` across QML template and frontend theme fallbacks.

### Changed
- Refactored sync daemon to implement granular, per-account/feed recovery from previous caches on connection drops, preventing widgets from going blank.
- Updated CalDAV, Google, and ICS providers to propagate structured connection errors instead of masking them as auth failures.
- Aligned dashboard cache/sync error handling to keep displaying cached events.
- Updated dashboard and widget window dimensions to use relative, screen-responsive scaling with compact bounds.

### Fixed
- Fixed text collision and overlap in `WidgetHeader.qml` on narrow screens by enforcing text truncation (`elide`) and responsive width bounds.
- Fixed QML `TypeError` and `ReferenceError` warnings in `CalendarList.qml` by referencing properties directly and introducing a decoupled `isSyncing` flag.
- Fixed dashboard toggle race conditions where rapid clicks were overwritten by background file reads through an optimistic `localOverrides` state map.
- Fixed sidebar tooltip layering issues by adding `z` depth ordering to `headerLayout` in `CalendarSidebar.qml`.
- Fixed temporary sync error flickering and stale error messages during month navigation by suppressing error containers while syncing and clearing auth errors on month changes.

## [1.3.0] - 2026-06-24

### Added
- Added support for multiple concurrent accounts across all calendar providers (Google, CalDAV, Apple iCloud, ICS feeds, and Local Directories).
- Implemented a self-healing configuration schema migration that seamlessly updates older single-account configuration files (v1.2.0 and earlier) on startup.
- Upgraded the sync daemon to process account network sync tasks in parallel using a thread pool, significantly reducing total latency.
- Implemented zero-latency local caching of events, enabling the QML widget and dashboard to load instantly from cache on startup while updating in the background.
- Redesigned the terminal-based setup wizard (`sync.py`) to feature an interactive main dashboard with submenus for managing each provider type, allowing users to add, remove, and toggle specific accounts or feeds.
- Grouped calendar listings in the dashboard sidebar by account/provider with collapsible arrow sections.
- Added a non-blocking undo toast with a 4-second delay when toggling provider or account visibility from the interface, preserving toggle state changes safely and avoiding database synchronization race conditions.
- Integrated a compact sync status indicator ("Synced", "Syncing...", or "Error") in the dashboard sidebar header, allowing manual sync trigger on click with Matugen theme-aware hover animations.

### Changed
- Refactored backend provider modules to utilize unique UUID mappings for granular account and calendar management.

### Fixed
- Prevented system exit failures from background threads when authenticating with Google Calendar, raising an internal RuntimeError instead of calling sys.exit to keep other calendars syncing.
- Resolved timezone rendering offsets where all-day events parsed as UTC midnight shifted by one day depending on local timezone settings.
- Added Latin-1 character decoding fallback for non-standard or legacy ICS feed formats.
- Enforced a default connection timeout of 10 seconds for CalDAV networking requests to prevent background sync daemon hangs.
- Added robust cleanup filtering in the QML interface to immediately purge deleted account configurations from the active view state.
- Enabled immediate clock-reactive QML layout and date updates on day boundaries.

## [1.2.0] - 2026-06-22

### Added
- Added native support for Apple iCloud Calendar via CalDAV. iCloud can now be selected directly from the interactive setup wizard.
- Added support for subscribing to arbitrary read-only ICS feeds (e.g., Proton Calendar, Outlook, public holidays).
- Added support for multiple concurrent ICS feed subscriptions, unifying events from multiple sources.
- Added native support for Local Directories. Users can now point Waylandar to a local folder containing `.ics` files, and it will safely parse and sync those events to the widget. Perfect for `vdirsyncer`, Nextcloud Client, or custom script integrations.
- Introduced ANSI color formatting and structural improvements to the terminal setup wizard (`sync.py`), significantly enhancing readability and organization.

### Changed
- Dismantled the monolithic `sync.py` entrypoint into a highly decoupled `core/` package architecture (daemon, cli, config), eliminating the God File anti-pattern.
- Completely removed `vdirsyncer` terminology from the user interface and documentation to clarify that the backend acts as a pure, decoupled filesystem parser and does not execute network sync tools itself.

### Fixed
- Added an automatic fallback to the frontend state loader. When users switch calendar providers entirely (which changes all internal calendar IDs), the widget now automatically checks all new calendars by default instead of showing an empty UI.
- Fixed a major UX bug causing notification spam for ICS feeds and Local Directories by removing the hardcoded 10-minute fallback alarm on read-only events.
- Fixed a QML rendering bug where Apple iCloud passed 8-character RGBA colors (e.g. `#FF2D55FF`) which broke widget color coding. Alpha channels are now safely stripped to standard 6-character hex.
- Fixed the UI text formatting for 0-minute alarms, properly rendering them as "At time of event" instead of "0 minutes before".
- Hardened backwards compatibility for `v1.0.0` users so their legacy `credentials.json` silently and seamlessly maps to the new `config.json` architecture without them needing to re-authenticate.
- Hardened the Local Directory parser against Denial of Service (DoS) by enforcing a 50MB file size limit and validating that targets are regular files (preventing infinite reads from named pipes like `/dev/zero`).
- Hardened `os.walk` to prevent infinite recursion and daemon crashes if a user creates a circular symlink inside their calendar folder.
- Added a `Latin-1` decoding fallback to safely parse legacy `.ics` files exported from older enterprise software (like legacy MS Outlook) that don't adhere to modern `UTF-8` standards.
- Sped up directory parsing and prevented the loading of "ghost" deleted events by automatically bypassing hidden metadata cache folders (e.g., `.vdirsyncer`, `.sync`, `.git`).
- Added validation in the CLI wizard to prevent users from adding the exact same local directory twice, which previously resulted in duplicate events flooding the UI.
- Fixed an issue where the sub-calendar name and assigned colors were omitted when fetching CalDAV calendars, causing all events to appear as "Unknown" and grey in the UI.
- Fixed a bug where clicking "Open in Browser" on an iCloud event attempted to open an invalid URL path. It now accurately points to the iCloud web calendar.
- Replaced the Apple logo character in the provider sidebar badge with a universally safe `i` character to prevent missing font glyphs on standard Linux distributions.
- Fixed a linting issue in `sync.py` due to an unused `datetime` import and an empty f-string block.

## [1.1.2] - 2026-06-21

### Changed
- Completely refactored the QML frontend architecture. Extracted massive monolithic codeblocks in `widget.qml` and `dashboard.qml` into modular, reusable components (`WidgetHeader`, `CalendarGridPane`, `AgendaListPane`, `LoadingSpinner`) for significantly cleaner and more maintainable code.

### Fixed
- Fixed an annoying visual bug in the desktop widget where expanding an event card would cause the entire widget window to dynamically resize and jump. The widget now uses a stable, fixed vertical height.

## [1.1.1] - 2026-06-21

### Fixed
- Fixed a bug where selecting "Re-auth Google" from the terminal wizard would skip the browser login if an old token already existed. The wizard now forcefully clears the old session to allow switching Google accounts.
- Fixed an issue where cancelling the Google re-auth flow with `Ctrl+C` would fail to restore the backup token, causing users to be logged out. The backup is now reliably restored even if the terminal is forcefully interrupted.

## [1.1.0] - 2026-06-21

### Added
- CalDAV support for Nextcloud and other CalDAV-compatible servers. The setup wizard now supports configuring and switching between Google Calendar and CalDAV providers.
- Configurable background sync interval (previously fixed at 60 minutes). Minimum interval is 5 minutes.

### Changed
- **Breaking:** `waylandar-auth` has been renamed to `waylandar`, reflecting its expanded role in provider setup and configuration rather than just authentication. Update any scripts or aliases that reference the old command name.

### Fixed
- Resolved a `ModuleNotFoundError` for the `cryptography` and `google` modules on Arch Linux and NixOS, caused by the widget picking up local `pyenv`/`conda` environments instead of system packages. The widget now resolves dependencies from the system Python environment exclusively.

## [1.0.0] - Initial Release

### Added
- Google Calendar integration via OAuth 2.0.
- Two UI modes: compact desktop widget (`waylandar-widget`) and full-month overlay (`waylandar-dashboard`).
- Background sync with desktop notifications via `notify-send` for upcoming events.
- Matugen theming support, generating colors dynamically from the active wallpaper.
- Native packaging for NixOS and Arch Linux.
