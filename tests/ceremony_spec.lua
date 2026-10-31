-- Ceremony: the only place rank moves. Gate arithmetic on its edges.
local Ceremony = require("src.ceremony")
local Save = require("src.save")

local function session(ratio, faults, extra)
    local base = { ratio = ratio, faults = faults, stopped = false,
        passed = true, consumed = false }
    if extra then
        for key, value in pairs(extra) do base[key] = value end
    end
    return base
end

describe("ceremony gate arithmetic", function()
    it("advances exactly at the gate ratio and fault cap", function()
        assert.is_true(Ceremony.earns_step(1, session(0.55, 3)))
        assert.is_true(Ceremony.earns_step(2, session(0.60, 0)))
        assert.is_true(Ceremony.earns_step(4, session(0.70, 3)))
    end)

    it("holds just below the gate, and above the fault cap", function()
        assert.is_false(Ceremony.earns_step(1, session(0.5499, 0)))
        assert.is_false(Ceremony.earns_step(1, session(0.99, 4)))
    end)

    it("never advances a stopped, failed, or max-rank session", function()
        assert.is_false(Ceremony.earns_step(1, session(1, 0, { stopped = true })))
        assert.is_false(Ceremony.earns_step(1, session(1, 0, { passed = false })))
        assert.is_false(Ceremony.earns_step(5, session(1, 0)))
    end)
end)

describe("ceremony application", function()
    it("moves rank once, unlocks the next level, records the best", function()
        local career = Save.default_career()
        local verdict = Ceremony.apply(career, 1, session(0.8, 1))
        assert.is_true(verdict.advanced)
        assert.are.equal(2, career.rank_index)
        assert.are.equal(2, career.unlocked_level)
        assert.are.equal(80, career.best_pct[1])
        assert.are.equal(1, career.ceremonies)
    end)

    it("consumes the session: the same evidence never moves rank twice", function()
        local career = Save.default_career()
        local evidence = session(0.95, 0)
        assert.is_not_nil(Ceremony.apply(career, 1, evidence))
        local again, err = Ceremony.apply(career, 1, evidence)
        assert.is_nil(again)
        assert.is_string(err)
        assert.are.equal(2, career.rank_index)
        assert.are.equal(1, career.ceremonies)
    end)

    it("a failed session still witnesses, unlocks nothing, moves nothing", function()
        local career = Save.default_career()
        local verdict = Ceremony.apply(career, 1,
            session(0.3, 2, { passed = false }))
        assert.is_false(verdict.advanced)
        assert.are.equal(1, career.rank_index)
        assert.are.equal(1, career.unlocked_level)
        assert.are.equal(1, career.ceremonies)
    end)
end)
