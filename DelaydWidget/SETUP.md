# Delayd Widget

The `DelaydWidget` WidgetKit extension is wired into `Delayd.xcodeproj` and is embedded by the main `Delayd` app target.

## What It Shows

- Default dream goal name and emoji
- Saved amount toward that dream
- Goal progress
- Days delayed this month
- A one-tap Log entry point that opens Delayd Quick Log via `delayd://quicklog`

The widget reads a compact snapshot from shared App Group storage:

- App Group: `group.com.delayd.shared`
- UserDefaults key: `widget.entry`
- Writer: `Delayd/Features/Shortcuts/DelaydWidgetSync.swift`
- Reader: `DelaydWidget/DelaydWidget.swift`

## Apple Capability Requirement

The repository includes entitlements files for both targets:

- `Delayd/Delayd.entitlements`
- `DelaydWidget/DelaydWidget.entitlements`

Before App Store/TestFlight distribution, confirm in Apple Developer/Xcode Signing & Capabilities that `group.com.delayd.shared` exists and is enabled for both bundle IDs:

- `com.droidates.Delayd`
- `com.droidates.Delayd.DelaydWidget`

## Testing

1. Build and run `Delayd` on a simulator or device.
2. Open the app once so it writes the first widget snapshot.
3. Long-press the Home Screen.
4. Tap `+`.
5. Search for `Delayd`.
6. Add the small or medium widget.
7. Tap the widget or Log button to open Quick Log.
