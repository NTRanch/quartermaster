# Roadmap — quartermaster (game) — v0.1 → v1.0
<!-- bloch:roadmap schema=1 kind=game lane=restricted baseline=0.1.0 target=1.0.0 -->

How to work this roadmap (any agent): run `bloch task start R-xxx --agent <you>` before working a task, `bloch task done R-xxx` when you believe it is complete — done runs every `verify:` command and flips the task green only if all pass; there is no override. `bloch task fail R-xxx --error "..."` records a failure. Fixes learned the hard way land in `.ai/memory/lessons.md` via the inbox/promote flow and are surfaced in every HANDOFF.

## Phase 1 — Baseline truth
- [x] R-101 Build is green from a clean checkout
  - verify: ./build.sh
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:42Z
- [x] R-102 Existing tests pass at the baseline
  - verify: /home/hatch/workspace/tools/luarocks-tree/bin/busted
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:43Z
- [x] R-103 Repo identity, baseline version, and this roadmap are recorded
  - verify: grep -q 'kind=game' .ai/roadmap.md && grep -q 'VERSION = "1.0.0"' src/main.lua
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:38Z

## Phase 2 — Core complete
- [x] R-201 Core loop is playable from start to finish
  - verify: /home/hatch/workspace/tools/luarocks-tree/bin/busted tests/drill_spec.lua tests/adversarial_spec.lua
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:43Z
- [x] R-202 Save and load round-trips game state
  - verify: /home/hatch/workspace/tools/luarocks-tree/bin/busted tests/save_spec.lua
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:43Z
- [x] R-203 Settings and accessibility options persist across sessions
  - verify: /home/hatch/workspace/tools/luarocks-tree/bin/busted tests/quartermaster_spec.lua
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:43Z

## Phase 3 — Tests and gates
- [x] R-301 Validation tests cover the happy path end to end (half the test split)
  - verify: /home/hatch/workspace/tools/luarocks-tree/bin/busted tests/quartermaster_spec.lua tests/drill_spec.lua tests/ceremony_spec.lua
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:43Z
- [x] R-302 Adversarial tests cover malformed, oversized, and hostile inputs (half the test split)
  - verify: /home/hatch/workspace/tools/luarocks-tree/bin/busted tests/adversarial_spec.lua tests/save_spec.lua tests/ledger_spec.lua
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:43Z
- [x] R-303 Structured playtest checklist is executed and its record filed
  - verify: grep -q 'agent playtest' docs/PLAYTEST.md && grep -q 'PASS' docs/PLAYTEST.md
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:43Z

## Phase 4 — Hardening
- [x] R-401 Performance budget holds on target hardware
  - verify: test $(wc -c < web/index.html) -le 786432 && test $(stat -c%s docs/previews/level-3-quartermaster.mp4) -le 4194304
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:03:38Z
- [x] R-402 Platform builds produce runnable artefacts
  - verify: node tools/assemble.mjs && grep -q 'QM_SOURCES_JS' web/index.html
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:45Z
- [x] R-403 Safety-critical options (stop/safeword-equivalents, accessibility) are never gated behind progression
  - verify: /home/hatch/workspace/tools/luarocks-tree/bin/busted tests/drill_spec.lua
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:45Z

## Phase 5 — Docs
- [x] R-501 README documents install, usage, and verification
  - verify: grep -q 'How to play' README.md && grep -q 'just build' README.md
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:45Z
- [x] R-502 CHANGELOG records every user-facing change
  - verify: grep -q '## \[1.0.0\]' CHANGELOG.md
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:45Z

## Phase 6 — Release v1
- [x] R-601 Version is bumped to 1.0.0 and the changelog records the release
  - verify: grep -q '1.0.0' CHANGELOG.md && git tag -l v1.0.0 | grep -q 'v1.0.0'
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:45Z
- [x] R-602 Clean-environment install and run is verified
  - verify: /home/hatch/workspace/tools/chrome-for-testing/chrome-linux64/chrome --headless=new --disable-gpu --no-sandbox --virtual-time-budget=5000 --dump-dom file://$PWD/web/index.html?demo=1\&seed=42 2>/dev/null | grep -q 'QUARTERMASTER'
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:51Z
- [x] R-603 Release artefacts are built from a clean checkout and checksummed
  - verify: cd docs && sha256sum -c SHA256SUMS.txt
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:51Z


## Phase 9 — Jam program (week 9, D-333)
- [x] R-901 Design chapter complete: mechanism group + canon core recorded
  - verify: test -f book/src/design.md
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T05:47:07Z
- [x] R-902 Engine research pinned for Lua (libraries, versions, licences)
  - verify: test -f book/src/engine-research.md
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T05:47:07Z
- [x] R-903 Single-file index.html assembles and runs offline with all screens
  - verify: grep -q 'QM_SOURCES_JS' web/index.html && grep -q 'ADULTS ONLY - 18+' web/index.html
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:51Z
- [ ] R-904 GJ-07 passed: 18+ flag, warnings listed, itch ToS screen (verified live at entry)
  - verify: test -f book/src/jam.md
- [ ] R-905 Seahawk playtest pass recorded; breakage log filed
  - verify: test -f docs/BREAKAGE-LOG.md
- [x] R-906 Port-back note + Lua language verdict + §9 transfer filing
  - verify: grep -q 'Lua verdict' docs/PORT-BACK.md && grep -q 'transfer filing' book/src/port-back.md
  - evidence: 1 verify commands, all exit 0 at 2026-10-31T06:02:51Z
