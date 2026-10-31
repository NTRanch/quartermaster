// stubs/tmp.js — inert stand-in for the npm `tmp` package in the browser
// bundle. Fengari depends on tmp only for its node CLI helpers; the VM
// itself never creates temp files, and a browser cannot.
"use strict";
function unavailable(name) {
    return function () {
        throw new Error("tmp." + name + " is unavailable in the browser build");
    };
}
module.exports = {
    dir: unavailable("dir"),
    dirSync: unavailable("dirSync"),
    file: unavailable("file"),
    fileSync: unavailable("fileSync"),
    setGracefulCleanup: function () {},
    tmpdir: "/tmp",
};
