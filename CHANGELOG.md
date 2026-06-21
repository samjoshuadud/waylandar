# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.1.1] - 2026-06-21

### Fixed
- Fixed a bug where selecting "Re-auth Google" from the terminal wizard would skip the browser login if an old token already existed. The wizard now forcefully clears the old session to allow switching Google accounts.

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
