# Port-Back — Quartermaster

Filed at the week's close, 2026-10-30, against v1.0.0. The full text
lives in the repo at `docs/PORT-BACK.md`; this chapter is the book's
copy of the verdict section.

- **Verdict:** Drilled plays. The call-and-hold loop carries a full
  session without the fiction doing any mechanical work: answer,
  brace, be scored, be written into the book. Escalation is honest —
  the same eight positions, less help, a stiffer brush — and the
  third drill's number-only calls plus two recall rounds make "from
  memory" a mechanic rather than a line of dialogue.
- **Numbers (against Sloane's ladder record):** rank gates at
  session ratio 0.55 / 0.60 / 0.65 / 0.70 with a hard fault ceiling
  of 3; level pass bands deliberately looser (0.60 / 0.65 / 0.70) so
  a drill can be cleared without earning the step. The demo policy
  passes all three drills; the ceremony moves at most one rank step
  per witnessed session, and stopped sessions never advance.
  Teach → T1-gate arithmetic: fair, because the gate is arithmetic
  the player can read on the ceremony screen before it rules.
- **Language verdict (Lua):** Lua carried table-driven protocol work
  exactly as the dossier hoped — the ledger, the ceremony gate, the
  drill machine, and the save format are all plain tables and small
  functions, 1,903 lines, 42 busted specs in ~0.2 s headless. What
  it fought: cross-VM float arithmetic (one `%` desync, fixed with
  Schrage) and the Fengari browser bundle's node probes (stubbed;
  recipe in `tools/build-vendor.sh`). What it cost: one discipline —
  the core is written in the 5.3 ∩ 5.4 intersection dialect.
- **Breakage:** `docs/BREAKAGE-LOG.md` — the RNG modulo desync and
  the three bundle load failures, each with its fix.
- **§9 transfer filing:** ledger shape, ceremony-gate pattern, and
  save-record discipline are systems content, label **sfw**, and may
  transfer. Sloane's fiction, the position names, and the revelation
  text are NSFW-lane content and stay in this repo.
