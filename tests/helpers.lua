--[[
    tests/helpers.lua
    ---------------------------------------------------------------------------
    Modulbetöltés a unit tesztekhez.

    A NOVA magmoduljai úgy vannak megírva, hogy betöltéskor NINCS mellékhatásuk:
    a globális `Nova` névtérbe regisztrálják magukat ÉS visszaadják a modult.
    Így ugyanaz a fájl fut az FXServerben (shared_script) és a tesztben (dofile).
]]

local helpers = {}

local LIB = 'resources/[nova-core]/nova_lib/shared/'

---A nova_lib modulok kötött betöltési sorrendje (a schema a result-ra és a
---tbl-re épül). Ugyanez a sorrend szerepel a fxmanifest.lua-ban.
local LIB_ORDER = { 'result', 'tbl', 'str', 'schema', 'env' }

---Egyetlen Lua modul betöltése a repository gyökeréhez képest.
---@param path string
---@return any
function helpers.loadFile(path)
    local chunk, err = loadfile(path)
    if not chunk then
        error(('nem sikerült betölteni: %s (%s)'):format(path, err), 2)
    end
    return chunk()
end

---A teljes nova_lib betöltése tiszta névtérbe.
---@return table Nova
function helpers.loadLib()
    _G.Nova = nil
    for _, name in ipairs(LIB_ORDER) do
        helpers.loadFile(LIB .. name .. '.lua')
    end
    return _G.Nova
end

return helpers
