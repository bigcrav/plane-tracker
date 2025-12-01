#!/usr/bin/env python3
"""
Headless server runner: polls FlightRadar24, writes closest/farthest logs + maps,
and serves the JSON/map pages via Flask. Intended for Proxmox/VM deployment.
"""
import argparse
import os
import sys
import threading
import time


def add_project_to_path():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "its-a-plane-python"))
    if base_dir not in sys.path:
        sys.path.insert(0, base_dir)
    return base_dir


def wait_for_completion(overhead, timeout=45, poll=0.5):
    waited = 0.0
    while overhead.processing and waited < timeout:
        time.sleep(poll)
        waited += poll


def start_fetch_loop(interval: int):
    from utilities.overhead import Overhead  # pylint: disable=import-error

    tracker = Overhead()

    def fetch_once():
        tracker.grab_data()
        wait_for_completion(tracker)

    def loop():
        while True:
            fetch_once()
            time.sleep(interval)

    # Kick off immediately and then schedule
    fetch_once()
    t = threading.Thread(target=loop, daemon=True)
    t.start()


def main():
    parser = argparse.ArgumentParser(description="Plane tracker server (headless)")
    parser.add_argument("--interval", type=int, default=180, help="Seconds between polls (default: 180)")
    parser.add_argument("--host", default="0.0.0.0", help="Bind host for Flask app")
    parser.add_argument("--port", type=int, default=8080, help="Port for Flask app")
    args = parser.parse_args()

    base_dir = add_project_to_path()
    os.chdir(base_dir)

    start_fetch_loop(args.interval)

    from web.app import app  # pylint: disable=import-error
    app.run(host=args.host, port=args.port, debug=False)


if __name__ == "__main__":
    main()
