# Jam Checklist — Quartermaster

Seeded from the program's Gameotron checklist (`checklists/gameotron-jam.md`
in the Ardor program home). Verify each item live at entry; grades recorded
here are scaffold-time states, not evidence.

- [x] GJ-01 GAMEOTRON process documented for this entry (incl. language chain)
- [x] GJ-02 Single self-contained `index.html` assembles and runs offline
- [x] GJ-03 ≥6 screens present (Title / Pause / How to Play / Gameplay / Settings / Game Over-or-Victory)
- [x] GJ-04 Human ideation-approval gate recorded (GAMEOTRON requirement)
- [ ] GJ-05 itch project created under NTRanch, slug `ntranch/quartermaster`
- [x] GJ-06 This week's toolchain preflight passed and recorded
- [ ] GJ-07 18+ flag set, content warnings listed, itch ToS screen passed (re-verify the NSFW clause live at entry)
- [ ] GJ-08 Seahawk playtest pass done; breakage log filed to bloch
- [x] GJ-09 Port-back note + language verdict filed; §9 transfer filing made

## Closing ritual (every rung)

seahawk playtest → breakage log to bloch → port-back note (with language
verdict) → §9-labelled transfer filing.

## States of record (2026-10-30, v1.0.0)

- GJ-04: the entry itself is the human gate — the 14-week programme,
  the mechanism groups, and the build-to-1.0 directive are the
  Owner's (D-333/D-334, and the 2026-10-30 22:42 PDT directive).
- GJ-05 / GJ-07: **open** — itch project creation and the 18+ flag
  ride the parent's publish step, not this repo build. The page
  carries its own 18+ gate and warnings regardless.
- GJ-08: **open, blocked** — the seahawk playtest leg runs on primo;
  the sandbox↔primo tunnel has been down since 2026-10-30 03:15 PDT.
  Substitute executed and filed: the structured agent playtest in
  `docs/PLAYTEST.md` (demo-policy runs, spec-driven play, D-221
  visual checks, headless-Chrome smoke). Seahawk pass still owed
  when the tunnel returns; breakage found so far is filed in
  `docs/BREAKAGE-LOG.md` and the bloch attempts.
