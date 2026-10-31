-- src/game.lua — Quartermaster screens + level flow (the shell's partner).
--
--- The core decides everything; the shell forwards input and renders the
--- draw list. Screens: gate, left, title, levels, howto, settings, play,
--- pause, ceremony, victory, gameover. Buttons are immediate-mode: frame()
--- registers them, the next step() hit-tests clicks against that list, so
--- what is drawn is exactly what can be pressed.

local Ceremony = require("src.ceremony")
local Data = require("src.data")
local Demo = require("src.demo")
local Draw = require("src.draw")
local Drill = require("src.drill")
local Ledger = require("src.ledger")
local Rng = require("src.rng")
local Save = require("src.save")

local M = {}

local C = {
    ground = 0, panel = 1, ink = 2, pink = 3, pink_dim = 4, gold = 5,
    good = 6, bad = 7, muted = 8, skin = 9, cloth = 10, silver = 11,
    deep = 12, brush = 13, warn = 14, rule = 15,
}

---@class QmGame
---@field screen string
---@field career QmCareer
---@field seed number
---@field attempts integer level starts so far (varies the drill stream)
---@field buttons table[] hit list from the last frame
---@field drill QmDrill|nil
---@field ledger QmLedger|nil
---@field demo QmDemo|nil non-nil in demo mode
---@field verdict table|nil ceremony outcome
---@field session table|nil ceremony session summary
---@field save_dirty boolean career changed since last frame emission
---@field reduce_motion boolean session-only display option
---@field ticks integer steps taken (drives blink/pulse, deterministic)

--- New game. options.save is external input: a malformed string loads
--- defaults, never an error (the save module validates).
---@param seed number
---@param options table|nil { demo_level = integer|nil, save = string|nil }
---@return QmGame
function M.new(seed, options)
    assert(type(seed) == "number", "seed must be a number")
    local opts = type(options) == "table" and options or {}
    local career = Save.default_career()
    if type(opts.save) == "string" then
        local loaded = Save.deserialize(opts.save)
        if loaded ~= nil then
            career = loaded
        end
    end
    local game = {
        screen = "gate",
        career = career,
        seed = seed,
        attempts = 0,
        buttons = {},
        frame_buttons = {},
        drill = nil,
        ledger = nil,
        demo = nil,
        verdict = nil,
        session = nil,
        level_index = 1,
        save_dirty = false,
        reduce_motion = false,
        ticks = 0,
        pending_cues = {},
    }
    if type(opts.demo_level) == "number" and Data.LEVELS[opts.demo_level] ~= nil then
        game.demo = Demo.new(Rng.new(seed + 999331))
        M.start_level(game, opts.demo_level)
    end
    return game
end

--- Begin a level: fresh ledger, fresh drill stream, ceremony reset.
---@param game QmGame
---@param level_index integer
function M.start_level(game, level_index)
    assert(Data.LEVELS[level_index] ~= nil, "level index invariant")
    game.attempts = game.attempts + 1
    game.level_index = level_index
    game.ledger = Ledger.new()
    local stream = Rng.new(game.seed * 31 + level_index * 1000 + game.attempts)
    game.drill = Drill.new(level_index, stream, game.ledger,
        { assist = game.career.assist })
    game.verdict = nil
    game.session = nil
    game.screen = "play"
end

-- Input ------------------------------------------------------------------

local function find_button(game, x, y)
    for index = #game.buttons, 1, -1 do
        local button = game.buttons[index]
        if not button.disabled and x >= button.x and x <= button.x + button.w
            and y >= button.y and y <= button.y + button.h then
            return button
        end
    end
    return nil
end

local function adjust_setting(game, id)
    local career = game.career
    if id == "vol_down" then
        career.volume = math.max(0, career.volume - 10)
    elseif id == "vol_up" then
        career.volume = math.min(100, career.volume + 10)
    elseif id == "assist" then
        career.assist = not career.assist
    elseif id == "motion" then
        game.reduce_motion = not game.reduce_motion
        return -- session-only: nothing to persist
    else
        return
    end
    game.save_dirty = true
end

local function on_button(game, id)
    local screen = game.screen
    if id == "enter" and screen == "gate" then
        game.screen = "title"
    elseif id == "leave" and screen == "gate" then
        game.screen = "left"
    elseif id == "back_gate" then
        game.screen = "gate"
    elseif id == "to_levels" and screen == "title" then
        game.screen = "levels"
    elseif id == "to_howto" and screen == "title" then
        game.screen = "howto"
    elseif id == "to_settings" and (screen == "title" or screen == "pause") then
        game.screen = "settings"
        game.settings_from = screen
    elseif id == "back" and screen == "levels" then
        game.screen = "title"
    elseif id == "back" and screen == "howto" then
        game.screen = "title"
    elseif id == "back" and screen == "settings" then
        game.screen = game.settings_from or "title"
    elseif id:sub(1, 5) == "level" and screen == "levels" then
        local index = tonumber(id:sub(6))
        if index ~= nil and index <= game.career.unlocked_level then
            M.start_level(game, index)
        end
    elseif id == "pause" and screen == "play" then
        game.screen = "pause"
    elseif id == "resume" and screen == "pause" then
        game.screen = "play"
    elseif id == "restart" and screen == "pause" then
        M.start_level(game, game.level_index)
    elseif id == "quit_title" then
        game.screen = "title"
        game.drill = nil
    elseif id == "continue" and (screen == "ceremony" or screen == "victory") then
        game.screen = "levels"
        game.drill = nil
    elseif id == "retry" and (screen == "ceremony" or screen == "gameover") then
        M.start_level(game, game.level_index)
    elseif id == "to_title" and screen == "gameover" then
        game.screen = "title"
        game.drill = nil
    else
        adjust_setting(game, id)
    end
end

--- Close a finished drill into ceremony / victory / gameover, once.
---@param game QmGame
local function finish_drill(game)
    local drill = game.drill
    if drill.failed then
        game.screen = "gameover"
        return
    end
    local session = Drill.session(drill)
    local verdict, err = Ceremony.apply(game.career, game.level_index, session)
    assert(verdict ~= nil, "ceremony apply invariant: " .. tostring(err))
    game.session = session
    game.verdict = verdict
    game.save_dirty = true
    if game.level_index == Data.LEVEL_COUNT and verdict.passed then
        game.screen = "victory"
    else
        game.screen = "ceremony"
    end
end

--- One fixed step (1/60 s). Input is external and fully type-checked.
---@param game QmGame
---@param input table|nil { x, y, pressed, down, key }
function M.step(game, input)
    game.ticks = game.ticks + 1
    local clean = { down = false }
    if type(input) == "table" then
        clean.down = input.down == true
        if input.pressed == true and type(input.x) == "number"
            and type(input.y) == "number" then
            local button = find_button(game, input.x, input.y)
            if button ~= nil then
                clean.button = button.id
            end
            clean.click_x, clean.click_y = input.x, input.y
        end
        if type(input.key) == "string" then
            clean.key = input.key
        end
    end
    if clean.key == "escape" then
        if game.screen == "play" then
            game.screen = "pause"
            return
        elseif game.screen == "pause" then
            game.screen = "play"
            return
        end
    end
    if clean.button ~= nil then
        game.pending_cues[#game.pending_cues + 1] = "click"
        on_button(game, clean.button)
    end
    if game.screen ~= "play" or game.drill == nil then
        return
    end
    local drill_input = { down = clean.down }
    if game.demo ~= nil then
        drill_input = Demo.input(game.demo, game.drill)
    else
        if clean.button ~= nil and clean.button:sub(1, 3) == "pad" then
            drill_input.pick = tonumber(clean.button:sub(4))
        end
        if clean.button == "stop" then
            drill_input.stop = true
        end
        if clean.key ~= nil and clean.key:match("^[1-8]$") then
            drill_input.pick = tonumber(clean.key)
        end
    end
    local was_done = game.drill.phase == "done"
    Drill.step(game.drill, drill_input)
    for _, cue in ipairs(game.drill.cues) do
        game.pending_cues[#game.pending_cues + 1] = cue
    end
    if not was_done and game.drill.phase == "done" then
        finish_drill(game)
    end
end

-- Drawing ----------------------------------------------------------------

local function button(game, draw, id, x, y, w, h, label, options)
    local opts = options or {}
    local edge = opts.disabled and C.muted or (opts.color or C.pink)
    Draw.panel(draw, x, y, w, h, C.panel, edge)
    Draw.text_centered(draw, x + w / 2, y + h / 2 - (opts.size or 22) / 2,
        opts.size or 22, opts.disabled and C.muted or C.ink, label)
    game.frame_buttons[#game.frame_buttons + 1] =
        { id = id, x = x, y = y, w = w, h = h, disabled = opts.disabled }
end

local function header(draw, title, sub)
    Draw.text_centered(draw, 480, 36, 44, C.pink, title)
    if sub ~= nil then
        Draw.text_centered(draw, 480, 92, 20, C.muted, sub)
    end
    Draw.line(draw, 60, 122, 900, 122, 2, C.rule)
end

local function draw_gate(game, draw)
    header(draw, "QUARTERMASTER", "NICE THOUGHTS RANCH - TOROGAO JAM WEEK 9")
    Draw.text_centered(draw, 480, 220, 30, C.warn, "ADULTS ONLY - 18+")
    local lines = {
        "THIS GAME CONTAINS ADULT TRAINING FICTION:",
        "POWER EXCHANGE, DISCIPLINE DRILLS, APPRAISAL,",
        "AND SERVICE UNDER PROTOCOL. ALL PARTICIPANTS",
        "ARE ADULTS. THE STOP CONTROL ENDS ANY SCENE",
        "AT ONCE, WITHOUT PENALTY, AT ANY TIME.",
    }
    for index, line in ipairs(lines) do
        Draw.text_centered(draw, 480, 300 + index * 34, 20, C.ink, line)
    end
    button(game, draw, "enter", 240, 560, 480, 72, "I AM 18 OR OLDER - ENTER")
    button(game, draw, "leave", 240, 660, 480, 72, "LEAVE", { color = C.muted })
end

local function draw_left(game, draw)
    header(draw, "QUARTERMASTER")
    Draw.text_centered(draw, 480, 320, 24, C.ink, "THIS GAME IS FOR ADULTS ONLY.")
    Draw.text_centered(draw, 480, 370, 24, C.ink, "THANK YOU FOR YOUR HONESTY.")
    button(game, draw, "back_gate", 330, 520, 300, 64, "BACK")
end

local function draw_title(game, draw)
    header(draw, "QUARTERMASTER", "DRILLED - POSITIONS DRILL: CALL-AND-HOLD")
    local career = game.career
    Draw.text_centered(draw, 480, 210, 26, C.gold,
        "SLOANE - RANK: " .. Data.RANKS[career.rank_index])
    Draw.text_centered(draw, 480, 252, 20, C.muted,
        "CEREMONIES WITNESSED: " .. career.ceremonies)
    if career.rank_index >= #Data.RANKS then
        Draw.text_centered(draw, 480, 292, 20, C.good, "THE BOOK IS COMPLETE")
    end
    button(game, draw, "to_levels", 280, 360, 400, 72, "ENTER THE DRILL")
    button(game, draw, "to_howto", 280, 452, 400, 72, "HOW TO PLAY")
    button(game, draw, "to_settings", 280, 544, 400, 72, "SETTINGS")
    Draw.text_centered(draw, 480, 880, 18, C.muted,
        "GAME LOGIC IN READABLE LUA - FENGARI VM - WEEK 9")
end

local function draw_levels(game, draw)
    header(draw, "CHOOSE THE DRILL", "LATER DRILLS UNLOCK AT THE CEREMONY")
    for index, level in ipairs(Data.LEVELS) do
        local y = 190 + (index - 1) * 200
        local locked = index > game.career.unlocked_level
        local best = game.career.best_pct[index] or 0
        local label = level.name .. " - " .. level.sub
        if locked then
            label = level.name .. " - LOCKED"
        elseif best > 0 then
            label = label .. " - BEST " .. best .. "%"
        end
        button(game, draw, "level" .. index, 130, y, 700, 120, label,
            { disabled = locked, size = 26 })
    end
    button(game, draw, "back", 330, 830, 300, 60, "BACK")
end

local HOWTO_LINES = {
    "THE QUARTERMASTER CALLS A POSITION. ANSWER IT",
    "ON THE PADS (OR KEYS 1-8) BEFORE TIME RUNS OUT.",
    "",
    "THEN HOLD: KEEP THE POINTER HELD TO BRACE.",
    "BRACING DAMS THE SWAY BUT DRAINS POISE - REST",
    "TO RECOVER. SWAY PAST THE BRUSH LINE, UNBRACED,",
    "IS A FAULT. THE BRUSH GRADES EVERY HOLD.",
    "",
    "LATER DRILLS WEAVE IN PROTOCOL RECALL: WATCH",
    "THE SEQUENCE, THEN ANSWER IT FROM MEMORY.",
    "",
    "EVERY CALL IS ENTERED IN THE EVIDENCE LEDGER.",
    "AT THE CEREMONY THE BOOK IS READ, WITNESSED,",
    "AND RANK MOVES - THERE, AND NOWHERE ELSE.",
    "",
    "STOP ENDS THE SCENE AT ONCE. NO PENALTY. EVER.",
}

local function draw_howto(game, draw)
    header(draw, "HOW TO PLAY")
    for index, line in ipairs(HOWTO_LINES) do
        Draw.text(draw, 110, 180 + index * 36, 21, C.ink, line)
    end
    button(game, draw, "back", 330, 850, 300, 60, "BACK")
end

local function draw_settings(game, draw)
    header(draw, "SETTINGS", "SAVED WITH THE CAREER RECORD")
    local career = game.career
    Draw.text(draw, 130, 220, 24, C.ink, "SOUND VOLUME")
    button(game, draw, "vol_down", 560, 200, 70, 56, "-")
    Draw.text_centered(draw, 705, 214, 26, C.gold, tostring(career.volume))
    button(game, draw, "vol_up", 780, 200, 70, 56, "+")
    Draw.text(draw, 130, 330, 24, C.ink, "SWAY ASSIST (WIDER BRUSH LINE)")
    button(game, draw, "assist", 560, 310, 290, 56,
        career.assist and "ON" or "OFF", { color = C.gold })
    Draw.text(draw, 130, 440, 24, C.ink, "REDUCE MOTION (CALMER FIGURE)")
    button(game, draw, "motion", 560, 420, 290, 56,
        game.reduce_motion and "ON" or "OFF", { color = C.gold })
    Draw.text_centered(draw, 480, 560, 19, C.muted,
        "ASSIST AND SAFETY OPTIONS ARE NEVER LOCKED")
    Draw.text_centered(draw, 480, 592, 19, C.muted,
        "BEHIND PROGRESS. THEY APPLY AT ONCE.")
    button(game, draw, "back", 330, 850, 300, 60, "BACK")
end

local function pad_label(game, index)
    local position = Data.POSITIONS[index]
    if game.drill ~= nil and game.drill.level.call_mode == "number" then
        return position.id
    end
    return position.number .. " " .. position.id
end

local function draw_pads(game, draw)
    for index = 1, Data.POSITION_COUNT do
        local col = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        local x = 60 + col * 212
        local y = 660 + row * 96
        local active = game.drill ~= nil
            and (game.drill.phase == "call" or game.drill.phase == "recall_answer")
        button(game, draw, "pad" .. index, x, y, 200, 84, pad_label(game, index),
            { size = 20, color = active and C.pink or C.pink_dim })
    end
end

local function call_text(drill)
    local position = Data.POSITIONS[drill.target]
    if drill.level.call_mode == "name_ghost" then
        return position.id
    elseif drill.level.call_mode == "name_number" then
        return position.number .. " - " .. position.id
    end
    return "POSITION " .. position.number
end

local function draw_stage(game, draw)
    local drill = game.drill
    Draw.panel(draw, 60, 150, 430, 480, C.deep, C.rule)
    local points = Data.POSITIONS[7].points -- WAIT at rest
    local sway = 0
    local caption = "AT REST"
    if drill.phase == "call" and drill.level.call_mode == "name_ghost" then
        points = Data.POSITIONS[drill.target].points
        caption = "THE GHOST SHOWS THE SHAPE"
    elseif drill.phase == "hold" or drill.phase == "appraise" then
        points = Data.POSITIONS[drill.target].points
        sway = drill.sway
        caption = Data.POSITIONS[drill.target].hold_note
    elseif drill.phase == "recall_show" and drill.recall ~= nil then
        local index = drill.recall.seq[drill.recall.show_index]
        points = Data.POSITIONS[index].points
        caption = "WATCH - " .. drill.recall.show_index .. " OF " .. #drill.recall.seq
    elseif drill.phase == "recall_answer" then
        caption = "ANSWER FROM MEMORY"
    end
    if game.reduce_motion then
        sway = sway * 0.35
    end
    Draw.figure(draw, points, 155, 240, 1.25, sway, C.skin, C.cloth)
    Draw.text_centered(draw, 275, 585, 18, C.muted, caption)
end

local function draw_call_panel(game, draw)
    local drill = game.drill
    Draw.panel(draw, 520, 150, 380, 480, C.panel, C.rule)
    Draw.text_centered(draw, 710, 172, 20, C.muted,
        "CALL " .. math.min(drill.call_number, drill.level.calls)
        .. " OF " .. drill.level.calls)
    if drill.phase == "call" then
        Draw.text_centered(draw, 710, 250, 44, C.pink, call_text(drill))
        local left = 1 - drill.ticks / drill.level.answer_ticks
        Draw.rect(draw, 550, 340, 320, 18, C.deep)
        Draw.rect(draw, 550, 340, math.max(0, 320 * left), 18, C.warn)
        Draw.text_centered(draw, 710, 400, 20, C.ink, "ANSWER ON THE PADS")
    elseif drill.phase == "hold" then
        Draw.text_centered(draw, 710, 230, 32, C.ink,
            Data.POSITIONS[drill.target].id)
        local progress = drill.hold_elapsed / drill.level.hold_ticks
        Draw.rect(draw, 550, 290, 320, 18, C.deep)
        Draw.rect(draw, 550, 290, 320 * progress, 18, C.good)
        Draw.text_centered(draw, 710, 330, 19, C.muted, "HOLD - BRACE TO STEADY")
        local tolerance = Drill.sway_max(drill)
        Draw.rect(draw, 710 - tolerance, 400, tolerance * 2, 26, C.pink_dim)
        local needle = 710 + math.max(-70, math.min(70, drill.sway * 2))
        Draw.rect(draw, needle - 3, 388, 6, 50, C.brush)
        Draw.text_centered(draw, 710, 450, 19, C.muted, "THE APPRAISAL BRUSH")
        Draw.rect(draw, 550, 510, 320, 16, C.deep)
        Draw.rect(draw, 550, 510, 320 * drill.poise / 100, 16, C.gold)
        Draw.text_centered(draw, 710, 545, 19, C.muted, "POISE")
        if drill.braced then
            Draw.text_centered(draw, 710, 585, 19, C.good, "BRACED")
        end
    elseif drill.phase == "appraise" and drill.result ~= nil then
        Draw.text_centered(draw, 710, 240, 30, C.ink, drill.result.label)
        Draw.text_centered(draw, 710, 300, 64, C.gold, drill.result.grade)
        Draw.text_centered(draw, 710, 400, 26, C.ink,
            drill.result.score .. " OF " .. drill.result.score_max)
        Draw.text_centered(draw, 710, 450, 19, C.muted, drill.result.detail)
    elseif drill.phase == "recall_show" then
        Draw.text_centered(draw, 710, 280, 32, C.pink, "PROTOCOL RECALL")
        Draw.text_centered(draw, 710, 340, 20, C.ink, "MEMORISE THE SEQUENCE")
    elseif drill.phase == "recall_answer" and drill.recall ~= nil then
        Draw.text_centered(draw, 710, 280, 32, C.pink, "RECALL")
        Draw.text_centered(draw, 710, 340, 22, C.ink,
            "STEP " .. drill.recall.answer_index .. " OF " .. #drill.recall.seq)
    end
end

local function draw_play(game, draw)
    local drill = game.drill
    Draw.text(draw, 60, 30, 30, C.pink, drill.level.name)
    Draw.text(draw, 60, 68, 19, C.muted,
        "BRUSH " .. drill.preset.id .. " - SCORE " .. game.ledger.total_score)
    for index = 1, Data.COMPOSURE_START do
        local ci = index <= drill.composure and C.pink or C.deep
        Draw.circle(draw, 620 + index * 34, 44, 12, ci)
    end
    button(game, draw, "pause", 760, 20, 90, 48, "PAUSE", { size = 17 })
    button(game, draw, "stop", 856, 20, 90, 48, "STOP", { size = 17, color = C.bad })
    draw_stage(game, draw)
    draw_call_panel(game, draw)
    draw_pads(game, draw)
end

local function draw_pause(game, draw)
    draw_play(game, draw)
    Draw.rect(draw, 0, 0, 960, 960, C.deep)
    Draw.panel(draw, 280, 300, 400, 360, C.panel, C.pink)
    Draw.text_centered(draw, 480, 330, 34, C.pink, "PAUSED")
    button(game, draw, "resume", 330, 400, 300, 60, "RESUME")
    button(game, draw, "restart", 330, 476, 300, 60, "RESTART DRILL")
    button(game, draw, "quit_title", 330, 552, 300, 60, "QUIT TO TITLE")
end

local function draw_ceremony(game, draw, victory)
    if victory then
        header(draw, "THE FINAL CEREMONY", "THIRD DRILL - FROM MEMORY")
    else
        header(draw, "THE APPRAISAL CEREMONY", game.drill.level.name)
    end
    local y = 170
    for _, entry in ipairs(game.ledger.entries) do
        if y > 560 then
            Draw.text_centered(draw, 480, y, 18, C.muted, "... THE BOOK CONTINUES")
            break
        end
        local line = entry.label .. "  " .. entry.score .. "/" .. entry.score_max
        if entry.faults > 0 then
            line = line .. "  FAULTS " .. entry.faults
        end
        Draw.text_centered(draw, 480, y, 19, C.ink, line)
        y = y + 30
    end
    local session = game.session
    Draw.text_centered(draw, 480, 590, 24, C.gold,
        "TOTAL " .. session.score .. " OF " .. session.score_max
        .. " - " .. math.floor(session.ratio * 100 + 0.5) .. "%")
    if session.stopped then
        Draw.text_centered(draw, 480, 632, 21, C.warn,
            "THE SCENE WAS STOPPED. THE BOOK RECORDS IT. NO MOVEMENT.")
    elseif session.passed then
        Draw.text_centered(draw, 480, 632, 21, C.good, "THE DRILL IS PASSED")
    else
        Draw.text_centered(draw, 480, 632, 21, C.bad, "THE DRILL IS NOT PASSED")
    end
    local verdict = game.verdict
    if verdict.advanced then
        Draw.text_centered(draw, 480, 668, 23, C.pink,
            "RANK ADVANCES: " .. Data.RANKS[verdict.rank_from]
            .. " TO " .. Data.RANKS[verdict.rank_to])
    else
        Draw.text_centered(draw, 480, 668, 21, C.muted,
            "RANK HOLDS AT " .. Data.RANKS[verdict.rank_to])
    end
    Draw.text_centered(draw, 480, 706, 18, C.muted,
        "WITNESSED AND ENTERED IN THE BOOK OF RECORD")
    if victory then
        for index, line in ipairs(Data.REVELATION_LINES) do
            Draw.text_centered(draw, 480, 736 + index * 26, 19, C.gold, line)
        end
    end
    button(game, draw, "continue", 200, 856, 260, 60, "CONTINUE")
    if not session.passed then
        button(game, draw, "retry", 500, 856, 260, 60, "DRILL AGAIN")
    end
end

local function draw_gameover(game, draw)
    header(draw, "THE DRILL IS ENDED")
    Draw.text_centered(draw, 480, 300, 24, C.ink, "COMPOSURE SPENT. THE QUARTERMASTER")
    Draw.text_centered(draw, 480, 340, 24, C.ink, "CLOSES THE BOOK FOR TODAY.")
    Draw.text_centered(draw, 480, 420, 20, C.muted,
        "SCORE " .. game.ledger.total_score .. " - THE EVIDENCE REMAINS FILED")
    button(game, draw, "retry", 280, 520, 400, 64, "DRILL AGAIN")
    button(game, draw, "to_title", 280, 600, 400, 64, "TITLE")
end

local DRAWERS = {
    gate = draw_gate, left = draw_left, title = draw_title,
    levels = draw_levels, howto = draw_howto, settings = draw_settings,
    play = draw_play, pause = draw_pause, gameover = draw_gameover,
}

--- Render the current frame: { palette, ops, cues, save, volume }.
---@param game QmGame
---@return table
function M.frame(game)
    local draw = Draw.new()
    game.frame_buttons = {}
    Draw.rect(draw, 0, 0, 960, 960, C.ground)
    if game.screen == "ceremony" then
        draw_ceremony(game, draw, false)
    elseif game.screen == "victory" then
        draw_ceremony(game, draw, true)
    else
        DRAWERS[game.screen](game, draw)
    end
    game.buttons = game.frame_buttons
    local frame = {
        palette = Data.PALETTE,
        ops = draw.ops,
        cues = game.pending_cues,
        volume = game.career.volume,
    }
    game.pending_cues = {}
    if game.save_dirty then
        frame.save = Save.serialize(game.career)
        game.save_dirty = false
    end
    return frame
end

return M
