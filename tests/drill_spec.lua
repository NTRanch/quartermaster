-- Drill state machine: scripted play (validation) and scoring edges.
local Data = require("src.data")
local Demo = require("src.demo")
local Drill = require("src.drill")
local Ledger = require("src.ledger")
local Rng = require("src.rng")

local function play_with_demo(level_index, seed)
    local ledger = Ledger.new()
    local drill = Drill.new(level_index, Rng.new(seed), ledger, {})
    local demo = Demo.new(Rng.new(seed + 999331))
    local guard = 0
    while drill.phase ~= "done" and guard < 60 * 600 do
        Drill.step(drill, Demo.input(demo, drill))
        guard = guard + 1
    end
    return drill, ledger, guard
end

describe("drill validation", function()
    it("rejects a bad level index as external input", function()
        local drill, err = Drill.new(99, Rng.new(1), Ledger.new(), {})
        assert.is_nil(drill)
        assert.is_string(err)
        local drill2 = Drill.new(0, Rng.new(1), Ledger.new(), {})
        assert.is_nil(drill2)
    end)

    it("demo play completes every level and files evidence for each call", function()
        for level = 1, Data.LEVEL_COUNT do
            local drill, ledger = play_with_demo(level, 1000 + level)
            assert.are.equal("done", drill.phase)
            assert.is_true(drill.completed)
            local calls = 0
            for _, e in ipairs(ledger.entries) do
                if e.kind == "call" then calls = calls + 1 end
            end
            assert.are.equal(Data.LEVELS[level].calls, calls)
            assert.is_true(Ledger.audit(ledger))
        end
    end)

    it("weaves Protocol Recall into levels 2 and 3 with full step credit", function()
        for level = 2, 3 do
            local _, ledger = play_with_demo(level, 55 + level)
            local recalls = 0
            for _, e in ipairs(ledger.entries) do
                if e.kind == "recall" then
                    recalls = recalls + 1
                    -- The demo answers recall perfectly: full marks.
                    assert.are.equal(e.score_max, e.score)
                end
            end
            assert.are.equal(level - 1, recalls)
        end
    end)

    it("passes level 1 under demo play (the teach gate is fair)", function()
        local drill = play_with_demo(1, 4242)
        local session = Drill.session(drill)
        assert.is_true(session.passed)
        assert.is_true(session.ratio >= Data.LEVELS[1].pass_ratio)
    end)
end)

describe("drill scoring edges", function()
    local function hold_out(level_index, brace)
        local ledger = Ledger.new()
        local drill = Drill.new(level_index, Rng.new(31), ledger, {})
        Drill.step(drill, { pick = drill.target }) -- instant, correct answer
        local guard = 0
        while drill.phase == "hold" and guard < 60 * 30 do
            Drill.step(drill, { down = brace })
            guard = guard + 1
        end
        return ledger
    end

    it("bracing out-scores never bracing on the severe brush", function()
        local braced = hold_out(3, true)
        local loose = hold_out(3, false)
        assert.is_true(braced.total_score > loose.total_score)
    end)

    it("a timeout files a zero entry and costs composure", function()
        local ledger = Ledger.new()
        local drill = Drill.new(1, Rng.new(3), ledger, {})
        local guard = 0
        while drill.phase == "call" and guard < 60 * 30 do
            Drill.step(drill, {})
            guard = guard + 1
        end
        assert.are.equal(Data.COMPOSURE_START - 1, drill.composure)
        assert.are.equal(0, ledger.entries[1].score)
    end)

    it("three wrong picks fail the call; two do not", function()
        local ledger = Ledger.new()
        local drill = Drill.new(1, Rng.new(3), ledger, {})
        local wrong = drill.target % Data.POSITION_COUNT + 1
        Drill.step(drill, { pick = wrong })
        Drill.step(drill, { pick = wrong })
        assert.are.equal("call", drill.phase)
        Drill.step(drill, { pick = wrong })
        assert.are.equal("appraise", drill.phase)
        assert.are.equal(0, ledger.entries[1].score)
    end)

    it("stop ends the session at once, witnessed, no composure cost", function()
        local ledger = Ledger.new()
        local drill = Drill.new(2, Rng.new(3), ledger, {})
        Drill.step(drill, { stop = true })
        assert.are.equal("done", drill.phase)
        assert.is_true(drill.stopped)
        assert.are.equal(Data.COMPOSURE_START, drill.composure)
        assert.are.equal("note", ledger.entries[#ledger.entries].kind)
        local session = Drill.session(drill)
        assert.is_false(session.passed)
    end)

    it("repeated composure loss ends the drill as failed", function()
        local ledger = Ledger.new()
        local drill = Drill.new(1, Rng.new(3), ledger, {})
        local guard = 0
        while drill.phase ~= "done" and guard < 60 * 300 do
            Drill.step(drill, {}) -- never answer anything
            guard = guard + 1
        end
        assert.is_true(drill.failed)
        assert.is_false(Drill.session(drill).passed)
    end)
end)
