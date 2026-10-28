# Changelog

## [1.1.0] - 2026-10-28

### Added
- **Noise cancellation on calls:** turns noise cancellation on or off only during phone calls.
- **Concert hall settings:** room (Silent room, Living room, Jazz club, Concert hall) and virtual speaker angle (30° to 180°).
- **Equalizer:** turn it on or off and choose one of its 7 presets (Vocal, Pop, Club, Punchy, Deep, Crystal and the Custom curve saved from the official app). The menu shows the active preset.
- **Pause when removed:** turns the headset's presence sensor on or off.
- **Auto power off:** never, or after 5, 10, 15, 30 or 60 minutes.
- New options only appear when the connected headset answers them, so models without them do not show them.
- Diagnostics mode for the headset API: launch with `--args -ProbeAPI YES` and the answers are saved in `~/Library/Logs/Parrot Status/probe.log`.

### Fixed
- The name and battery level were sometimes missing after connecting, when two answers arrived in the same Bluetooth packet.

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
