#!/usr/bin/env bash
# Rebuild tools/vendor/fengari-web.js from tools/node_modules (fengari +
# esbuild installed there). The browser bundle needs three accommodations,
# each measured against a real load failure (see docs/BREAKAGE-LOG.md):
#   1. node builtins that fengari's loader/io/debug modules require are
#      aliased to inert stubs in tools/stubs/ (browser has no fs/os/...).
#   2. fengari's node-CLI-only dependencies (tmp, readline-sync) probe
#      process.binding at load; they are stubbed the same way.
#   3. src/luaconf.js reads process.env.FENGARICONF unguarded; an esbuild
#      define rewrites that one expression to `undefined`. A real process
#      shim is NOT an option: fengari's environment detection keys off
#      `typeof process` and a shim flips it onto the node path.
set -euo pipefail
cd "$(dirname "$0")"
npx esbuild fengari-entry.js --bundle --format=iife --platform=browser \
    --outfile=vendor/fengari-web.js \
    --define:process.env.FENGARICONF="undefined" \
    --alias:os=./stubs/node-os.js \
    --alias:fs=./stubs/node-fs.js \
    --alias:child_process=./stubs/node-child_process.js \
    --alias:path=./stubs/node-path.js \
    --alias:crypto=./stubs/node-crypto.js \
    --alias:readline=./stubs/node-readline.js \
    --alias:tmp=./stubs/tmp.js \
    --alias:readline-sync=./stubs/readline-sync.js
echo "vendor bundle rebuilt: $(wc -c < vendor/fengari-web.js) bytes"
