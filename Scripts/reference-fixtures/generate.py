#!/usr/bin/env python3
"""Generate reference fixtures for the BusinessMath test suite.

Run once; commit the output. CI never executes this — the Swift test target reads
the committed JSON. A Swift suite that needs a working SciPy to run is a suite that
goes red for reasons unrelated to the library.

    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
    .venv/bin/python generate.py

Output lands in Tests/BusinessMathTests/Fixtures/, alongside a MANIFEST.json that
records the SciPy and NumPy versions and a sha256 per fixture. When a fixture and
the manifest disagree, the manifest is the one that tells you why.
"""

import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy
import scipy

import spec

OUTPUT_DIR = (Path(__file__).resolve().parents[2]
              / "Tests" / "BusinessMathTests" / "Fixtures")


def _write(path: Path, payload: dict) -> str:
    """Write `payload` as stable JSON and return its sha256.

    sort_keys and a fixed separator keep the bytes reproducible, so a regeneration
    that changes nothing produces no diff — which is what makes a diff meaningful.
    """
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    path.write_text(text)
    return hashlib.sha256(text.encode()).hexdigest()


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    generated_at = datetime.now(timezone.utc).isoformat()
    entries = {}

    for entry in spec.SPECIAL_FUNCTIONS:
        cases = entry["cases"]()
        payload = {
            "name": entry["name"],
            "reference": entry["reference"],
            "note": entry["note"],
            "cases": cases,
        }
        filename = f"{entry['name']}.json"
        digest = _write(OUTPUT_DIR / filename, payload)
        entries[filename] = {"sha256": digest, "cases": len(cases),
                             "reference": entry["reference"]}
        print(f"  {filename}: {len(cases)} cases")

    for entry in spec.POINT_SETS:
        cases = entry["cases"]()
        payload = {"name": entry["name"], "reference": entry["reference"],
                   "note": entry["note"], "cases": cases}
        filename = f"{entry['name']}.json"
        digest = _write(OUTPUT_DIR / filename, payload)
        entries[filename] = {"sha256": digest, "cases": len(cases),
                             "reference": entry["reference"]}
        print(f"  {filename}: {len(cases)} cases")

    for entry in spec.DISTRIBUTIONS:
        cases = entry["cases"]()
        payload = {"name": entry["name"], "reference": entry["reference"],
                   "note": entry["note"], "cases": cases}
        filename = f"{entry['name']}.json"
        digest = _write(OUTPUT_DIR / filename, payload)
        entries[filename] = {"sha256": digest, "cases": len(cases),
                             "reference": entry["reference"]}
        print(f"  {filename}: {len(cases)} cases")

    manifest = {
        "generated": generated_at,
        "python": platform.python_version(),
        "scipy": scipy.__version__,
        "numpy": numpy.__version__,
        "fixtures": entries,
    }
    _write(OUTPUT_DIR / "MANIFEST.json", manifest)
    print(f"\nscipy {scipy.__version__} · numpy {numpy.__version__} · "
          f"python {platform.python_version()}")
    print(f"{len(entries)} fixtures → {OUTPUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
