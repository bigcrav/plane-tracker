#!/bin/bash
# SwiftBar widget that pulls data from the remote plane-tracker server.
# Refresh interval: 30s (from filename).

BASE_URL="${BASE_URL:-http://localhost:8080}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "✈️"
echo "---"

${PYTHON_BIN} - <<'PY'
import json
import os
import sys
import urllib.request

BASE_URL = os.environ.get("BASE_URL", "http://localhost:8080").rstrip("/")

def fetch_json(path):
    url = f"{BASE_URL}{path}"
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"--Error: {e}")
        return []


def fmt_distance(entry):
    dist = entry.get("distance", 0.0)
    dirn = entry.get("direction", "")
    return f"{dist:.1f} {dirn}".strip()


def print_section(title, items, map_path):
    print(title)
    for item in items:
        callsign = item.get("callsign", "UNKNOWN")
        origin = item.get("origin", "UNK")
        dest = item.get("destination", "UNK")
        dist = fmt_distance(item)
        print(f"--{callsign} {origin}->{dest} ({dist})")
    if not items:
        print("--No data yet")
    print(f"--View map | href={BASE_URL}{map_path}")


close = fetch_json("/closest/json")
far = fetch_json("/farthest/json")

print_section("Closest flights", close, "/closest")
print("---")
print_section("Farthest flights", far, "/farthest")
PY
