# Build & Delivery — Quartermaster

**Language:** Lua 5.4 sources under tiger-style-lua, written in the
5.3 ∩ 5.4 intersection dialect (see the engine chapter's decision of
record).

**Delivery shape:** one self-contained `web/index.html` (604,884
bytes, most of it the unminified Fengari VM): the Fengari 0.1.4 VM inlined as a browser bundle, the readable
Lua core inlined as the `QM_SOURCES_JS` block, a shared bootstrap, and
a small JS shell (canvas / input / generated WebAudio / localStorage).
The Lua renders nothing; it emits draw lists on a 960×960 logical
canvas, and the shell presents them.

**Toolchain (all sandbox-local):**

- Estate Lua 5.4.8 (`~/workspace/tools/lua-5.4.8/src/lua`) — headless
  truth: `luac -p` on every source, busted suite from the estate
  luarocks tree (42 specs, half validation / half adversarial).
- Node 24 — the capture pipeline, the cross-VM conformance gate, the
  page assembler (`tools/assemble.mjs`), and the vendor bundle build
  (`tools/build-vendor.sh`, esbuild; stubs under `tools/stubs/`).
- ffmpeg — preview encodes (`tools/capture.mjs`: the shipped core in
  demo mode at 10 fps × 12 s per level, shared rasteriser).
- Headless Chrome (chrome-for-testing) — screenshot smoke of the
  assembled file: 18+ gate and demo gameplay both verified.

**Build:** `just build` runs `./build.sh` — syntax gate, specs,
conformance, assembly, and `docs/SHA256SUMS.txt` written over the
page and the three preview videos. Green is what the gates say;
`just previews` re-renders the videos; `just book` renders this book.

**Jam rule honoured:** one self-contained `index.html`, ten screens
(18+ gate first; Title / How to Play / Gameplay / Pause / Settings /
Level Select / Ceremony / Game Over / Victory), documented process —
this book, `docs/PORT-BACK.md`, `docs/PLAYTEST.md`,
`docs/BREAKAGE-LOG.md`.
