#!/usr/bin/env python3
"""
clean_keystrokes.py
-------------------
Flags outliers in raw keystroke CSVs exported from the TypingResearch iOS app.

Does NOT delete rows — adds four columns so downstream analyses can filter
with different thresholds without re-running the pipeline:

    tap_norm_x      float   tapLocalX / keyWidth  (0 = left edge, 1 = right edge)
    tap_norm_y      float   tapLocalY / keyHeight  (0 = top edge, 1 = bottom edge)
    is_outlier      int     1 if any flag fired, else 0
    outlier_flags   str     pipe-separated reasons (empty string = clean)

Outlier criteria (literature-grounded):
    spatial     tap_norm_x or tap_norm_y outside [-0.5, 1.5]
                  → tap is >½ key-width outside the key boundary.
                  Threshold from Azenkot & Zhai (2012): exclude taps further
                  from key center than the width of an adjacent key.
    iki_low     inter_key_interval_ms < 50
                  → physiologically impossible; double-registration or jitter.
    iki_high    inter_key_interval_ms > 3000
                  → pause/distraction, not typing rhythm.
    trial_start text_before == ""
                  → first keystroke of a trial; its IKI is stimulus reaction
                  time, not a between-key interval.  Always exclude from IKI
                  distributions; optionally exclude from tap distributions.
    delete_event event_type == "delete"
                  → user aimed at backspace intentionally; exclude from
                  tap-distribution / boundary-reconstruction analyses.

Usage:
    python clean_keystrokes.py <input.csv> [output.csv]

    If output path is omitted, writes <stem>_cleaned.csv next to the input.

Thresholds can be overridden at the top of this file.
"""

import sys
import csv
import os
from pathlib import Path

# ── Configurable thresholds ────────────────────────────────────────────────
SPATIAL_MIN = -0.5   # norm_x / norm_y lower bound (inclusive)
SPATIAL_MAX =  1.5   # norm_x / norm_y upper bound (inclusive)
IKI_MIN_MS  =  50.0  # IKI below this → iki_low
IKI_MAX_MS  = 3000.0 # IKI above this → iki_high
# ──────────────────────────────────────────────────────────────────────────


def safe_float(val, default=0.0):
    try:
        return float(val)
    except (ValueError, TypeError):
        return default


def compute_flags(row: dict) -> list[str]:
    flags = []

    # ── tap_norm_x / tap_norm_y ──────────────────────────────────────────
    tap_x   = safe_float(row.get("tap_local_x"))
    tap_y   = safe_float(row.get("tap_local_y"))
    k_w     = safe_float(row.get("key_width"))
    k_h     = safe_float(row.get("key_height"))

    norm_x = (tap_x / k_w) if k_w > 0 else 0.5
    norm_y = (tap_y / k_h) if k_h > 0 else 0.5

    row["tap_norm_x"] = f"{norm_x:.4f}"
    row["tap_norm_y"] = f"{norm_y:.4f}"

    if not (SPATIAL_MIN <= norm_x <= SPATIAL_MAX) or \
       not (SPATIAL_MIN <= norm_y <= SPATIAL_MAX):
        flags.append("spatial")

    # ── IKI ──────────────────────────────────────────────────────────────
    iki = safe_float(row.get("inter_key_interval_ms"))
    if iki < IKI_MIN_MS and iki > 0:   # iki == 0 is handled by trial_start
        flags.append("iki_low")
    if iki > IKI_MAX_MS:
        flags.append("iki_high")

    # ── Trial start ───────────────────────────────────────────────────────
    if row.get("text_before", "").strip() == "":
        flags.append("trial_start")

    # ── Delete events ─────────────────────────────────────────────────────
    if row.get("event_type", "").strip().lower() == "delete":
        flags.append("delete_event")

    return flags


def clean_file(input_path: str, output_path: str | None = None) -> str:
    in_path  = Path(input_path)
    out_path = Path(output_path) if output_path else \
               in_path.with_name(in_path.stem + "_cleaned.csv")

    with open(in_path, newline="", encoding="utf-8") as fh:
        reader   = csv.DictReader(fh)
        orig_fields = reader.fieldnames or []
        rows     = list(reader)

    new_fields = list(orig_fields) + ["tap_norm_x", "tap_norm_y",
                                       "is_outlier", "outlier_flags"]

    total    = len(rows)
    flagged  = 0
    flag_counts: dict[str, int] = {}

    for row in rows:
        flags = compute_flags(row)          # also sets tap_norm_x/y in row
        row["is_outlier"]    = "1" if flags else "0"
        row["outlier_flags"] = "|".join(flags)
        if flags:
            flagged += 1
            for f in flags:
                flag_counts[f] = flag_counts.get(f, 0) + 1

    with open(out_path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=new_fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    # ── Summary ──────────────────────────────────────────────────────────
    print(f"\nInput : {in_path}")
    print(f"Output: {out_path}")
    print(f"Rows  : {total} total  |  {flagged} flagged ({100*flagged/total:.1f}%)")
    print(f"        {total - flagged} clean")
    if flag_counts:
        print("\nFlag breakdown:")
        for flag, count in sorted(flag_counts.items(), key=lambda x: -x[1]):
            print(f"  {flag:<14} {count:>5}  ({100*count/total:.1f}%)")

    clean_non_delete = sum(
        1 for r in rows
        if r["is_outlier"] == "0" and r.get("event_type") != "delete"
    )
    print(f"\nUsable for tap distribution (is_outlier=0, not delete): {clean_non_delete}")
    print(f"Usable for IKI stats (is_outlier=0, not trial_start):    "
          f"{sum(1 for r in rows if r['is_outlier']=='0' and 'trial_start' not in r['outlier_flags'])}")

    return str(out_path)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    input_csv  = sys.argv[1]
    output_csv = sys.argv[2] if len(sys.argv) > 2 else None
    clean_file(input_csv, output_csv)


if __name__ == "__main__":
    main()
