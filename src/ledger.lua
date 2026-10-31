-- src/ledger.lua — Quartermaster appraisal evidence ledger.
--
--- Append-only: entries are never edited or removed after the fact, which
--- is what makes the ceremony's witness line honest. Totals are kept
--- incrementally and can be re-derived at any time by audit(); the spec
--- suite calls audit() after hostile input to prove they never drift.

local M = {}

M.ENTRIES_MAX = 512
M.ENTRY_SCORE_MAX = 1000
M.KINDS = { call = true, recall = true, note = true }

---@class QmLedgerEntry
---@field seq integer 1-based append order
---@field kind string one of M.KINDS
---@field label string short human label (bounded length)
---@field score integer points awarded, 0..ENTRY_SCORE_MAX
---@field score_max integer points available, 0..ENTRY_SCORE_MAX
---@field faults integer faults inside this entry, 0..99

---@class QmLedger
---@field entries QmLedgerEntry[]
---@field total_score integer
---@field total_max integer
---@field total_faults integer

---@return QmLedger
function M.new()
    return { entries = {}, total_score = 0, total_max = 0, total_faults = 0 }
end

local function is_integer(value)
    return type(value) == "number" and value % 1 == 0
end

--- Validate one candidate entry (external input: return nil, err).
---@param entry table
---@return QmLedgerEntry|nil
---@return string|nil
local function validate_entry(entry)
    if type(entry) ~= "table" then
        return nil, "entry must be a table"
    end
    if not M.KINDS[entry.kind] then
        return nil, "entry kind not recognised"
    end
    if type(entry.label) ~= "string" or #entry.label == 0 or #entry.label > 64 then
        return nil, "entry label must be 1..64 chars"
    end
    if not is_integer(entry.score) or entry.score < 0 or entry.score > M.ENTRY_SCORE_MAX then
        return nil, "entry score out of range"
    end
    if not is_integer(entry.score_max) or entry.score_max < 0
        or entry.score_max > M.ENTRY_SCORE_MAX then
        return nil, "entry score_max out of range"
    end
    if entry.score > entry.score_max then
        return nil, "entry score exceeds its maximum"
    end
    if not is_integer(entry.faults) or entry.faults < 0 or entry.faults > 99 then
        return nil, "entry faults out of range"
    end
    return {
        kind = entry.kind, label = entry.label, score = entry.score,
        score_max = entry.score_max, faults = entry.faults,
    }
end

--- Append one entry. The ledger owns the stored copy; the caller's table
--- is never retained. Returns true, or nil + error when full/invalid.
---@param ledger QmLedger
---@param entry table
---@return boolean|nil
---@return string|nil
function M.append(ledger, entry)
    assert(type(ledger) == "table" and type(ledger.entries) == "table",
        "ledger invariant: entries table missing")
    if #ledger.entries >= M.ENTRIES_MAX then
        return nil, "ledger is full"
    end
    local clean, err = validate_entry(entry)
    if clean == nil then
        return nil, err
    end
    clean.seq = #ledger.entries + 1
    ledger.entries[#ledger.entries + 1] = clean
    ledger.total_score = ledger.total_score + clean.score
    ledger.total_max = ledger.total_max + clean.score_max
    ledger.total_faults = ledger.total_faults + clean.faults
    return true
end

--- Re-derive every total from the entries and compare. This is the
--- invariant check: any drift between stored totals and the entries is a
--- programmer error (assert), a clean ledger returns true.
---@param ledger QmLedger
---@return boolean
function M.audit(ledger)
    local score, max, faults = 0, 0, 0
    for index, entry in ipairs(ledger.entries) do
        assert(entry.seq == index, "ledger invariant: sequence gap")
        score = score + entry.score
        max = max + entry.score_max
        faults = faults + entry.faults
    end
    assert(score == ledger.total_score, "ledger invariant: score drift")
    assert(max == ledger.total_max, "ledger invariant: max drift")
    assert(faults == ledger.total_faults, "ledger invariant: fault drift")
    return true
end

--- Session ratio in [0, 1]; an empty ledger scores 0, never NaN.
---@param ledger QmLedger
---@return number
function M.ratio(ledger)
    if ledger.total_max == 0 then
        return 0
    end
    return ledger.total_score / ledger.total_max
end

return M
