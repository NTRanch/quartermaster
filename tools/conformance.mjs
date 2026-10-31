// tools/conformance.mjs — cross-VM gate: the canonical demo dump from
// PUC Lua 5.4 (headless truth) must equal the dump from the shipped
// Fengari artifact, byte for byte. Usage: node tools/conformance.mjs
import { execFileSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { bootGame } from "./lua-host.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..");
const ESTATE_LUA = "/home/hatch/workspace/tools/lua-5.4.8/src/lua";

const LEVEL = 1;
const SEED = 42;
const TICKS = 720;

function dumpFrame(frame) {
  return frame.ops
    .map((op) =>
      op
        .map((v) => (typeof v === "number" ? String(Math.trunc(v)) : String(v)))
        .join(",")
    )
    .join("\n");
}

const puc = execFileSync(
  ESTATE_LUA,
  [join(ROOT, "tests", "demo_dump.lua"), String(LEVEL), String(SEED), String(TICKS)],
  { cwd: ROOT, encoding: "utf8" }
);

const game = bootGame({ seed: SEED, demoLevel: LEVEL });
const chunks = [];
for (let tick = 1; tick <= TICKS; tick++) {
  game.step(null);
  if (tick % 6 === 0) chunks.push(dumpFrame(game.frame()) + "\n==");
}
const fengari = chunks.join("\n") + "\n";

if (puc === fengari) {
  console.log(`conformance: PUC 5.4 == Fengari 5.3, ${TICKS} ticks, identical dumps`);
} else {
  const pucLines = puc.split("\n");
  const fenLines = fengari.split("\n");
  for (let i = 0; i < Math.max(pucLines.length, fenLines.length); i++) {
    if (pucLines[i] !== fenLines[i]) {
      console.error(`first divergence at dump line ${i}:`);
      console.error("  PUC:     " + pucLines[i]);
      console.error("  Fengari: " + fenLines[i]);
      break;
    }
  }
  process.exit(1);
}
