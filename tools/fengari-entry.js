// Browser entry for the Fengari VM bundle. No process shim: fengari's
// own environment detection keys off `typeof process`, and a shim would
// flip it onto the node path (which then reads the bare `global`). The
// node-only CLI dependencies that probe process at load (tmp,
// readline-sync) are aliased to inert stubs at bundle time instead.
window.Fengari = require("fengari");
