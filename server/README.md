# Server (Proxmox) deployment

This runner keeps everything headless (no LED matrix) on your Proxmox box: it polls FlightRadar24, writes `close.txt` / `farthest.txt`, generates the maps, and serves the JSON + map pages via Flask.

## Quick start
```bash
git clone https://github.com/c0wsaysmoo/plane-tracker # or your fork
cd plane-tracker
python3 -m venv .venv
source .venv/bin/activate
pip install -r macos-widget/requirements-macos.txt  # server needs the same deps
python server/run_server.py --interval 180 --host 0.0.0.0 --port 8080
```

Endpoints (from clients):
- `http://<server>:8080/closest/json` and `/farthest/json` for data
- `http://<server>:8080/history/json` for the rolling history feed
- `http://<server>:8080/closest` and `/farthest` for interactive maps
- `http://<server>:8080/maps/<filename>` for static map files

## systemd unit example (on Proxmox Debian/Ubuntu)
Save as `/etc/systemd/system/plane-tracker.service`:
```ini
[Unit]
Description=Plane Tracker Server
After=network.target

[Service]
User=pi
WorkingDirectory=/home/pi/plane-tracker
Environment="PATH=/home/pi/plane-tracker/.venv/bin"
ExecStart=/home/pi/plane-tracker/.venv/bin/python server/run_server.py --interval 180 --host 0.0.0.0 --port 8080
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
Reload and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now plane-tracker.service
```

## Notes
- Configure `its-a-plane-python/config.py` with your location/units/email before starting.
- Maps are written under `its-a-plane-python/web/static/maps`; logs live in `its-a-plane-python/close.txt` and `its-a-plane-python/farthest.txt`.
- For SSL, front this with nginx/Traefik/Caddy and proxy to `localhost:8080`.
