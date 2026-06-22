# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Added native support for Apple iCloud Calendar via CalDAV. iCloud can now be selected directly from the interactive setup wizard.
- Added support for subscribing to arbitrary read-only ICS feeds (e.g., Proton Calendar, Outlook, public holidays).
- Added support for multiple concurrent ICS feed subscriptions, unifying events from multiple sources.
- Added native support for Local Directories. Users can now point Waylandar to a local folder containing `.ics` files, and it will safely parse and sync those events to the widget. Perfect for `vdirsyncer`, Nextcloud Client, or custom script integrations.
- Introduced ANSI color formatting and structural improvements to the terminal setup wizard (`sync.py`), significantly enhancing readability and organization.

### Changed
- Completely removed `vdirsyncer` terminology from the user interface and documentation to clarify that the backend acts as a pure, decoupled filesystem parser and does not execute network sync tools itself.

### Fixed
- Added an automatic fallback to the frontend state loader. When users switch calendar providers entirely (which changes all internal calendar IDs), the widget now automatically checks all new calendars by default instead of showing an empty UI.
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
