// Browser stub for node's "os" (fengari loslib binds it; the core never calls os.*).
module.exports = { platform: () => "browser", tmpdir: () => "/tmp",
  hostname: () => "jam", EOL: "\n", arch: () => "wasm", release: () => "0" };
