-- src/data.lua — Quartermaster canon data: positions, poses, presets,
-- levels, ranks. Pure tables; no logic beyond lookup helpers.
--
--- Legibility is a jam feature: the drill protocol IS this table, and it
--- ships readable in the single file.

local M = {}

-- Palette indices are 0-based inside draw ops (the shell/rasteriser index
-- the palette array from 0). Position i of this list is colour index i-1.
M.PALETTE = {
    "#0d0208", -- 0 ground
    "#1c0a18", -- 1 panel
    "#f7e8f1", -- 2 ink
    "#ff2e88", -- 3 hot pink
    "#a11856", -- 4 pink dim
    "#ffb347", -- 5 gold
    "#4be38a", -- 6 good
    "#ff4b4b", -- 7 bad
    "#8a6d80", -- 8 muted
    "#e8b4a0", -- 9 skin tone (figure)
    "#5a4678", -- 10 cloth (figure)
    "#cfd4dc", -- 11 silver
    "#07010a", -- 12 deep
    "#ffd7ec", -- 13 brush highlight
    "#ffe14b", -- 14 warning
    "#472238", -- 15 rule line
}

-- A pose is a point set in a 240x300 cell (x right, y down). Points:
-- head (centre), neck, hip, shl/shr shoulders, ell/elr elbows,
-- hal/har hands, knl/knr knees, ftl/ftr feet.
local function pose(points)
    return points
end

M.POSITIONS = {
    {
        id = "ATTEND", number = 1, hold_note = "Stand straight. Eyes front.",
        points = pose({ head = { 120, 40 }, neck = { 120, 72 }, hip = { 120, 170 },
            shl = { 88, 84 }, shr = { 152, 84 }, ell = { 84, 128 }, elr = { 156, 128 },
            hal = { 82, 172 }, har = { 158, 172 }, knl = { 104, 232 }, knr = { 136, 232 },
            ftl = { 100, 292 }, ftr = { 140, 292 } }),
    },
    {
        id = "KNEEL", number = 2, hold_note = "Kneel. Hands behind the back.",
        points = pose({ head = { 120, 96 }, neck = { 120, 128 }, hip = { 120, 196 },
            shl = { 88, 140 }, shr = { 152, 140 }, ell = { 92, 180 }, elr = { 148, 180 },
            hal = { 108, 206 }, har = { 132, 206 }, knl = { 96, 262 }, knr = { 144, 262 },
            ftl = { 84, 288 }, ftr = { 156, 288 } }),
    },
    {
        id = "PRESENT", number = 3, hold_note = "Kneel. Present, palms up.",
        points = pose({ head = { 120, 92 }, neck = { 120, 124 }, hip = { 120, 194 },
            shl = { 88, 136 }, shr = { 152, 136 }, ell = { 78, 168 }, elr = { 162, 168 },
            hal = { 64, 148 }, har = { 176, 148 }, knl = { 96, 262 }, knr = { 144, 262 },
            ftl = { 84, 288 }, ftr = { 156, 288 } }),
    },
    {
        id = "BOW", number = 4, hold_note = "Bow deep. Arms hang loose.",
        points = pose({ head = { 152, 122 }, neck = { 128, 110 }, hip = { 110, 190 },
            shl = { 104, 116 }, shr = { 150, 124 }, ell = { 96, 162 }, elr = { 146, 170 },
            hal = { 92, 208 }, har = { 142, 216 }, knl = { 96, 240 }, knr = { 130, 240 },
            ftl = { 88, 294 }, ftr = { 136, 294 } }),
    },
    {
        id = "INSPECT", number = 5, hold_note = "Stand. Arms wide for inspection.",
        points = pose({ head = { 120, 36 }, neck = { 120, 68 }, hip = { 120, 168 },
            shl = { 88, 80 }, shr = { 152, 80 }, ell = { 52, 52 }, elr = { 188, 52 },
            hal = { 30, 26 }, har = { 210, 26 }, knl = { 102, 230 }, knr = { 138, 230 },
            ftl = { 98, 292 }, ftr = { 142, 292 } }),
    },
    {
        id = "SERVE", number = 6, hold_note = "Half-kneel. One arm offers the tray.",
        points = pose({ head = { 120, 60 }, neck = { 120, 90 }, hip = { 118, 180 },
            shl = { 90, 100 }, shr = { 150, 100 }, ell = { 70, 140 }, elr = { 152, 150 },
            hal = { 50, 132 }, har = { 140, 196 }, knl = { 100, 238 }, knr = { 150, 262 },
            ftl = { 96, 292 }, ftr = { 170, 284 } }),
    },
    {
        id = "WAIT", number = 7, hold_note = "Stand. Hands clasped. Head bowed.",
        points = pose({ head = { 120, 54 }, neck = { 120, 80 }, hip = { 120, 172 },
            shl = { 90, 90 }, shr = { 150, 90 }, ell = { 100, 140 }, elr = { 140, 140 },
            hal = { 117, 168 }, har = { 123, 168 }, knl = { 104, 232 }, knr = { 136, 232 },
            ftl = { 100, 292 }, ftr = { 140, 292 } }),
    },
    {
        id = "DISPLAY", number = 8, hold_note = "Stand tall. Hands behind the head.",
        points = pose({ head = { 120, 34 }, neck = { 120, 66 }, hip = { 120, 166 },
            shl = { 88, 78 }, shr = { 152, 78 }, ell = { 56, 44 }, elr = { 184, 44 },
            hal = { 98, 24 }, har = { 142, 24 }, knl = { 100, 230 }, knr = { 140, 230 },
            ftl = { 94, 292 }, ftr = { 146, 292 } }),
    },
}

M.POSITION_COUNT = #M.POSITIONS

--- Position lookup by 1-based index; nil for out-of-range (external input).
---@param index integer
---@return table|nil
function M.position(index)
    if type(index) ~= "number" or index % 1 ~= 0 then
        return nil
    end
    return M.POSITIONS[index]
end

-- Appraisal Brush stiffness presets: sway_max is the tolerated sway in
-- logical pixels; multiplier scales every score the brush awards.
M.PRESETS = {
    soft = { id = "SOFT", sway_max = 30, multiplier = 1.0 },
    firm = { id = "FIRM", sway_max = 20, multiplier = 1.15 },
    severe = { id = "SEVERE", sway_max = 13, multiplier = 1.3 },
}
M.PRESET_ORDER = { "soft", "firm", "severe" }

-- call_mode: name_ghost (name + ghost figure), name_number (name + number,
-- no ghost), number (number only; pad numbers hidden — recall the table).
M.LEVELS = {
    {
        name = "FIRST DRILL", sub = "TEACH", preset = "soft", calls = 6,
        answer_ticks = 360, hold_ticks = 180, call_mode = "name_ghost",
        recall_after = {}, pass_ratio = 0.60, pass_faults_max = 6,
    },
    {
        name = "SECOND DRILL", sub = "THE BRUSH TURNS FIRM", preset = "firm",
        calls = 8, answer_ticks = 300, hold_ticks = 240, call_mode = "name_number",
        recall_after = { [4] = 3 }, pass_ratio = 0.65, pass_faults_max = 5,
    },
    {
        name = "THIRD DRILL", sub = "FROM MEMORY", preset = "severe",
        calls = 10, answer_ticks = 240, hold_ticks = 300, call_mode = "number",
        recall_after = { [4] = 4, [8] = 5 }, pass_ratio = 0.70, pass_faults_max = 4,
    },
}
M.LEVEL_COUNT = #M.LEVELS

-- Sloane's ranks, lowest first. Rank moves only at the ceremony.
M.RANKS = {
    "CONSIDERATION",
    "IN TRAINING",
    "OWNED",
    "ENTRUSTED QUARTERMASTER",
    "FORMAL / KEPT",
}

-- Ceremony gate to advance FROM rank index i (1-based): session ratio at
-- least this, faults at most RANK_FAULTS_MAX, session not stopped, level
-- passed. Teach -> T1 fairness is what the jam measures; keep the numbers
-- in this one table.
M.RANK_GATE_RATIO = { 0.55, 0.60, 0.65, 0.70 }
M.RANK_FAULTS_MAX = 3

M.COMPOSURE_START = 3
M.SCORE_CALL_MAX = 100 -- before the preset multiplier
M.SCORE_RECALL_STEP = 25 -- before the preset multiplier

M.REVELATION_LINES = {
    "THE BOOK NAMES IT PLAINLY AT THE END:",
    "DRILLED WAS THE EUPHEMISM.",
    "SHE WAS BEING TRAINED TO BE KEPT -",
    "AND THE QUARTERMASTER KEEPS THE RECORD.",
}

return M
