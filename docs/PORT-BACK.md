# Port-back — Quartermaster → Torogao

What W9 validated, stated in Torogao's terms, so the port is a
transcription of proven shapes rather than a fresh design. Lane law
applies to every line below (§9): the content is systems-shaped and
SFW-transferable; Sloane's fiction stays in this repo.

## 1. The evidence ledger (ache / session-evidence systems)

- **Append-only, bounded, self-auditing.** `src/ledger.lua`: entries
  are validated at append (kind whitelist, score range, label bound),
  stored as copies (the caller's table is never retained), capped at
  a named constant (512), and `audit()` re-derives seq + totals from
  the entries and asserts them against the cached sums — cached state
  is a cache, never a source of truth.
- **Torogao form:** the same three properties map directly onto
  session-evidence logs for the rig runtime: bounded ring with
  explicit overflow refusal (not silent truncation), per-entry
  validation at the write boundary, and an audit pass that any
  consumer can run before trusting totals.
- **Gate evidence:** `tests/ledger_spec.lua` — flood-to-capacity,
  negative/over-range scores, unknown kinds, and caller-mutation
  cases all behave as specified (in the 42-spec suite).

## 2. The appraisal ceremony (progression gates)

- **One gate, one place, one step.** `src/ceremony.lua` is the only
  module that mutates rank. Its predicate `earns_step` is pure:
  not-stopped ∧ passed ∧ ratio ≥ per-rank gate ∧ faults ≤ ceiling.
  Application consumes the session (replay protection: a witnessed
  session can never be applied twice), moves at most one rank step,
  and records best-percent + unlock as separate, separately-tested
  side effects.
- **Torogao form:** any ladder movement in the Crescendo system —
  including Sloane's own ladder, whose W9 verdict this entry files
  against — should be a pure predicate over a session record plus a
  single consuming apply. The W9 numbers that balanced: rank gates at
  ratio 0.55 / 0.60 / 0.65 / 0.70 with a hard fault ceiling of 3;
  level pass bands looser than rank gates (0.60 / 0.65 / 0.70), so a
  level can be cleared without earning the step — teach → T1-gate
  arithmetic that felt fair in demo-policy simulation across all
  three levels.
- **Stop semantics are part of the gate contract:** a stopped session
  is witnessed (ceremony count + best-percent update) but can never
  advance rank. Port this verbatim wherever a participant-facing stop
  exists.

## 3. Position inventory + drill state machine

- **Content as data, behaviour as one machine.** Eight positions are
  point-set records in `src/data.lua`; the drill (`src/drill.lua`)
  is a single explicit phase machine (call → hold → appraise →
  recall_show → recall_answer → appraise → done) with every timing
  a named constant. Seeded call order never repeats the previous
  target (bounded rerolls, then the next index — termination is
  structural, not hoped for).
- **Torogao form:** pose/position inventories for the rig and the
  face-state machinery should stay data tables consumed by one
  machine, exactly this shape; the recall weave (a later call asks
  back an earlier item from memory, T2-Protocol-Recall shape)
  generalises to any teach-then-test loop in training content.

## 4. Persistence (save records everywhere)

- **`QM1|…` format:** one line, whitelisted keys, strict ranges,
  duplicates and unknown keys reject the *whole* record, missing
  keys default. Serialisation is a pure function of the record, so
  round-trips are byte-identical and fuzz-verifiable (200 seeded
  hostile strings in `tests/save_spec.lua`; anything that parses
  must re-serialise and re-parse).
- **Torogao form:** adopt the same discipline for any hand-rolled
  record that crosses a trust boundary (browser storage, file
  drops): reject-whole over half-load, and never a `load()`-based
  deserialiser.

## 5. Lua verdict (the D-335 language question for table-driven work)

- **Verdict: Lua earns its rotation slot for protocol/table-driven
  systems.** The whole mechanism group — ledger, ceremony, drill,
  persistence, demo policy — is ~2,300 lines of readable Lua with
  zero VM-specific code in the core; the busted suite (42 specs)
  runs headless under PUC 5.4 in ~0.2 s, and the shipped Fengari
  artifact passes a byte-identical 720-tick conformance gate
  against it.
- **Two portability findings travel with the verdict** (both in
  `docs/BREAKAGE-LOG.md`): (a) cross-VM arithmetic must avoid `%`
  and `/` on operands above 2^31 — Schrage decomposition keeps the
  RNG exact in both number models; (b) the Fengari browser bundle
  needs inert stubs for node builtins and its CLI-only deps, plus
  an esbuild define for `luaconf`'s unguarded `process.env` read —
  and a `process` shim is a trap (it flips Fengari's own env
  detection). `tools/build-vendor.sh` is the reproducible recipe.
- **Filing:** this entry is the GJ-09 close-out evidence for
  roadmap R-906; the Torogao-side adoption items (ledger shape,
  ceremony gate, save discipline) are proposed, not landed — they
  land under Torogao's own bloch items when the port runs.
