# 0005 — Episode boundary rules and the revert-outcome split

Date: 2026-08-20
Status: accepted (pending video calibration — see Verification)

## Context

ADR 0003's outcome replay collapses a fully-removed substitution to a region
that absorbs the retyping burst and settles when activity moves elsewhere.
Pressure-testing that mechanism against natural typing (synthetic replays
through the real `classify_rows`, 2026-08-20, recorded in the
substitution-episode-reporting plan) confirmed three mislabels:

1. **Fight with autocorrect.** Delete `the`, retype `teh`, autocorrect
   re-fires: the second `replace` was absorbed into the first episode's
   region, so the first settled as `reverted_other` holding the *second*
   substitution's output — the truth is a revert to the original followed by
   a fresh substitution.
2. **Interrupted revert.** Delete the corrected word, fix a typo elsewhere,
   come back and retype the original: the elsewhere edit settled the
   still-empty region as `reverted_other` ("left nothing") even though the
   final text restored the original.
3. **Trailing burst.** Retype the original and keep typing contiguously:
   `start == hi` edits are absorbed, so the region swallowed trailing text
   and a genuine `reverted_to_original` came out `reverted_other`.

Separately, `reverted_other` conflated "replaced with different text" and
"deleted, left empty" — opposite findings for completion-mechanism research.

## Decision

Three boundary rules in `_classify_outcomes` (all in the settle/absorb
loops), then a schema split in `_settle`:

- **Settle-before-absorb.** A `replace`/`paste` whose range overlaps a
  collapsed region settles that region *before* the edit applies: a new
  substitution firing inside an episode ends it as it stands. The fight case
  settles at `teh == original` → `reverted_to_original`, and the re-fire is
  tracked as its own episode.
- **Empty regions are not settled by edits elsewhere.** An empty region means
  "deleted, not yet replaced"; settling it on an unrelated edit bakes in
  "left nothing" prematurely. It shifts with edits before it (existing
  position arithmetic) and stays alive until something lands in it, a foreign
  delimiter closes it, or the session ends.
- **Foreign-delimiter growth stop.** An insert appended at `hi` whose text
  contains a whitespace/punctuation character found in *neither*
  `replaced_text` nor `replacement_text` settles the region on the text as it
  stood (the append shifts only indices ≥ hi, so `text[lo:hi]` excludes it).
  Judged against the pair so spacing (`alot → a lot`) and smart-typography
  episodes keep their own delimiter. Same pair test as
  `episode_final_trusted`; the flag remains for the vectors growth-stop
  cannot see (overlap edits widening the region, delimiters typed inside it).
- **Outcome split.** `reverted_other` → `replaced_with_other` /
  `deleted_entirely`. `region == original` is checked before the empty test,
  so a paste over an empty `replaced_text` that is deleted again resolves
  `reverted_to_original`, not `deleted_entirely`. With the empty-region rule
  above, `deleted_entirely` can only be assigned at a foreign-delimiter close
  or session end — never by an unrelated mid-session edit.

## Consequences

- Outcome labels change on existing data (`reverted_other` disappears);
  combined `--out` CSVs from before this ADR do not concatenate with new
  ones. Regenerate rather than mix.
- A cursor landing *exactly* on a still-alive empty region and typing there
  is absorbed as if it were the revert. Accepted: positions must collide
  exactly, and the alternative (eager settling) mislabels every interrupted
  revert.
- `substitution_kind` is untouched — it never encoded outcome.

## Verification

Synthetic: `tests/test_substitution_metrics.py` — the fight, interrupted
revert, trailing burst, pair-delimiter, inside-delimiter, and
paste-over-empty shapes. Field: a scripted free-typing session (deliberate
autocorrect fights on video) checks each episode line against the recording;
until that session is run, treat the three boundary rules as
synthetically-calibrated only.
