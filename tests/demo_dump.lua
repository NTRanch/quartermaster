-- tests/demo_dump.lua — canonical frame dump for the cross-VM conformance
-- gate. Usage: lua tests/demo_dump.lua <level> <seed> <ticks>
-- Prints the sampled draw lists; tools/conformance.mjs diffs the PUC run
-- against the shipped Fengari artifact's run of the same script.

package.path = "./?.lua;" .. package.path

local Main = require("src.main")
local H = require("tests.spec_helper")

local level = tonumber(arg[1]) or 1
local seed = tonumber(arg[2]) or 42
local ticks = tonumber(arg[3]) or 720

local state = Main.new_game(seed, { demo_level = level })
for tick = 1, ticks do
    Main.step(state, nil)
    if tick % 6 == 0 then
        print(H.dump_frame(Main.frame(state)))
        print("==")
    end
end
