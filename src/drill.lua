-- src/drill.lua — Quartermaster drill state machine: call, hold, appraise,
-- with Protocol Recall woven in. Pure logic: the shell feeds input tables,
-- the game reads fields to draw. All timing is in fixed 1/60 s ticks.
--
--- Phases: call -> hold -> appraise -> (next call | recall_show ->
--- recall_answer -> appraise) -> done. Evidence for every call and recall
--- lands in the ledger; this module never touches rank (ceremony's job).

local Data = require("src.data")
local Rng = require("src.rng")
local Ledger = require("src.ledger")

local M = {}

M.APPRAISE_TICKS = 78
M.RECALL_SHOW_TICKS = 42
M.RECALL_GAP_TICKS = 12
M.RECALL_STEP_TICKS_MAX = 300
M.WRONG_PICKS_MAX = 3
local POISE_DRAIN_PER_TICK = 14 / 60
local POISE_REGEN_PER_TICK = 22 / 60
local BRACE_LOCK_TICKS = 45

---@class QmDrill
---@field phase string
---@field call_number integer
---@field target integer position index called
---@field sway number current effective sway in logical px (draw reads it)
---@field braced boolean
---@field poise number 0..100
---@field composure integer
---@field stopped boolean
---@field completed boolean true when every call was attempted
---@field failed boolean true when composure ran out
---@field result table|nil last appraisal, shown during appraise phase
---@field recall table|nil active recall round
---@field cues string[] sound cues emitted this step

--- Create a drill for a level. Level index is external input: (nil, err).
---@param level_index integer
---@param rng QmRng
---@param ledger QmLedger
---@param options table { assist = boolean }
---@return QmDrill|nil
---@return string|nil
function M.new(level_index, rng, ledger, options)
    if type(level_index) ~= "number" or level_index % 1 ~= 0
        or Data.LEVELS[level_index] == nil then
        return nil, "level index out of range"
    end
    assert(type(rng) == "table" and type(ledger) == "table", "drill needs rng + ledger")
    local level = Data.LEVELS[level_index]
    local drill = {
        level_index = level_index,
        level = level,
        preset = Data.PRESETS[level.preset],
        rng = rng,
        ledger = ledger,
        assist = options ~= nil and options.assist == true,
        phase = "call",
        ticks = 0,
        call_number = 0,
        target = 1,
        last_target = 0,
        wrong_count = 0,
        call_faults = 0,
        reaction_ticks = 0,
        hold_elapsed = 0,
        sway = 0,
        sway_phase_a = 0,
        sway_phase_b = 0,
        steadiness_sum = 0,
        steadiness_samples = 0,
        sway_fault = false,
        braced = false,
        poise = 100,
        brace_lock_ticks = 0,
        composure = Data.COMPOSURE_START,
        stopped = false,
        completed = false,
        failed = false,
        result = nil,
        recall = nil,
        cues = {},
    }
    M.begin_call(drill)
    return drill
end

--- Sway tolerance for this drill (assist widens it; accessibility option).
---@param drill QmDrill
---@return number
function M.sway_max(drill)
    if drill.assist then
        return drill.preset.sway_max * 1.5
    end
    return drill.preset.sway_max
end

--- Pick the next target: seeded, never an immediate repeat.
---@param drill QmDrill
function M.begin_call(drill)
    drill.call_number = drill.call_number + 1
    local target = Rng.next_range(drill.rng, Data.POSITION_COUNT)
    local attempts = 0
    while target == drill.last_target and attempts < 3 do
        target = Rng.next_range(drill.rng, Data.POSITION_COUNT)
        attempts = attempts + 1
    end
    if target == drill.last_target then
        target = drill.last_target % Data.POSITION_COUNT + 1
    end
    drill.target = target
    drill.last_target = target
    drill.phase = "call"
    drill.ticks = 0
    drill.wrong_count = 0
    drill.call_faults = 0
    drill.cues[#drill.cues + 1] = "call"
end

local function grade_for(score, score_max)
    if score_max == 0 then
        return "F"
    end
    local pct = score / score_max
    if pct >= 0.9 then return "S" end
    if pct >= 0.75 then return "A" end
    if pct >= 0.6 then return "B" end
    if pct >= 0.4 then return "C" end
    return "F"
end

--- End the current call with a zero entry (timeout or repeated faults).
---@param drill QmDrill
---@param why string label suffix recorded in the ledger
local function fail_call(drill, why)
    Ledger.append(drill.ledger, {
        kind = "call", label = Data.POSITIONS[drill.target].id .. " " .. why,
        score = 0, score_max = math.floor(100 * drill.preset.multiplier + 0.5),
        faults = drill.call_faults,
    })
    drill.composure = drill.composure - 1
    drill.result = { label = Data.POSITIONS[drill.target].id, score = 0,
        score_max = math.floor(100 * drill.preset.multiplier + 0.5), grade = "F",
        detail = why }
    drill.cues[#drill.cues + 1] = "bad"
    drill.phase = "appraise"
    drill.ticks = 0
end

--- Score a finished hold and log the evidence.
---@param drill QmDrill
local function appraise_hold(drill)
    local multiplier = drill.preset.multiplier
    local reaction_pts = 50 * math.max(0,
        1 - drill.reaction_ticks / drill.level.answer_ticks)
    local steadiness_pts = 0
    if drill.steadiness_samples > 0 then
        steadiness_pts = 50 * (drill.steadiness_sum / drill.steadiness_samples)
    end
    local score_max = math.floor(Data.SCORE_CALL_MAX * multiplier + 0.5)
    local score = math.floor((reaction_pts + steadiness_pts) * multiplier + 0.5)
    if score > score_max then score = score_max end
    if score < 0 then score = 0 end
    Ledger.append(drill.ledger, {
        kind = "call", label = Data.POSITIONS[drill.target].id,
        score = score, score_max = score_max, faults = drill.call_faults,
    })
    drill.result = { label = Data.POSITIONS[drill.target].id, score = score,
        score_max = score_max, grade = grade_for(score, score_max),
        detail = "APPRAISED" }
    drill.cues[#drill.cues + 1] = "appraise"
    drill.phase = "appraise"
    drill.ticks = 0
end

--- Build a recall round of the given length (seeded, no adjacent repeats).
---@param drill QmDrill
---@param length integer
local function begin_recall(drill, length)
    local seq = {}
    local previous = 0
    for index = 1, length do
        local pick = Rng.next_range(drill.rng, Data.POSITION_COUNT)
        if pick == previous then
            pick = pick % Data.POSITION_COUNT + 1
        end
        seq[index] = pick
        previous = pick
    end
    drill.recall = { seq = seq, show_index = 1, answer_index = 1, hits = 0 }
    drill.phase = "recall_show"
    drill.ticks = 0
    drill.cues[#drill.cues + 1] = "recall"
end

--- Close a recall round into the ledger and move to its appraisal.
---@param drill QmDrill
local function finish_recall(drill)
    local recall = drill.recall
    local multiplier = drill.preset.multiplier
    local score = math.floor(recall.hits * Data.SCORE_RECALL_STEP * multiplier + 0.5)
    local score_max = math.floor(#recall.seq * Data.SCORE_RECALL_STEP * multiplier + 0.5)
    Ledger.append(drill.ledger, {
        kind = "recall", label = "PROTOCOL RECALL",
        score = score, score_max = score_max, faults = drill.call_faults,
    })
    drill.result = { label = "PROTOCOL RECALL", score = score,
        score_max = score_max, grade = grade_for(score, score_max),
        detail = "RECALLED " .. recall.hits .. " OF " .. #recall.seq }
    drill.recall = nil
    drill.cues[#drill.cues + 1] = "appraise"
    drill.phase = "appraise"
    drill.ticks = 0
end

--- Advance after an appraisal: recall if scheduled, else next/done.
---@param drill QmDrill
local function advance(drill)
    if drill.composure <= 0 then
        drill.failed = true
        drill.phase = "done"
        return
    end
    if drill.phase_after_appraise == "recall" then
        drill.phase_after_appraise = nil
        begin_recall(drill, drill.pending_recall_length)
        drill.pending_recall_length = nil
        return
    end
    if drill.call_number >= drill.level.calls then
        drill.completed = true
        drill.phase = "done"
        drill.cues[#drill.cues + 1] = "done"
        return
    end
    M.begin_call(drill)
end

--- Schedule what follows the current appraisal (call or recall bookkeeping).
---@param drill QmDrill
local function plan_after_appraise(drill)
    local recall_length = drill.level.recall_after[drill.call_number]
    if recall_length ~= nil and drill.composure > 0 then
        drill.phase_after_appraise = "recall"
        drill.pending_recall_length = recall_length
    end
end

local function step_call(drill, input)
    drill.ticks = drill.ticks + 1
    if input.pick ~= nil then
        if input.pick == drill.target then
            drill.reaction_ticks = drill.ticks
            drill.phase = "hold"
            drill.ticks = 0
            drill.hold_elapsed = 0
            drill.steadiness_sum = 0
            drill.steadiness_samples = 0
            drill.sway_fault = false
            drill.sway_phase_a = Rng.range_float(drill.rng, 0, 6.28318)
            drill.sway_phase_b = Rng.range_float(drill.rng, 0, 6.28318)
            drill.cues[#drill.cues + 1] = "good"
            return
        end
        drill.wrong_count = drill.wrong_count + 1
        drill.call_faults = drill.call_faults + 1
        drill.cues[#drill.cues + 1] = "bad"
        if drill.wrong_count >= M.WRONG_PICKS_MAX then
            fail_call(drill, "MISCALLED")
            plan_after_appraise(drill)
            return
        end
    end
    if drill.ticks > drill.level.answer_ticks then
        drill.call_faults = drill.call_faults + 1
        fail_call(drill, "NO ANSWER")
        plan_after_appraise(drill)
    end
end

local function step_hold(drill, input)
    drill.ticks = drill.ticks + 1
    drill.hold_elapsed = drill.hold_elapsed + 1
    local want_brace = input.down == true and drill.brace_lock_ticks == 0
    drill.braced = want_brace
    if drill.brace_lock_ticks > 0 then
        drill.brace_lock_ticks = drill.brace_lock_ticks - 1
    end
    if want_brace then
        drill.poise = drill.poise - POISE_DRAIN_PER_TICK
        if drill.poise <= 0 then
            drill.poise = 0
            drill.brace_lock_ticks = BRACE_LOCK_TICKS
        end
    else
        drill.poise = math.min(100, drill.poise + POISE_REGEN_PER_TICK)
    end
    local progress = drill.hold_elapsed / drill.level.hold_ticks
    local amplitude = 9 + 16 * progress
    local raw = amplitude * (0.7 * math.sin(0.11 * drill.hold_elapsed + drill.sway_phase_a)
        + 0.3 * math.sin(0.043 * drill.hold_elapsed + drill.sway_phase_b))
    local effective = raw
    if drill.braced then
        effective = raw * 0.3
    end
    drill.sway = effective
    local tolerance = M.sway_max(drill)
    local quality = 1 - math.min(math.abs(effective) / tolerance, 1)
    drill.steadiness_sum = drill.steadiness_sum + quality
    drill.steadiness_samples = drill.steadiness_samples + 1
    if not drill.braced and math.abs(raw) > tolerance and not drill.sway_fault then
        drill.sway_fault = true
        drill.call_faults = drill.call_faults + 1
        drill.cues[#drill.cues + 1] = "bad"
    end
    if drill.hold_elapsed >= drill.level.hold_ticks then
        appraise_hold(drill)
        plan_after_appraise(drill)
    end
end

local function step_recall_show(drill)
    drill.ticks = drill.ticks + 1
    local span = M.RECALL_SHOW_TICKS + M.RECALL_GAP_TICKS
    local index = math.floor(drill.ticks / span) + 1
    if index > #drill.recall.seq then
        drill.phase = "recall_answer"
        drill.ticks = 0
        drill.recall_step_ticks = 0
        drill.cues[#drill.cues + 1] = "call"
    else
        drill.recall.show_index = index
    end
end

local function step_recall_answer(drill, input)
    drill.ticks = drill.ticks + 1
    drill.recall_step_ticks = drill.recall_step_ticks + 1
    local recall = drill.recall
    if input.pick ~= nil then
        if input.pick == recall.seq[recall.answer_index] then
            recall.hits = recall.hits + 1
            recall.answer_index = recall.answer_index + 1
            drill.recall_step_ticks = 0
            drill.cues[#drill.cues + 1] = "good"
            if recall.answer_index > #recall.seq then
                finish_recall(drill)
            end
            return
        end
        drill.call_faults = drill.call_faults + 1
        drill.cues[#drill.cues + 1] = "bad"
        finish_recall(drill)
        return
    end
    if drill.recall_step_ticks > M.RECALL_STEP_TICKS_MAX then
        drill.call_faults = drill.call_faults + 1
        finish_recall(drill)
    end
end

--- One fixed step. Input is external: every field is type-checked, junk
--- is ignored, and a nil input means "no input this tick".
---@param drill QmDrill
---@param input table|nil { pick = integer|nil, down = boolean, stop = boolean }
function M.step(drill, input)
    drill.cues = {}
    if drill.phase == "done" then
        return
    end
    local clean = {}
    if type(input) == "table" then
        if type(input.pick) == "number" and input.pick % 1 == 0
            and Data.position(input.pick) ~= nil then
            clean.pick = input.pick
        end
        clean.down = input.down == true
        clean.stop = input.stop == true
    end
    if clean.stop then
        Ledger.append(drill.ledger, {
            kind = "note", label = "STOPPED BY PARTICIPANT",
            score = 0, score_max = 0, faults = 0,
        })
        drill.stopped = true
        drill.phase = "done"
        drill.cues[#drill.cues + 1] = "done"
        return
    end
    if drill.phase == "call" then
        step_call(drill, clean)
    elseif drill.phase == "hold" then
        step_hold(drill, clean)
    elseif drill.phase == "appraise" then
        drill.ticks = drill.ticks + 1
        if drill.ticks >= M.APPRAISE_TICKS then
            advance(drill)
        end
    elseif drill.phase == "recall_show" then
        step_recall_show(drill)
    elseif drill.phase == "recall_answer" then
        step_recall_answer(drill, clean)
    end
end

--- Session summary for the ceremony. Valid any time; complete at done.
---@param drill QmDrill
---@return table
function M.session(drill)
    local ledger = drill.ledger
    Ledger.audit(ledger)
    return {
        score = ledger.total_score,
        score_max = ledger.total_max,
        faults = ledger.total_faults,
        ratio = Ledger.ratio(ledger),
        passed = drill.completed and not drill.failed
            and Ledger.ratio(ledger) >= drill.level.pass_ratio
            and ledger.total_faults <= drill.level.pass_faults_max,
        stopped = drill.stopped,
        completed = drill.completed,
        failed = drill.failed,
        consumed = false,
    }
end

return M
