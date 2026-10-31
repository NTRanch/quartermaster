-- src/ceremony.lua — Quartermaster appraisal ceremony.
--
--- The ONLY place rank ever moves. The drill writes evidence; a separate
--- witness step at session end reads the session summary against the
--- gates in data.lua and applies at most one rank step. Applying a
--- ceremony consumes the session: the same evidence can never be
--- presented twice.

local Data = require("src.data")

local M = {}

--- Pure verdict: does this session earn a rank step from the given rank?
--- Kept side-effect free so the gate arithmetic is directly spec-testable.
---@param rank_index integer 1..#RANKS
---@param session table { ratio, faults, stopped, passed }
---@return boolean
function M.earns_step(rank_index, session)
    if type(session) ~= "table" then
        return false
    end
    if session.stopped == true or session.passed ~= true then
        return false
    end
    if rank_index >= #Data.RANKS then
        return false
    end
    local gate = Data.RANK_GATE_RATIO[rank_index]
    if gate == nil then
        return false
    end
    if type(session.ratio) ~= "number" or session.ratio < gate then
        return false
    end
    if type(session.faults) ~= "number" or session.faults > Data.RANK_FAULTS_MAX then
        return false
    end
    return true
end

--- Apply one finished session to the career record. Mutates the career
--- (rank, unlock, bests, ceremony count) and marks the session consumed.
--- A consumed or malformed session is rejected with nil + error.
---@param career QmCareer
---@param level_index integer
---@param session table drill session summary
---@return table|nil verdict { advanced, rank_from, rank_to, passed }
---@return string|nil
function M.apply(career, level_index, session)
    if type(career) ~= "table" or type(session) ~= "table" then
        return nil, "ceremony needs a career and a session"
    end
    if Data.LEVELS[level_index] == nil then
        return nil, "ceremony level out of range"
    end
    if session.consumed == true then
        return nil, "session already presented at a ceremony"
    end
    session.consumed = true
    career.ceremonies = career.ceremonies + 1
    local verdict = {
        advanced = false,
        rank_from = career.rank_index,
        rank_to = career.rank_index,
        passed = session.passed == true,
    }
    local pct = math.floor((session.ratio or 0) * 100 + 0.5)
    if pct > (career.best_pct[level_index] or 0) then
        career.best_pct[level_index] = pct
    end
    if session.passed == true then
        local next_level = level_index + 1
        if next_level <= Data.LEVEL_COUNT and next_level > career.unlocked_level then
            career.unlocked_level = next_level
        end
    end
    if M.earns_step(career.rank_index, session) then
        career.rank_index = career.rank_index + 1
        verdict.advanced = true
        verdict.rank_to = career.rank_index
    end
    return verdict
end

return M
