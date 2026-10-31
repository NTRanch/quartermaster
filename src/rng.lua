-- src/rng.lua — Quartermaster seeded RNG (Park-Miller minimal standard).
--
--- Contract: deterministic across PUC Lua 5.4 (integer arithmetic) and
--- Fengari 5.3 (double arithmetic). The multiplier keeps every product
--- below 2^53, so both number models produce the identical sequence.
--- External input is validated with (nil, err); internal misuse asserts.

local M = {}

local MODULUS = 2147483647 -- 2^31 - 1
local MULTIPLIER = 48271
-- Schrage decomposition of MODULUS by MULTIPLIER: keeps every intermediate
-- below 2^31, so the step is exact in both number models. A direct
-- (state * MULTIPLIER) % MODULUS is NOT portable: Fengari's float modulo
-- loses the quotient on large operands (measured: off by the quotient
-- itself at the second step from seed 2303).
local SCHRAGE_Q = 44488 -- MODULUS // MULTIPLIER
local SCHRAGE_R = 3399 -- MODULUS % MULTIPLIER (must stay < SCHRAGE_Q)
local RANGE_MAX = 1000000

---@class QmRng
---@field state integer Park-Miller state, always 1..MODULUS-1

--- Create a generator. Any finite number seed folds into 1..MODULUS-1.
---@param seed number
---@return QmRng
function M.new(seed)
    assert(type(seed) == "number", "rng seed must be a number")
    assert(seed == seed and seed ~= math.huge and seed ~= -math.huge,
        "rng seed must be finite")
    local state = math.floor(math.abs(seed)) % MODULUS
    if state == 0 then
        state = 1
    end
    return { state = state }
end

--- Advance once and return the raw state (1..MODULUS-1).
---@param rng QmRng
---@return integer
function M.next_int(rng)
    local state = rng.state
    local hi = math.floor(state / SCHRAGE_Q)
    local lo = state - hi * SCHRAGE_Q
    local test = MULTIPLIER * lo - SCHRAGE_R * hi
    if test < 0 then
        test = test + MODULUS
    end
    rng.state = test
    return rng.state
end

--- Float in [0, 1). Division is IEEE double in both VMs, so values agree.
---@param rng QmRng
---@return number
function M.next_float(rng)
    return (M.next_int(rng) - 1) / (MODULUS - 1)
end

--- Integer in 1..count. count is programmer input: assert, never clamp.
---@param rng QmRng
---@param count integer
---@return integer
function M.next_range(rng, count)
    assert(type(count) == "number" and count % 1 == 0, "count must be an integer")
    assert(count >= 1 and count <= RANGE_MAX, "count out of bounds")
    return (M.next_int(rng) % count) + 1
end

--- Float in [low, high).
---@param rng QmRng
---@param low number
---@param high number
---@return number
function M.range_float(rng, low, high)
    assert(type(low) == "number" and type(high) == "number", "bounds must be numbers")
    assert(high > low, "high must exceed low")
    return low + (high - low) * M.next_float(rng)
end

--- In-place Fisher-Yates shuffle of the array part of list (bounded by #list).
---@param rng QmRng
---@param list table
function M.shuffle(rng, list)
    assert(type(list) == "table", "list must be a table")
    for index = #list, 2, -1 do
        local swap = M.next_range(rng, index)
        list[index], list[swap] = list[swap], list[index]
    end
end

return M
