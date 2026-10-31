# Quartermaster — recipes. `just build` is the full gate + assembly.

# Full build: luac, specs, cross-VM conformance, assemble, checksums.
build:
    ./build.sh

# mdBook process documentation.
book:
    mdbook build book

# The same gates as build (build.sh runs them before assembling).
check:
    ./build.sh

# Specs only (busted on the estate Lua 5.4 toolchain).
test:
    ~/workspace/tools/luarocks-tree/bin/busted

# Re-render the per-level preview videos from the shipped core.
previews:
    node tools/capture.mjs 1 42
    node tools/capture.mjs 2 42
    node tools/capture.mjs 3 42
