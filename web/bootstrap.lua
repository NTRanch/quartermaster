-- web/bootstrap.lua — host wiring, shared by the browser shell and the
-- node tools. The host fills the global QM_SOURCES table (module name ->
-- readable source) before running this chunk; modules register as
-- package.preload entries so require() works identically everywhere.
for name, src in pairs(QM_SOURCES) do
    package.preload[name] = function()
        local chunk, err = load(src, name)
        assert(chunk, err)
        return chunk()
    end
end

local QM = require("src.main")

QM_STATE = nil

function QM_BOOT(seed, demo_level, save)
    local options = {}
    if demo_level ~= nil then
        options.demo_level = demo_level
    end
    if save ~= nil then
        options.save = save
    end
    QM_STATE = QM.new_game(seed, options)
end

function QM_STEP(input)
    QM.step(QM_STATE, input)
end

function QM_FRAME()
    return QM.frame(QM_STATE)
end
