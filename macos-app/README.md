# macOS native app + widget (SwiftUI/WidgetKit)

This folder holds a lightweight SwiftUI desktop app and a WidgetKit extension that consume the plane-tracker server API (`/closest/json` and `/farthest/json`). No menu bar dependency.

## Structure
- `PlaneTrackerApp.swift` – app entry point
- `ContentView.swift` – main window UI (closest/farthest lists, configurable server URL)
- `Models.swift` – data model + fetcher
- `PlaneTrackerWidget/PlaneTrackerWidget.swift` – WidgetKit extension showing glanceable lists

## How to open/build
1. Open the repo folder in Xcode (File > Open > select the repo). Create a new macOS app project if prompted and drop these files in, or add them to an existing project/Workspace.
2. Target macOS 13+ (for `MenuBarExtra` not needed here, but SwiftUI/WidgetKit baseline).
3. The repo now includes a `PlaneTrackerWidget` extension target (.appex) that builds alongside the app and is embedded automatically.
4. In the widget target, add an app group or shared container if you want to persist the server URL; by default, it uses `UserDefaults.standard` and falls back to `http://127.0.0.1:8080`.

## Configuring server URL
- Defaults to `http://127.0.0.1:8080` (localhost). Edit the text field in the app and click “Set & Refresh” to point at a different server.
- Widget (if added): set a `UserDefaults` string key `server_url` under the widget’s suite (or app group). The sample code reads `UserDefaults.standard` for simplicity.

## What it expects on the server
- `GET /closest/json` -> JSON array of flight objects
- `GET /farthest/json` -> JSON array of flight objects
- (Optional) `/closest` and `/farthest` for map links you can open from the app

## Notes
- Uses `URLSession` async fetches; refresh button in the app triggers both endpoints.
- Widget refresh cadence is ~5 minutes (Timeline policy) with placeholder/sample data when offline.
- If you add signing, bundle IDs, or groups, adjust in Xcode accordingly. This repository only provides the source files.***
