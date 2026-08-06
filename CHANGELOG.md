# Changelog

All notable changes to Codex Current are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Made the floating dashboard follow the measured height of its visible components, including live growth and shrinkage when task details are expanded or collapsed, with screen-aware height limits.
- Added a one-click compact dashboard mode and pinned CI to Xcode 16.2 with separately reported self-test and package-build steps.

## [1.0.0] - 2026-08-06

### Added

- Native macOS menu-bar app and pinnable floating dashboard.
- Official Codex rate-limit windows, remaining percentages, and reset times.
- Official token-activity history plus a clearly separated local range estimate.
- Beta monitoring for tasks currently opened by Codex Desktop.
- Clash Verge/Mihomo connection, routing, node-health, and latency status.
- Compact and expanded layouts with configurable card visibility and ordering.
- English and Simplified Chinese localization.
- Local notifications for low quota, detected task events, and VPN disconnection.
- Permanent local monitoring history with an explicit clear action.
- Field-level privacy and data-quality contract.

### Changed

- Finalized the public product name as Codex Current and added automatic migration for pre-release Codex Bar history and dashboard preferences.

### Release boundary

- V1.0 is buildable from source and can produce an ad-hoc-signed local app bundle.
- A Developer ID-signed and Apple-notarized public binary is not included yet.
- Task activity remains Beta because it depends on Codex Desktop's local session format.

[Unreleased]: https://github.com/shuhaochen618-svg/Codex-Current/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/shuhaochen618-svg/Codex-Current/releases/tag/v1.0.0
