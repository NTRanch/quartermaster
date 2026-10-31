# Breakage log — Quartermaster

Every breakage found in playtest or build lands here with: what broke, the
evidence, the bloch attempt id, and the fix or the filed finding. Copied to
bloch at the week's close (the log is the input, bloch is the record).

## 2026-10-30 — Cross-VM RNG divergence (Fengari float modulo)

- **What broke:** the first cross-VM conformance run diverged at dump line
  403. Probing isolated it to the Park-Miller step: from seed 2303 the
  second state came out 1781829919 under Fengari vs 1781832417 under PUC
  5.4 — off by exactly the division quotient. Fengari's float `%` loses
  the quotient on large operands, so `(state * 48271) % 2147483647` is
  not portable even though every intermediate is below 2^53.
- **Fix:** Schrage decomposition in `src/rng.lua` (Q=44488, R=3399); every
  intermediate stays below 2^31 and the sequence is now byte-identical
  across VMs (verified for seeds 42 / 2303 / 999373, and by the standing
  conformance gate: 720 demo ticks, identical frame dumps).
- **Lesson filed:** any future estate Lua that must agree across VMs
  avoids `%` and `/` on operands above 2^31 unless the algorithm is
  decomposed into small exact steps.

## 2026-10-30 — Fengari browser bundle: three load-time probes

- **What broke:** the first assembled page rendered the fail surface
  ("Lua VM missing"). The esbuild bundle threw at load in a browser
  context, three times in sequence: (1) fengari's CLI-only transitive
  deps `tmp` and `readline-sync` call `process.binding(...)` at module
  init; (2) fengari's own `src/luaconf.js` reads
  `process.env.FENGARICONF` unguarded; (3) a global `process` shim —
  the obvious fix for (1)/(2) — flips fengari's environment detection
  (`typeof process`) onto its node path, which then reads the bare
  `global` and throws anyway.
- **Fix:** `tools/build-vendor.sh` — node builtins + the two CLI deps
  aliased to inert stubs in `tools/stubs/`; the single unguarded
  expression neutralised with an esbuild `--define`. Verified by
  evaluating the bundle in a `process`-less VM context (18 exports,
  `6 * 7 = 42` through a real lua state) and by headless Chrome
  screenshots of the assembled page (gate screen + demo mode).
