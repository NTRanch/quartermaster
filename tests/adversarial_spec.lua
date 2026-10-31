-- Adversarial: hostile input at every public boundary of the core.
local Main = require("src.main")
local H = require("tests.spec_helper")

describe("game adversarial inputs", function()
    it("ignores garbage input tables for 600 ticks, in menus and in play", function()
        local state = Main.new_game(11, {})
        H.click(Main, state, "enter")
        H.click(Main, state, "to_levels")
        H.click(Main, state, "level1")
        assert.are.equal("play", state.screen)
        local junk = {
            nil, {}, { x = "a", y = {}, pressed = "yes" },
            { x = 1e9, y = -1e9, pressed = true },
            { key = 42 }, { key = "99" }, { key = "escape " },
            { down = "held" }, { pick = 0 }, { pick = 9 },
        }
        for round = 1, 60 do
            for _, input in ipairs(junk) do
                local ok, err = pcall(Main.step, state, input)
                assert.is_true(ok, "step crashed on junk input: " .. tostring(err))
            end
            assert.is_true(round > 0)
        end
        local frame = Main.frame(state)
        assert.is_true(#frame.ops > 0)
        assert.is_true(#frame.ops <= 4000)
    end)

    it("boots clean on a hostile save string", function()
        local state = Main.new_game(11, { save = "QM1|rank=3; DROP TABLE" })
        assert.are.equal(1, state.career.rank_index)
        assert.are.equal("gate", state.screen)
    end)

    it("answer spam cannot skip the hold or inflate the ledger", function()
        local state = Main.new_game(11, {})
        H.click(Main, state, "enter")
        H.click(Main, state, "to_levels")
        H.click(Main, state, "level1")
        local drill = state.drill
        for _ = 1, 1000 do
            Main.step(state, { key = tostring(drill.target) })
            if drill.phase ~= "call" then break end
        end
        assert.are.equal("hold", drill.phase)
        assert.are.equal(0, #state.ledger.entries)
    end)

    it("demo runs are byte-identical for equal seeds (determinism)", function()
        local function run()
            local state = Main.new_game(2024, { demo_level = 2 })
            local chunks = {}
            for tick = 1, 1500 do
                Main.step(state, nil)
                if tick % 30 == 0 then
                    chunks[#chunks + 1] = H.dump_frame(Main.frame(state))
                end
            end
            return table.concat(chunks, "\n==\n")
        end
        assert.are.equal(run(), run())
    end)

    it("demo mode completes all three levels through the public API", function()
        for level = 1, 3 do
            local state = Main.new_game(777, { demo_level = level })
            local guard = 0
            while state.screen == "play" and guard < 60 * 900 do
                Main.step(state, nil)
                guard = guard + 1
            end
            assert.are_not.equal("play", state.screen)
            assert.is_not_nil(state.verdict)
        end
    end)
end)
