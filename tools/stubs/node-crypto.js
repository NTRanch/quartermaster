// Browser stub for node's "crypto" (fengari binds it for os randomness; unused here).
module.exports = { randomBytes: (n) => new Uint8Array(n),
  getRandomValues: (a) => a };
