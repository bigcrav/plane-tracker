# macOS widget (menu bar) setup

This folder turns the Pi flight tracker into a macOS-friendly setup: a headless fetcher that writes the same `close.txt` and `farthest.txt` logs plus maps, and SwiftBar/HTML clients to display them (locally or from a remote server).

## 1) Prep the Python bits
1. Configure `its-a-plane-python/config.py` with your coords, units, and email (if wanted).
2. Install deps (inside the repo):
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r macos-widget/requirements-macos.txt
   ```
3. Run the headless fetcher (writes `close.txt`, `farthest.txt`, and maps under `its-a-plane-python/web/static/maps`):
   ```bash
   python macos-widget/headless_tracker.py --interval 120
   # add --once to do a single fetch
   ```
4. (Optional) start the Flask server for map/JSON viewing:
   ```bash
   python its-a-plane-python/web/app.py  # serves http://localhost:8080
   ```

### LaunchAgent example (runs the fetcher on boot)
Save to `~/Library/LaunchAgents/com.plane.tracker.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.plane.tracker</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-lc</string>
        <string>cd /Users/$(whoami)/Code/plane-tracker && source .venv/bin/activate && python macos-widget/headless_tracker.py --interval 300</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>/tmp/plane-tracker.log</string>
    <key>StandardErrorPath</key><string>/tmp/plane-tracker.err</string>
</dict>
</plist>
```
Load it with `launchctl load ~/Library/LaunchAgents/com.plane.tracker.plist`.

## 2a) Install the SwiftBar widget (local files)
1. Install [SwiftBar](https://swiftbar.app/).
2. Make the widget executable and symlink it into SwiftBar’s plugin folder:
   ```bash
   chmod +x macos-widget/swiftbar/plane-tracker.30s.sh
   ln -s "$PWD/macos-widget/swiftbar/plane-tracker.30s.sh" "$HOME/Library/Application Support/SwiftBar/"
   ```
3. Ensure the paths match your checkout; override via env vars in SwiftBar if needed:
   - `REPO_ROOT` (default `~/Code/plane-tracker/its-a-plane-python`)
   - `CLOSE_PATH` / `FAR_PATH`
   - `BASE_URL` (default `http://localhost:8080` for the maps)
4. Start SwiftBar; you should see `✈️` with closest/farthest lists and map links.

## 2b) SwiftBar widget (remote server)
If the data lives on your Proxmox server (running `server/run_server.py`), use the remote-aware widget:
```bash
chmod +x macos-widget/swiftbar/plane-tracker-remote.30s.sh
ln -s "$PWD/macos-widget/swiftbar/plane-tracker-remote.30s.sh" "$HOME/Library/Application Support/SwiftBar/"
```
Set `BASE_URL` in SwiftBar (e.g., `http://yourserver:8080`). No local files needed; it consumes the server’s `/closest/json` and `/farthest/json`.

## 3) Simple desktop app (HTML)
Open `macos-widget/desktop_app.html` in your browser. Add `?server=http://yourserver:8080` to point it at the remote server. It lists closest/farthest flights and links to the maps.

## How it hangs together
- `macos-widget/headless_tracker.py` reuses `utilities.overhead.Overhead` to poll FlightRadar24 and write logs/maps—no LED matrix required.
- `macos-widget/swiftbar/plane-tracker.30s.sh` reads local logs; `plane-tracker-remote.30s.sh` hits the server API.
- `macos-widget/desktop_app.html` is a lightweight client that fetches from the server and opens the map pages.
