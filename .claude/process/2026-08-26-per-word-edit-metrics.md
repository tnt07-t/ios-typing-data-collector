# 2026-08-26 — per-word edit metrics (prof feedback)

Plan: `~/.claude/plans/fetch-main-pull-if-binary-octopus.md`. Branch
`tran/free-type-analysis`.

## What happened
- Merged `origin/main` (`7ab3afc3`): brought in `prefix_error_metrics.py`
  (PR #34, active CER/WER) — already covers the "normalize to percentages"
  half of the feedback. One both-added conflict in `scripts/CLAUDE.md`,
  kept both sections.
- New `scripts/word_edit_metrics.py` (`0e4c3ebb`): per-word edited/clean
  binary + mechanism breakdown. Reuses `prefix_error_metrics` UTF-16
  replay helpers + `WORD_RE`, and `substitution_metrics.classify_rows`
  for sources.
- Docs commit `66136214`: CSV purpose statement + pipeline section.

## Errors hit / fixed
- First attribution design (nearest-surviving-cell context walk) falsely
  marked a neighboring word as edited when a whole word was deleted.
  Replaced with position markers.
- First `_shift_marker` treated insert-at-marker as always shifting, so
  ordinary forward typing dragged every delete's marker to end-of-text —
  9/18 Jimmy events came out unattributed. Fix: left-biased marker
  (insert at marker stays put; deletion ending at marker pulls left).
  After the fix all 18 events attribute and match the video ground truth
  (`day → say` episode → "say", `breads` cleanup → "bread").
- `python3 -m pytest tests/` still shows 2 pre-existing collection errors
  (`test_hand_pipeline`, `test_pooled_fusion` need numpy; venv has no
  pytest). Ignore them or run suites individually.

## Outcome
- 92 tests pass (83 in the non-numpy suites + 9 new).
- `Jimmy_test_Tran`: 33 words, 7 edited (21.2%) — autocorrect 5 (15.2%),
  backspace_retype 3 (9.1%), select_overtype 1 (3.0%).
- Deferred: workstream C (tap x/y export) needs an on-device spike; the
  system keyboard's touches are not observable in-app
  (`LastTouchTracker.swift:11-14`); fallback is the broadcast-video route.
