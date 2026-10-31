![Quartermaster header](assets/brand/header.png)

# Quartermaster

**Nice Thoughts Ranch** · Torogao Jam Program week 9 (Wave C — Mini-games: the Crescendo set) · Sloane · **Lua** · status: **v1.0.0**

Drilled — Positions Drill: Call-and-Hold, her step-2 game.

An 18+ game built for the weekly Gameotron jam on itch.io (NTRanch), as one
rung of the 14-week Torogao system-validation program (D-333/D-334/D-335/D-336).
The full planning book lives in [`book/`](book/) (mdBook, NTRanch theme);
this repo's bloch roadmap is [`.ai/roadmap.md`](.ai/roadmap.md).

_The Quartermaster keeps the book. Positions are called, held, and
appraised; every call is written into the ledger as evidence; and at the
appraisal ceremony the book is witnessed — rank moves there, and nowhere
else. What the drill trains has a plainer name, and the book, in the end,
says it._

Sloane's step-2 game in the Crescendo programme (canon:
`canon://ntranch/crescendo-ladders@1`). Her kink set of record: tantric /
yoni massage, sex toys, collared and leashed, slavery and training,
appraisal, chastity.

## Play

Open `web/index.html` in a browser. One file, no server, no assets: the
game is readable Lua source running on an embedded Fengari VM (view
source — the core ships in the page as the `QM_SOURCES_JS` block, under
320 KB total). Progress persists in the browser's local storage.

## The three drills

| Level | Stage | Brush | What changes |
|---|---|---|---|
| 1 · **First Drill** | Teach | Soft | Positions are called by name, with a ghost of the pose on stage. Six calls. |
| 2 · **Second Drill** | The Brush Turns Firm | Firm | Calls come by name and number; from the fourth call, earlier positions are recalled from memory (Protocol Recall). |
| 3 · **Third Drill** | From Memory | Severe | Calls come by number alone. Two recall rounds, a tighter brush, and the book is complete: pass it and the ceremony names what the training was. |

Clearing a drill unlocks the next. Rank climbs one step per qualifying
ceremony — Consideration → In Training → Owned → Entrusted Quartermaster
→ Formal / Kept — and only ever at the ceremony.

## How to play

- A position is **called** (by name, by number, or, in the first drill,
  with a ghost of the pose). Answer on the position pads (click, tap, or
  keys `1`–`8`) before the bar runs out. A wrong pad is a mark against
  the call; three lose it.
- Then **hold**: the figure sways, wider as the hold goes on. Hold the
  pad (or hold `Space`) to **brace** and steady her — bracing drains
  poise, and poise only returns while you are not bracing. The needle on
  the Appraisal Brush is the sway itself; the brush's stiffness preset
  (soft / firm / severe) decides how much sway the score forgives.
- Some calls are **recalls**: a sequence of positions is shown, then
  asked back from memory, one pad at a time.
- Composure is three marks. Timeouts and lost calls cost one each; lose
  all three and the drill ends in failure. **Stop** (the red button)
  ends any drill at once, without penalty, forever available — the
  ledger records that the participant stopped, and the ceremony
  witnesses the book as it stands.
- `Esc` or the Pause button pauses. Settings carry volume and a
  sway-assist toggle (a wider brush tolerance), both persisted.

Scoring is all arithmetic and all in the open: reaction speed and
steadiness, fifty points each, scaled by the brush preset. The ceremony
screen shows the whole ledger — every call, every score — before it
rules.

## Previews

Rendered from the shipped build in demo mode (`?demo=<level>&seed=42`,
scripted policy, `tools/capture.mjs`) — the videos show the real game
logic, not a mock-up:

- [Level 1 — First Drill](docs/previews/level-1-quartermaster.mp4)
- [Level 2 — Second Drill](docs/previews/level-2-quartermaster.mp4)
- [Level 3 — Third Drill](docs/previews/level-3-quartermaster.mp4)

## Systems (what the jam entry validates for Torogao)

- **Evidence ledger** — append-only, bounded, self-auditing; totals are
  recomputed from entries and asserted, never trusted.
- **Appraisal ceremony** — the single rank gate: a pure predicate over
  the session (passed, ratio band, fault ceiling, not stopped), applied
  at most one step, with replay protection (a consumed session can
  never be witnessed twice).
- **Position inventory + drill state machine** — eight positions as
  point-set data; seeded call order with no immediate repeats; recall
  sequences woven into later calls.
- **Persistence** — a hand-written, strictly validated save string
  (`QM1|…`): unknown keys, duplicates, and out-of-range values reject
  the whole record rather than half-loading it.
- **Lua across two VMs** — one readable core, PUC Lua 5.4 headless and
  Fengari in the page, with a byte-identical conformance gate between
  them. What that took is in `docs/BREAKAGE-LOG.md`; what Torogao
  inherits is in `docs/PORT-BACK.md`.

## Build and test

```sh
just build     # luac -p all sources → busted specs → cross-VM conformance
               # → assemble web/index.html → write docs/SHA256SUMS.txt
just test      # the busted suite alone (42 specs, half adversarial)
just previews  # re-render the three preview videos from the shipped core
just book      # the mdBook process documentation (book/)
```

Toolchain: estate Lua 5.4.8 (`~/workspace/tools/lua-5.4.8`), busted from
the estate luarocks tree, node for the VM bundle and capture pipeline,
ffmpeg for the encodes. `tools/build-vendor.sh` rebuilds the vendored
Fengari browser bundle from `tools/node_modules`.
