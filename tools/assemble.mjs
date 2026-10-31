// tools/assemble.mjs — build the single distributable web/index.html:
// shell template + Fengari bundle + readable Lua sources + bootstrap +
// bridge, all inlined. The page is the artifact; process honesty is
// kept by shipping the exact core sources the tests and captures run.
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..");

const shell = readFileSync(join(ROOT, "web", "shell.html"), "utf8");
const fengari = readFileSync(join(ROOT, "tools", "vendor", "fengari-web.js"), "utf8");
const bridge = readFileSync(join(ROOT, "web", "bridge.js"), "utf8");
const bootstrap = readFileSync(join(ROOT, "web", "bootstrap.lua"), "utf8");

const sources = {};
for (const file of readdirSync(join(ROOT, "src"))) {
  if (file.endsWith(".lua")) {
    sources["src." + file.slice(0, -4)] =
      readFileSync(join(ROOT, "src", file), "utf8");
  }
}

function fill(template, marker, content) {
  if (!template.includes(marker)) throw new Error("marker missing: " + marker);
  // Function replacement: bundle/source text may contain $ patterns.
  return template.replace(marker, content);
}

let html = shell;
html = fill(html, "/*__FENGARI__*/", () => fengari);
html = fill(html, "/*__SOURCES__*/", () => JSON.stringify(sources));
html = fill(html, "/*__BOOTSTRAP__*/", () => JSON.stringify(bootstrap));
html = fill(html, "/*__BRIDGE__*/", () => bridge);
writeFileSync(join(ROOT, "web", "index.html"), html);
console.log("web/index.html:", html.length, "bytes");
