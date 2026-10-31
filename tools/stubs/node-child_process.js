// Browser stub for node's "child_process" (bound by fengari aux libs; never called).
const fail = () => { throw new Error("child_process unavailable in the shell"); };
module.exports = { exec: fail, execSync: fail, spawn: fail, spawnSync: fail };
