-- Ledger: validation of the append-only evidence invariants.
local Ledger = require("src.ledger")

local function entry(score, max, faults)
    return { kind = "call", label = "ATTEND", score = score,
        score_max = max, faults = faults or 0 }
end

describe("ledger validation", function()
    it("accumulates totals as entries land", function()
        local ledger = Ledger.new()
        assert.is_true(Ledger.append(ledger, entry(80, 100, 1)))
        assert.is_true(Ledger.append(ledger, entry(50, 100, 0)))
        assert.are.equal(130, ledger.total_score)
        assert.are.equal(200, ledger.total_max)
        assert.are.equal(1, ledger.total_faults)
        assert.are.equal(0.65, Ledger.ratio(ledger))
        assert.is_true(Ledger.audit(ledger))
    end)

    it("never retains the caller's table", function()
        local ledger = Ledger.new()
        local mine = entry(10, 100, 0)
        Ledger.append(ledger, mine)
        mine.score = 999
        assert.are.equal(10, ledger.total_score)
    end)

    it("scores an empty ledger 0, never NaN", function()
        assert.are.equal(0, Ledger.ratio(Ledger.new()))
    end)
end)

describe("ledger adversarial", function()
    it("rejects negative and over-max scores", function()
        local ledger = Ledger.new()
        assert.is_nil(Ledger.append(ledger, entry(-1, 100, 0)))
        assert.is_nil(Ledger.append(ledger, entry(0, Ledger.ENTRY_SCORE_MAX + 1, 0)))
        assert.is_nil(Ledger.append(ledger, entry(101, 100, 0)))
        assert.are.equal(0, #ledger.entries)
    end)

    it("rejects unknown kinds, bad labels, and non-tables", function()
        local ledger = Ledger.new()
        local bad = entry(1, 1, 0)
        bad.kind = "bribe"
        assert.is_nil(Ledger.append(ledger, bad))
        bad = entry(1, 1, 0)
        bad.label = string.rep("x", 65)
        assert.is_nil(Ledger.append(ledger, bad))
        assert.is_nil(Ledger.append(ledger, "not a table"))
        assert.is_nil(Ledger.append(ledger, nil))
        assert.are.equal(0, #ledger.entries)
    end)

    it("caps the ledger and still audits clean after the flood", function()
        local ledger = Ledger.new()
        for _ = 1, Ledger.ENTRIES_MAX do
            assert.is_true(Ledger.append(ledger, entry(1, 1, 0)))
        end
        local ok, err = Ledger.append(ledger, entry(1, 1, 0))
        assert.is_nil(ok)
        assert.are.equal("ledger is full", err)
        assert.is_true(Ledger.audit(ledger))
        assert.are.equal(Ledger.ENTRIES_MAX, ledger.total_score)
    end)
end)
