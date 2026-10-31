-- tests/spec_helper.lua — shared spec utilities (not a _spec file).

local H = {}

--- Canonical one-line-per-op dump of a frame; integers print identically
--- in PUC 5.4 and Fengari 5.3, which is the whole point of the format.
---@param frame table
---@return string
function H.dump_frame(frame)
    local lines = {}
    for _, op in ipairs(frame.ops) do
        local fields = {}
        for index = 1, #op do
            local value = op[index]
            if type(value) == "number" then
                fields[#fields + 1] = string.format("%d", value)
            else
                fields[#fields + 1] = tostring(value)
            end
        end
        lines[#lines + 1] = table.concat(fields, ",")
    end
    return table.concat(lines, "\n")
end

--- Click a button by id: render a frame, find the button, press its centre.
---@param main table src.main API
---@param state table game state
---@param id string
---@return boolean found
function H.click(main, state, id)
    main.frame(state)
    for _, button in ipairs(state.buttons) do
        if button.id == id and not button.disabled then
            main.step(state, {
                x = button.x + button.w / 2, y = button.y + button.h / 2,
                pressed = true, down = false,
            })
            return true
        end
    end
    return false
end

--- Step n ticks, optionally feeding input from fn(tick) each tick.
function H.ticks(main, state, count, fn)
    for tick = 1, count do
        main.step(state, fn ~= nil and fn(tick) or nil)
    end
end

return H
