-- src/draw.lua — Quartermaster draw-list builder + abstract figure.
--
--- The core emits per-frame draw lists (contract: PLAN.md). Ops are the
--- compact arrays the shared rasteriser and the canvas shell both read:
--- { "r", x, y, w, h, ci } { "c", x, y, r, ci } { "l", x1, y1, x2, y2, w, ci }
--- { "p", x1, y1, x2, y2, x3, y3, ci } { "t", x, y, size, ci, "TEXT" }.
--- Colour indices are 0-based into the palette. All numbers are rounded
--- to integers here, at emission, which is what makes frame dumps byte-
--- identical across VMs (the conformance gate relies on it).

local M = {}

M.OPS_MAX = 4000 -- hard bound per frame; assert fires long before the shell cares

local ALLOWED = {}
do
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?-+: '/()&%"
    for index = 1, #chars do
        ALLOWED[chars:sub(index, index)] = true
    end
end

local function round(value)
    return math.floor(value + 0.5)
end

--- Uppercase and replace anything outside the bitmap-font charset.
---@param text string
---@return string
function M.sanitize(text)
    local upper = tostring(text):upper()
    local out = {}
    for index = 1, #upper do
        local char = upper:sub(index, index)
        if ALLOWED[char] then
            out[#out + 1] = char
        else
            out[#out + 1] = " "
        end
    end
    return table.concat(out)
end

---@class QmDraw
---@field ops table[] the frame's op list

---@return QmDraw
function M.new()
    return { ops = {} }
end

local function push(draw, op)
    assert(#draw.ops < M.OPS_MAX, "draw list exceeds per-frame bound")
    draw.ops[#draw.ops + 1] = op
end

---@param draw QmDraw
function M.rect(draw, x, y, w, h, ci)
    push(draw, { "r", round(x), round(y), round(w), round(h), ci })
end

---@param draw QmDraw
function M.circle(draw, x, y, r, ci)
    push(draw, { "c", round(x), round(y), round(r), ci })
end

---@param draw QmDraw
function M.line(draw, x1, y1, x2, y2, w, ci)
    push(draw, { "l", round(x1), round(y1), round(x2), round(y2), round(w), ci })
end

---@param draw QmDraw
function M.tri(draw, x1, y1, x2, y2, x3, y3, ci)
    push(draw, { "p", round(x1), round(y1), round(x2), round(y2),
        round(x3), round(y3), ci })
end

---@param draw QmDraw
function M.text(draw, x, y, size, ci, text)
    push(draw, { "t", round(x), round(y), round(size), ci, M.sanitize(text) })
end

--- Approximate text width in logical px (bitmap advance is 0.6 x size).
---@param text string
---@param size number
---@return number
function M.text_width(text, size)
    return #M.sanitize(text) * size * 0.6
end

---@param draw QmDraw
function M.text_centered(draw, cx, y, size, ci, text)
    local clean = M.sanitize(text)
    M.text(draw, cx - (#clean * size * 0.6) / 2, y, size, ci, clean)
end

--- Framed panel: fill + 2px rule.
---@param draw QmDraw
function M.panel(draw, x, y, w, h, fill_ci, edge_ci)
    M.rect(draw, x, y, w, h, fill_ci)
    M.line(draw, x, y, x + w, y, 2, edge_ci)
    M.line(draw, x, y + h, x + w, y + h, 2, edge_ci)
    M.line(draw, x, y, x, y + h, 2, edge_ci)
    M.line(draw, x + w, y, x + w, y + h, 2, edge_ci)
end

-- How far each figure point rides the sway: upper body moves, feet stay.
local SWAY_FACTOR = {
    head = 1.0, neck = 0.9, shl = 0.85, shr = 0.85, ell = 0.8, elr = 0.8,
    hal = 0.75, har = 0.75, hip = 0.3, knl = 0.05, knr = 0.05, ftl = 0, ftr = 0,
}

--- Draw the abstract drilled figure for a pose point set.
---@param draw QmDraw
---@param points table pose points (240x300 cell)
---@param ox number cell origin x
---@param oy number cell origin y
---@param scale number cell scale (1 = 240x300)
---@param sway number horizontal sway in logical px
---@param line_ci integer limb colour index
---@param cloth_ci integer torso colour index
function M.figure(draw, points, ox, oy, scale, sway, line_ci, cloth_ci)
    local function px(name)
        local point = points[name]
        local factor = SWAY_FACTOR[name] or 0
        return ox + point[1] * scale + sway * factor, oy + point[2] * scale
    end
    local hx, hy = px("head")
    local nx, ny = px("neck")
    local ix, iy = px("hip")
    M.circle(draw, hx, hy, 26 * scale, line_ci)
    M.line(draw, nx, ny, ix, iy, 12 * scale, cloth_ci) -- torso
    local limbs = {
        { "shl", "ell" }, { "ell", "hal" }, { "shr", "elr" }, { "elr", "har" },
        { "hip", "knl" }, { "knl", "ftl" }, { "hip", "knr" }, { "knr", "ftr" },
    }
    for _, pair in ipairs(limbs) do
        local ax, ay = px(pair[1])
        local bx, by = px(pair[2])
        M.line(draw, ax, ay, bx, by, 7 * scale, line_ci)
    end
    M.line(draw, select(1, px("shl")), select(2, px("shl")),
        select(1, px("shr")), select(2, px("shr")), 8 * scale, cloth_ci)
    M.line(draw, ox, oy + 300 * scale, ox + 240 * scale, oy + 300 * scale, 3, cloth_ci)
end

return M
