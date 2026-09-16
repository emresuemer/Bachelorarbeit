#!/usr/bin/env python3
"""Decode the generated input jobs and check them against macro_data.dta.

The transmitted values are scaled integers, so this is the only place the
round-trip error is ever measured. It reads the jobs back exactly as Stata
will (free-format, whitespace-separated, wrapping across lines), rebuilds the
county-year panel, and compares it to the source.

Run from src/analyses/:  python3 remote/tools/verify_payload.py
"""

import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_supply_jobs import COLS, JOBS, SRC, YEAR_BASE  # noqa: E402

# Max acceptable error as a fraction of each variable's own sd. Set by the
# scale factors, which in turn are capped by the 72-character line limit:
# `input` needs one whole observation per line, so shorter numbers are the
# only way to keep lines short. 1e-3 of an sd is far below any quantity
# that affects a standardized coefficient.
TOL = 1e-3


def parts():
    """The part files in numeric order -- part10 must not sort before part2."""
    return sorted(JOBS.glob("10_supply_part*.do"),
                  key=lambda p: int(p.stem.rsplit("part", 1)[1]))


def decode():
    values = []
    width = len(COLS) + 2
    for path in parts():
        lines = path.read_text().splitlines()
        start = next(i for i, l in enumerate(lines) if l.startswith("input "))
        stop = lines.index("end")
        for offset, line in enumerate(lines[start + 1:stop], start=start + 2):
            row = line.split()
            # A data line must hold whole observations. A partial one is what
            # ends a truncated job: the server reports "'' cannot be read as a
            # number" and saves nothing.
            if not row or len(row) % width:
                sys.exit(f"{path.name} line {offset}: {len(row)} values, "
                         f"expected a multiple of {width}")
            values += row

    if len(values) % width:
        sys.exit(f"payload is not a multiple of {width} values - a job is truncated")

    frame = pd.DataFrame(
        [values[i:i + width] for i in range(0, len(values), width)],
        columns=["kkz", "yr"] + list(COLS),
    ).replace(".", np.nan).astype(float)

    frame["year"] = frame["yr"] + YEAR_BASE
    for name, scale in COLS.items():
        frame[name] = frame[name] / scale
    return frame.drop(columns="yr")


def main():
    original = pd.read_stata(SRC)
    decoded = decode()

    print(f"decoded {len(decoded)} rows, "
          f"{decoded.duplicated(['kkz', 'year']).sum()} duplicate keys")

    merged = original.merge(decoded, on=["kkz", "year"],
                            suffixes=("_o", "_r"), how="outer", indicator=True)
    counts = merged["_merge"].value_counts().to_dict()
    if counts.get("both", 0) != len(original) or len(merged) != len(original):
        sys.exit(f"row mismatch against source: {counts}")
    print(f"all {len(original)} county-years present, none extra")

    failed = False
    for name in COLS:
        a, b = merged[name + "_o"].astype(float), merged[name + "_r"].astype(float)
        if not (a.isna() == b.isna()).all():
            print(f"  FAIL {name}: missingness differs")
            failed = True
            continue
        both = a.notna() & b.notna()
        err = float((a[both] - b[both]).abs().max()) if both.any() else 0.0
        rel = err / original[name].std()
        flag = "FAIL" if rel > TOL else "ok  "
        failed |= rel > TOL
        print(f"  {flag} {name:<18} max err {err:.2e}  = {rel:.1e} sd")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
