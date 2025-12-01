#!/usr/bin/env python3
"""
Headless flight logger for macOS.

Runs the existing FlightRadar24 polling logic without the LED matrix and
writes the closest/farthest logs plus maps that the SwiftBar widget reads.
"""
import argparse
import os
import sys
import time


def add_project_to_path():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "its-a-plane-python"))
    if base_dir not in sys.path:
        sys.path.insert(0, base_dir)
    return base_dir


def wait_for_completion(overhead, timeout=30, poll=0.5):
    waited = 0.0
    while overhead.processing and waited < timeout:
        time.sleep(poll)
        waited += poll


def main():
    parser = argparse.ArgumentParser(description="Headless flight tracker for macOS")
    parser.add_argument("--interval", type=int, default=120, help="Seconds between fetches (default: 120)")
    parser.add_argument("--once", action="store_true", help="Fetch only once and exit")
    args = parser.parse_args()

    base_dir = add_project_to_path()
    os.chdir(base_dir)

    from utilities.overhead import Overhead  # pylint: disable=import-error

    tracker = Overhead()

    def fetch():
        tracker.grab_data()
        wait_for_completion(tracker)

    fetch()
    if args.once:
        return

    while True:
        time.sleep(args.interval)
        fetch()


if __name__ == "__main__":
    main()
