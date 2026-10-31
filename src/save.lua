-- src/save.lua — Quartermaster career record: serialize / deserialize.
--
--- The record is data-only by discipline (rank, unlocks, bests, settings),
--- so the format is a flat, bounded "QM1|k=v|k=v" string the shell can keep
--- in localStorage. Deserialization is a strict hand parser — never load()
--- — with a key whitelist and ranged integers: malformed or hostile save
--- strings return nil + error, they never crash and never partially apply.

local Data = require("src.data")

local M = {}

M.SAVE_BYTES_MAX = 1024
M.CEREMONIES_MAX = 100000

---@class QmCareer
---@field rank_index integer 1..#RANKS (1 = lowest)
---@field unlocked_level integer 1..LEVEL_COUNT
---@field ceremonies integer completed ceremonies, 0..CEREMONIES_MAX
---@field best_pct table<integer, integer> best ratio percent per level, 0..100
---@field volume integer 0..100
---@field preset string default stiffness preset key
---@field assist boolean sway-assist accessibility option (never gated)

---@return QmCareer
function M.default_career()
    return {
        rank_index = 1,
        unlocked_level = 1,
        ceremonies = 0,
        best_pct = {},
        volume = 70,
        preset = "soft",
        assist = false,
    }
end

--- Serialize deterministically: fixed key order, integers only.
---@param career QmCareer
---@return string
function M.serialize(career)
    assert(type(career) == "table", "career must be a table")
    local parts = {
        "QM1",
        "rank=" .. career.rank_index,
        "unlocked=" .. career.unlocked_level,
        "ceremonies=" .. career.ceremonies,
    }
    for level = 1, Data.LEVEL_COUNT do
        parts[#parts + 1] = "b" .. level .. "=" .. (career.best_pct[level] or 0)
    end
    parts[#parts + 1] = "vol=" .. career.volume
    parts[#parts + 1] = "preset=" .. career.preset
    parts[#parts + 1] = "assist=" .. (career.assist and "1" or "0")
    return table.concat(parts, "|")
end

local function parse_integer(raw, low, high)
    if type(raw) ~= "string" or not raw:match("^%d+$") then
        return nil
    end
    local value = tonumber(raw)
    if value == nil or value < low or value > high then
        return nil
    end
    return value
end

local FIELD_RANGES = {
    rank = { 1, #Data.RANKS },
    unlocked = { 1, Data.LEVEL_COUNT },
    ceremonies = { 0, M.CEREMONIES_MAX },
    vol = { 0, 100 },
    assist = { 0, 1 },
}

--- Deserialize. Missing keys fall back to defaults (a partial record from
--- an older build still loads); unknown, duplicated, or out-of-range
--- fields reject the whole string.
---@param text string
---@return QmCareer|nil
---@return string|nil
function M.deserialize(text)
    if type(text) ~= "string" then
        return nil, "save must be a string"
    end
    if #text > M.SAVE_BYTES_MAX then
        return nil, "save exceeds size bound"
    end
    local fields = {}
    for chunk in (text .. "|"):gmatch("(.-)|") do
        fields[#fields + 1] = chunk
    end
    if fields[1] ~= "QM1" then
        return nil, "save header not recognised"
    end
    local career = M.default_career()
    local seen = {}
    for index = 2, #fields do
        local key, raw = fields[index]:match("^([a-z0-9]+)=(.*)$")
        if key == nil then
            return nil, "save field malformed"
        end
        if seen[key] then
            return nil, "save field duplicated"
        end
        seen[key] = true
        local best_level = key:match("^b(%d)$")
        if best_level ~= nil then
            local level = tonumber(best_level)
            if level < 1 or level > Data.LEVEL_COUNT then
                return nil, "save best level out of range"
            end
            local value = parse_integer(raw, 0, 100)
            if value == nil then
                return nil, "save best value out of range"
            end
            career.best_pct[level] = value
        elseif key == "preset" then
            if Data.PRESETS[raw] == nil then
                return nil, "save preset not recognised"
            end
            career.preset = raw
        elseif FIELD_RANGES[key] ~= nil then
            local range = FIELD_RANGES[key]
            local value = parse_integer(raw, range[1], range[2])
            if value == nil then
                return nil, "save field out of range: " .. key
            end
            if key == "rank" then
                career.rank_index = value
            elseif key == "unlocked" then
                career.unlocked_level = value
            elseif key == "ceremonies" then
                career.ceremonies = value
            elseif key == "vol" then
                career.volume = value
            elseif key == "assist" then
                career.assist = (value == 1)
            end
        else
            return nil, "save field not recognised: " .. key
        end
    end
    return career
end

return M
