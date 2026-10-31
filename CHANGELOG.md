# Changelog — Quartermaster

All notable changes, newest first. Format: Keep a Changelog.

## [1.0.0] — 2026-10-30

The full mechanism group, playable end to end in one file.

- **Drilled — Positions Drill: Call-and-Hold**, all three drills
  (First / Second / Third) with escalating call modes (name + ghost →
  name + number → number only), six / eight / ten calls, and Protocol
  Recall woven into drills 2 and 3.
- **Appraisal Brush** scoring: reaction + steadiness under three
  stiffness presets (soft / firm / severe); brace-and-poise hold play.
- **Evidence ledger + appraisal ceremony**: the ceremony is the only
  place rank moves — one step per qualifying session, replay-protected,
  stopped sessions witnessed without advancement.
- **Persistence**: hand-written strictly-validated `QM1|…` career
  record (rank, unlocks, best percents, ceremonies, volume, assist).
- **Screens**: 18+ gate, title, level select, how to play, settings
  (volume, sway assist, reduce motion), play, pause, ceremony,
  game over, victory — with the ledger read on the ceremony screen and
  the revelation lines on victory.
- **VM**: Fengari 0.1.4 inlined in `web/index.html` (readable Lua
  sources ship in the page); the same core runs under PUC Lua 5.4 for
  the headless suite. 42 busted specs (validation + adversarial),
  cross-VM conformance gate (720 demo ticks, byte-identical dumps).
- **Previews**: one demo-mode capture per drill in `docs/previews/`.

## [Unreleased]

- Repo scaffolded 2026-10-30: bloch roadmap (kind=game, lane=restricted),
  planning, per-game skill, baseline Lua config, NTRanch-themed mdBook,
  brand-asset slots.
