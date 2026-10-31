// Browser stub for node's "path" (string-only helpers fengari may touch at init).
module.exports = { sep: "/", delimiter: ":",
  join: (...a) => a.filter((s) => s && s.length).join("/"),
  resolve: (...a) => a.filter((s) => s && s.length).join("/"),
  dirname: (p) => p.replace(/\/[^/]*$/, "") || "/",
  basename: (p) => p.replace(/.*\//, ""),
  extname: (p) => { const m = /\.[^./]*$/.exec(p); return m ? m[0] : ""; } };
