-- Save record: round-trips (validation) and hostile strings (adversarial).
local Save = require("src.save")

describe("save validation", function()
    it("round-trips a full career byte-identically", function()
        local career = Save.default_career()
        career.rank_index = 4
        career.unlocked_level = 3
        career.ceremonies = 17
        career.best_pct = { [1] = 88, [2] = 71, [3] = 64 }
        career.volume = 30
        career.preset = "severe"
        career.assist = true
        local text = Save.serialize(career)
        local back, err = Save.deserialize(text)
        assert.is_nil(err)
        assert.are.same(career, back)
        assert.are.equal(text, Save.serialize(back))
    end)

    it("loads a bare header as defaults (partial record)", function()
        local career, err = Save.deserialize("QM1")
        assert.is_nil(err)
        assert.are.same(Save.default_career(), career)
    end)

    it("serializes deterministically", function()
        local career = Save.default_career()
        assert.are.equal(Save.serialize(career), Save.serialize(career))
    end)
end)

describe("save adversarial", function()
    local function rejected(text)
        local career, err = Save.deserialize(text)
        assert.is_nil(career)
        assert.is_string(err)
    end

    it("rejects empty, foreign, and oversized strings", function()
        rejected("")
        rejected("hello world")
        rejected("QM2|rank=1")
        rejected("QM1|" .. string.rep("a", Save.SAVE_BYTES_MAX))
        rejected(42)
        rejected(nil)
    end)

    it("rejects duplicated and unknown fields", function()
        rejected("QM1|rank=1|rank=2")
        rejected("QM1|admin=1")
        rejected("QM1|rank")
        rejected("QM1|=3")
    end)

    it("rejects out-of-range and non-integer values", function()
        rejected("QM1|rank=0")
        rejected("QM1|rank=99")
        rejected("QM1|vol=-5")
        rejected("QM1|vol=101")
        rejected("QM1|vol=7.5")
        rejected("QM1|assist=2")
        rejected("QM1|b9=10")
        rejected("QM1|preset=brutal")
        rejected("QM1|ceremonies=99999999999999999999")
    end)

    it("survives a seeded fuzz storm without crashing", function()
        local Rng = require("src.rng")
        local rng = Rng.new(1234)
        local alphabet = "QM1|=rankvolsbacerhp0123456789|"
        for case = 1, 200 do
            local len = Rng.next_range(rng, 40)
            local buf = {}
            for index = 1, len do
                local pick = Rng.next_range(rng, #alphabet)
                buf[index] = alphabet:sub(pick, pick)
            end
            local career = Save.deserialize(table.concat(buf))
            if career ~= nil then
                -- A fuzz string that parses must re-serialize and re-parse.
                local again = Save.deserialize(Save.serialize(career))
                assert.is_not_nil(again)
            end
            assert.is_true(case > 0)
        end
    end)
end)
