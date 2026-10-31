// Browser stub for node's "fs" (fengari liolib binds it; the core never calls io.*).
const fail = () => { throw new Error("fs unavailable in the single-file shell"); };
module.exports = { readFileSync: fail, writeFileSync: fail, existsSync: () => false,
  createReadStream: fail, createWriteStream: fail, constants: {} };
