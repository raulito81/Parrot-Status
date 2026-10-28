# Changelog

## [1.0.0] - 2026-10-28

### Changed
- Builds and runs on current macOS (13 Ventura or later, Apple silicon) with the current Xcode SDK.
- Open at login now uses `SMAppService` and can be turned off from the new "Open at login" menu item (it is turned on the first time the app runs).
- Battery notifications use the `UserNotifications` framework and are shown even while the app is active.
- The Option key now swaps "Battery notifications" for "Battery notifications…" with a native alternate menu item, instead of a global event tap that needed Input Monitoring access.
- Connection errors are logged instead of crashing the app.

### Added
- Bluetooth usage description and entitlement, which macOS requires to let the app talk to the headphones.

### Removed
- Sparkle updates: they pointed to the original project's feed and the bundled framework was Intel-only.
- "Move to Applications" prompt (the `lets-move-cocoa` submodule).
- "Touch control support for all Apps": it unloaded `com.apple.rcd`, which System Integrity Protection no longer allows, and the source it needed was not in the repository.
