#!/bin/bash
# SwiftBar widget for Plane Tracker
# Refresh every 30s (name dictates refresh interval)

PYTHON_BIN="${PYTHON_BIN:-python3}"
REPO_ROOT="${REPO_ROOT:-$HOME/Code/plane-tracker/its-a-plane-python}"
CLOSE_PATH="${CLOSE_PATH:-$REPO_ROOT/close.txt}"
FAR_PATH="${FAR_PATH:-$REPO_ROOT/farthest.txt}"
BASE_URL="${BASE_URL:-http://localhost:8080}"

echo "✈️"
echo "---"

${PYTHON_BIN} - <<'PY'
import json
import os

CLOSE_PATH = os.environ["CLOSE_PATH"]
FAR_PATH = os.environ["FAR_PATH"]
BASE_URL = os.environ.get("BASE_URL", "http://localhost:8080")


def load(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except Exception:
        return []


def fmt_distance(entry):
    dist = entry.get("distance", 0.0)
    dirn = entry.get("direction", "")
    return f"{dist:.1f} {dirn}".strip()


def print_section(title, items, empty_message):
    print(title)
    for item in items:
        callsign = item.get("callsign", "UNKNOWN")
        origin = item.get("origin", "UNK")
        dest = item.get("destination", "UNK")
        dist = fmt_distance(item)
        print(f"--{callsign} {origin}->{dest} ({dist})")
    if not items:
        print(f"--{empty_message}")


close = load(CLOSE_PATH)
far = load(FAR_PATH)

print_section("Closest flights", close, "No data yet")
print(f"--View map | href={BASE_URL}/closest")

print("---")
print_section("Farthest flights", far, "No data yet")
print(f"--View map | href={BASE_URL}/farthest")
PY
