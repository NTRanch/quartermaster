// tools/capture.mjs — preview capture for one level.
// Usage: node tools/capture.mjs <level> [seed] [outPath]
// Steps the SHIPPED Lua core (Fengari, demo mode) at 10 fps for 12 s,
// rasterises each draw list with the shared rasteriser, and encodes
// docs/previews/level-<n>-quartermaster.mp4 with ffmpeg. The video shows
// the real game logic; nothing here is a mock-up.
import { execFileSync } from "node:child_process";
import { mkdirSync, rmSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { bootGame } from "./lua-host.mjs";
import { rasterise, writePNG } from "./raster.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..");

const level = Number(process.argv[2] || 1);
const seed = Number(process.argv[3] || 42);
const outPath =
  process.argv[4] ||
  join(ROOT, "docs", "previews", `level-${level}-quartermaster.mp4`);

const FPS = 10;
const SECONDS = 12;
const TICKS_PER_FRAME = 6; // core tick is 1/60 s

const game = bootGame({ seed, demoLevel: level });
const framesDir = join(ROOT, "docs", "previews", `.frames-${level}`);
rmSync(framesDir, { recursive: true, force: true });
mkdirSync(framesDir, { recursive: true });
mkdirSync(dirname(outPath), { recursive: true });

for (let frameIndex = 0; frameIndex < FPS * SECONDS; frameIndex++) {
  for (let tick = 0; tick < TICKS_PER_FRAME; tick++) game.step(null);
  const frame = game.frame();
  const px = rasterise(frame, 480, 480);
  const name = `frame-${String(frameIndex).padStart(3, "0")}.png`;
  writePNG(join(framesDir, name), px, 480, 480);
}

execFileSync(
  "/usr/bin/ffmpeg",
  [
    "-y", "-framerate", String(FPS), "-i", join(framesDir, "frame-%03d.png"),
    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "26",
    "-movflags", "+faststart", outPath,
  ],
  { stdio: "pipe" }
);
rmSync(framesDir, { recursive: true, force: true });
const bytes = statSync(outPath).size;
console.log(`level ${level}: ${outPath} ${bytes} bytes`);
if (bytes > 4 * 1024 * 1024) {
  console.error("preview exceeds the 4 MB budget");
  process.exit(1);
}
