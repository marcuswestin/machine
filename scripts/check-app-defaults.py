#!/usr/bin/python3
"""Report only differing declared CustomUserPreferences keys and values."""

import os
from pathlib import Path
import json
import plistlib
import subprocess
import sys
import re

repo = Path(__file__).resolve().parent.parent
host = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("MACHINE_HOST", "machine")
declared = json.loads(
    subprocess.check_output(
        [
            "nix",
            "--extra-experimental-features",
            "nix-command flakes",
            "--option",
            "warn-dirty",
            "false",
            "eval",
            "--offline",
            "--no-write-lock-file",
            "--json",
            f"{repo}#darwinConfigurations.{host}.config.system.defaults.CustomUserPreferences",
        ]
    )
)


def shown(key, value):
    if re.search(r"password|secret|token|credential|auth|session|private", key, re.I):
        return "<redacted>"
    if isinstance(value, bytes):
        return "0x" + value.hex()
    return json.dumps(value, ensure_ascii=False, sort_keys=True, default=str)


for domain, expected in sorted(declared.items()):
    # defaults export emits XML; XML parsers normalize CR/CRLF to LF. Put the
    # target through the same serialization so Return shortcuts are not false drift.
    expected = plistlib.loads(plistlib.dumps(expected, fmt=plistlib.FMT_XML))
    result = subprocess.run(["defaults", "export", domain, "-"], capture_output=True)
    if result.returncode:
        print(f"[UNVERIFIED] {domain}: preferences absent or unreadable")
        continue
    try:
        actual = plistlib.loads(result.stdout)
    except (ValueError, plistlib.InvalidFileException) as error:
        print(f"[UNVERIFIED] {domain}: invalid plist ({type(error).__name__})")
        continue
    differences = [
        key
        for key, value in expected.items()
        if key not in actual or actual[key] != value
    ]
    for key in differences:
        current = shown(key, actual[key]) if key in actual else "<unset>"
        print(
            f"[DIFF] {domain}.{key}: current={current} -> repo={shown(key, expected[key])}"
        )
