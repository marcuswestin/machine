#!/usr/bin/python3
"""Report persisted CustomUserPreferences drift without displaying private values."""

import os
from pathlib import Path
import json
import plistlib
import subprocess
import sys

repo = Path(__file__).resolve().parent.parent
host = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("MACHINE_HOST", "machine")
declared = json.loads(
    subprocess.check_output(
        [
            "nix",
            "--extra-experimental-features",
            "nix-command flakes",
            "eval",
            "--offline",
            "--no-write-lock-file",
            "--json",
            f"{repo}#darwinConfigurations.{host}.config.system.defaults.CustomUserPreferences",
        ]
    )
)
counts = {"MATCH": 0, "DIFF": 0, "UNKNOWN": 0}
for domain, expected in sorted(declared.items()):
    # defaults export emits XML; XML parsers normalize CR/CRLF to LF. Put the
    # target through the same serialization so Return shortcuts are not false drift.
    expected = plistlib.loads(plistlib.dumps(expected, fmt=plistlib.FMT_XML))
    result = subprocess.run(["defaults", "export", domain, "-"], capture_output=True)
    if result.returncode:
        counts["UNKNOWN"] += 1
        print(f"[UNKNOWN] {domain}: preferences absent or unreadable; no match assumed")
        continue
    try:
        actual = plistlib.loads(result.stdout)
    except (ValueError, plistlib.InvalidFileException) as error:
        counts["UNKNOWN"] += 1
        print(f"[UNKNOWN] {domain}: invalid plist ({type(error).__name__})")
        continue
    differences = [
        key
        for key, value in expected.items()
        if key not in actual or actual[key] != value
    ]
    status = "DIFF" if differences else "MATCH"
    counts[status] += 1
    print(
        f"[{status}] {domain}: {len(expected)} declared keys, {len(differences)} differing/unset"
    )
    for key in differences:
        print(
            f"  {key}: {'unset (app default may apply)' if key not in actual else 'differs'}"
        )
print("Summary: " + ", ".join(f"{count} {status}" for status, count in counts.items()))
print(
    "Report only: saved custom user defaults; excludes first-class macOS defaults, current-host settings,"
)
print(
    "app runtime state, credentials, native imports, and permissions. No private values displayed."
)
