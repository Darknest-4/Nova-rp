--[[
    tests/mocks/cfx.lua
    ---------------------------------------------------------------------------
    Minimális CitizenFX natív-mock, hogy a NOVA magmoduljai FXServer NÉLKÜL is
    tesztelhetők legyenek.

    Elv: a mock csak annyit valósít meg, amennyit a tesztelt kód valóban használ.
    Nem célja a teljes natív-felület utánzása — az illúziót keltene, hogy
    a mock ellen zöld teszt egyenlő a szerveren működő kóddal.
    Ami natívra épül és tényleg a szerveren dől el, arra integrációs teszt van.
]]

local cfx = {}

---A mock belső állapota. Tesztek közt `cfx.reset()`-tel ürítendő.
cfx.state = {
    convars   = {},   -- [key] = string
    events    = {},   -- kliensnek küldött eventek naplója
    prints    = {},   -- print() kimenet
    resource  = 'nova_test',
}

local function toStringValue(value)
    if type(value) == 'boolean' then return value and 'true' or 'false' end
    return tostring(value)
end

---Convar beállítása a teszthez.
---@param key string
---@param value any
function cfx.setConvar(key, value)
    cfx.state.convars[key] = toStringValue(value)
end

---Minden mock-állapot törlése.
function cfx.reset()
    cfx.state.convars = {}
    cfx.state.events = {}
    cfx.state.prints = {}
end

---A natívok globális telepítése.
function cfx.install()
    _G.GetConvar = function(key, default)
        local value = cfx.state.convars[key]
        if value == nil then return default end
        return value
    end

    _G.GetConvarInt = function(key, default)
        local value = tonumber(cfx.state.convars[key])
        if value == nil then return default end
        return math.floor(value)
    end

    _G.GetCurrentResourceName = function()
        return cfx.state.resource
    end

    _G.TriggerClientEvent = function(eventName, target, ...)
        cfx.state.events[#cfx.state.events + 1] = {
            name = eventName, target = target, args = { ... },
        }
    end

    _G.LoadResourceFile = function(_, path)
        local file = io.open(path, 'r')
        if not file then return nil end
        local content = file:read('a')
        file:close()
        return content
    end
end

return cfx
