#!/usr/bin/env bash
# Quartermaster build: gates first, then assemble the single file.
# lua 5.4.8 estate toolchain; node for the VM bundle + assembly.
set -euo pipefail
cd "$(dirname "$0")"

LUA="$HOME/workspace/tools/lua-5.4.8/src/lua"
LUAC="$HOME/workspace/tools/lua-5.4.8/src/luac"
BUSTED="$HOME/workspace/tools/luarocks-tree/bin/busted"

echo "== luac -p (all Lua sources)"
for f in src/*.lua tests/*.lua web/bootstrap.lua; do
    "$LUAC" -p "$f"
done

echo "== busted (validation + adversarial)"
"$BUSTED"

echo "== cross-VM conformance (PUC 5.4 vs shipped Fengari)"
node tools/conformance.mjs

echo "== assemble web/index.html"
node tools/assemble.mjs

echo "== checksums"
( cd docs && sha256sum ../web/index.html previews/*.mp4 > SHA256SUMS.txt )
cat docs/SHA256SUMS.txt
echo "build OK"
