// stubs/readline-sync.js — inert stand-in for the browser bundle.
// readline-sync serves fengari's interactive node CLI only; the embedded
// VM never prompts, and a browser cannot read a terminal line.
"use strict";
function unavailable() {
    throw new Error("readline-sync is unavailable in the browser build");
}
module.exports = {
    question: unavailable,
    prompt: unavailable,
    setDefaultOptions: function () {},
};
