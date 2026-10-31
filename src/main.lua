-- src/main.lua — Quartermaster public API (the shell's whole contract).
--
--- new_game(seed, options) -> state
--- step(state, input)      -> advance one fixed 1/60 s tick
--- frame(state)            -> { palette, ops, cues, save, volume }
--- The core is VM-portable (PUC 5.4 headless, Fengari 5.3 shipped): no
--- host APIs in here; the bridge lives in the shell and tools.

local Game = require("src.game")

local M = {}

M.VERSION = "1.0.0"

---@param seed number
---@param options table|nil { demo_level = integer|nil, save = string|nil }
---@return table state
function M.new_game(seed, options)
    return Game.new(seed, options)
end

---@param state table
---@param input table|nil
function M.step(state, input)
    Game.step(state, input)
end

---@param state table
---@return table frame
function M.frame(state)
    return Game.frame(state)
end

return M
