-- src/demo.lua — Quartermaster scripted demo policy.
--
--- Demo mode (?demo=<level>&seed=<n>) plays the drill with no human: the
--- policy reads the drill's public fields and answers like a drilled,
--- slightly imperfect participant — fixed reaction delays from its own
--- seeded stream, bracing when sway grows, recall answered from memory of
--- the shown sequence. Deterministic: same seed -> identical inputs ->
--- identical draw lists (the conformance gate diffs two VMs on this).

local Rng = require("src.rng")

local M = {}

local REACTION_TICKS_MIN = 18
local REACTION_TICKS_SPAN = 30
local RECALL_TICKS = 15

---@class QmDemo
---@field rng QmRng policy-private stream (delays only)
---@field call_seen integer call_number the current delay belongs to
---@field delay_ticks integer ticks to wait before answering this call
---@field recall_step_seen integer answer_index the delay belongs to

---@param rng QmRng
---@return QmDemo
function M.new(rng)
    assert(type(rng) == "table", "demo needs an rng")
    return { rng = rng, call_seen = -1, delay_ticks = 0, recall_step_seen = -1 }
end

--- Produce this tick's input for the drill. Pure function of drill state
--- plus the policy stream; never mutates the drill.
---@param demo QmDemo
---@param drill QmDrill
---@return table input { pick, down, stop }
function M.input(demo, drill)
    local input = { down = false }
    if drill.phase == "call" then
        if demo.call_seen ~= drill.call_number then
            demo.call_seen = drill.call_number
            demo.delay_ticks = REACTION_TICKS_MIN
                + Rng.next_range(demo.rng, REACTION_TICKS_SPAN)
        end
        if drill.ticks >= demo.delay_ticks then
            input.pick = drill.target
        end
    elseif drill.phase == "hold" then
        -- Brace when sway threatens tolerance and poise allows; rest to
        -- recover otherwise. Mirrors the taught technique.
        local tolerance = drill.preset.sway_max
        if math.abs(drill.sway) > tolerance * 0.45 and drill.poise > 30 then
            input.down = true
        elseif drill.poise < 55 and math.abs(drill.sway) < tolerance * 0.8 then
            input.down = false
        else
            input.down = drill.poise > 70
        end
    elseif drill.phase == "recall_answer" and drill.recall ~= nil then
        if demo.recall_step_seen ~= drill.recall.answer_index then
            demo.recall_step_seen = drill.recall.answer_index
            demo.step_start = drill.ticks
        end
        if drill.ticks - (demo.step_start or 0) >= RECALL_TICKS then
            input.pick = drill.recall.seq[drill.recall.answer_index]
        end
    end
    return input
end

return M
