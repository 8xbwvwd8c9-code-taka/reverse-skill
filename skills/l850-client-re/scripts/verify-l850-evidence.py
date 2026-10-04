#!/usr/bin/env python3
"""Validate the minimum metadata contract for an L850 evidence record."""

from __future__ import annotations
import argparse
import pathlib
import re
import sys

REQUIRED = {
    "CLIENT_SHA256": r"^[A-F0-9]{64}$",
    "RUNTIME_IMAGE_SHA256": r"^[A-F0-9]{64}$",
    "GHIDRA_USED": r"^(YES|NO|BLOCKED_.+)$",
    "CAPSTONE_USED": r"^(YES|NO|BLOCKED_.+)$",
    "ARGUS_MCP_STATUS": r"^.+$",
    "WHOLE_IMAGE_ANALYSIS": r"^NO$",
    "MEMORY_WRITE": r"^NO$",
    "PACKET_SEND": r"^NO$",
    "GAME_ACTION": r"^NO$",
}

def parse_fields(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key in REQUIRED:
            out[key] = value.strip()
    return out

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("report", type=pathlib.Path)
    ns = ap.parse_args()

    text = ns.report.read_text(encoding="utf-8", errors="replace")
    fields = parse_fields(text)
    errors: list[str] = []

    for key, pattern in REQUIRED.items():
        value = fields.get(key)
        if value is None:
            errors.append(f"missing {key}")
        elif not re.match(pattern, value):
            errors.append(f"invalid {key}={value!r}")

    if errors:
        print("STATUS=FAIL")
        for e in errors:
            print(f"ERROR={e}")
        return 2

    print("STATUS=PASS")
    for key in REQUIRED:
        print(f"{key}={fields[key]}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
