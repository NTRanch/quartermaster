# Playtest — Quartermaster v1.0.0

Structured agent playtest, executed 2026-10-30 against the shipped
build. Honest label: this is an **agent playtest** — the demo policy
and the spec suite played the game; the Owner's hands and eye are the
morning gate, not this file. No audio was played aloud at any point
(audio silence rule): cues are verified by construction (frame cue
lists) and by the settings/volume path in specs, never by ear.

## Method

1. **Demo-policy runs** through the public API (`src.demo`), all
   three drills, seed 42 — the same policy that drives demo mode and
   the preview captures.
2. **Spec-driven play** — the busted suite plays real sessions via
   frame→button hit-testing (`tests/spec_helper.lua` `click`), so the
   navigation it proves is the navigation a player performs.
3. **Visual check (D-221)** — SHOULD: dark ground, hot-pink accents,
   readable call panel, figure on stage, pads labelled. SEEN:
   rasterised capture frames (level 2, hold phase) and headless-Chrome
   screenshots of the assembled `web/index.html` (gate screen; demo
   level 3 call phase). Both matched the SHOULD at viewing size; the
   figure's cloth colour was brightened one step after the first
   capture read too dark against the stage panel.

## Checklist

| # | Check | Result |
|---|---|---|
| 1 | Boot lands on the 18+ gate; LEAVE exits to the left screen | PASS (specs) |
| 2 | Gate → title → level select → drill 1 starts | PASS (specs, click-walk) |
| 3 | Locked drills are not clickable before unlock | PASS (specs) |
| 4 | Drill 1 completes under the demo policy and passes | PASS (specs) |
| 5 | Drills 2 and 3 complete; recall rounds occur and score | PASS (specs) |
| 6 | Wrong pads: two marks survive a call, three lose it | PASS (specs) |
| 7 | Timeout scores zero and costs composure; repeated timeouts fail the drill | PASS (specs) |
| 8 | Bracing out-scores unbraced holding on the severe preset | PASS (specs) |
| 9 | Stop ends the drill, is witnessed, never advances rank | PASS (specs) |
| 10 | Pause freezes the drill clock | PASS (specs) |
| 11 | Settings persist (volume, sway assist) through save/reload | PASS (specs) |
| 12 | Ceremony advances at most one rank step; consumed sessions reject | PASS (specs) |
| 13 | Hostile input/save fuzz never crashes and state stays bounded | PASS (specs) |
| 14 | Same seed → identical draw lists (determinism) | PASS (specs + conformance) |
| 15 | Preview videos exist per level, ≤ 4 MB, from the shipped core | PASS (45 KB each) |
| 16 | Assembled single file boots in a real browser engine | PASS (headless Chrome) |

## Notes for the Owner's hands

- Brace feel (poise drain vs sway growth) is tuned by constants in
  `src/drill.lua`; the demo policy braces conservatively, so a human
  can out-score it — intended.
- The figure is the D-292 abstract stand-in (point-set stick figure);
  keeper art was not generated (character generation is paused).
