--[[
    nova_lib :: env
    ---------------------------------------------------------------------------
    Tipizált convar-olvasás és titok-maszkolás.

    Miért convar és nem .env fájl?
      A hivatalos Cfx dokumentáció szerint a szerveroldali szkriptek convarokat
      olvasnak (`GetConvar`, `GetConvarInt`); a `set` csak szerveroldalon látszik,
      a `setr` replikálódik a kliensre. Környezeti változó közvetlen olvasására
      nincs dokumentált natív, ezért a titkok a gitignore-olt
      `server/cfg/90-local.cfg`-ben élnek `set` paranccsal.
      A `.env` fájl a Node-alapú toolingé (migráció, validátorok), nem a szerveré.

    FIGYELEM: `set` -> szerveroldali, `setr` -> a KLIENS IS LÁTJA.
    Titok soha nem mehet `setr`-rel.

    Ez a modul natívot hív, ezért a tesztekhez a tests/mocks/cfx.lua mock kell.
]]

local Nova = rawget(_G, 'Nova') or {}
_G.Nova = Nova

local Result = Nova.Result
if not Result then
    error('nova_lib :: env — a result.lua modult előbb be kell tölteni')
end

local env = {}

---Szöveges convar.
---@param key string
---@param default? string
---@return string
function env.string(key, default)
    local value = GetConvar(key, default or '')
    return value
end

---Egész convar. Nem szám esetén az alapértelmezettel tér vissza.
---@param key string
---@param default integer
---@return integer
function env.int(key, default)
    return GetConvarInt(key, default)
end

---Logikai convar. Elfogadott igaz értékek: 'true', '1', 'yes', 'on'.
---@param key string
---@param default boolean
---@return boolean
function env.bool(key, default)
    local raw = GetConvar(key, default and 'true' or 'false'):lower()
    return raw == 'true' or raw == '1' or raw == 'yes' or raw == 'on'
end

---Kötelező convar (tipikusan titok). Hiány esetén hibát ad vissza, nem crashel,
---így a boot-diagnosztika egyszerre tudja jelenteni az összes hiányzó titkot.
---@param key string
---@return NovaResult   ok: string érték, err: 'MISSING_CONVAR'
function env.required(key)
    local value = GetConvar(key, '')
    if value == nil or value == '' then
        return Result.err('MISSING_CONVAR', { key = key })
    end
    return Result.ok(value)
end

---Titok maszkolása naplózáshoz. Sosem írunk ki teljes titkot.
---@param value string|nil
---@param visible? integer  hány karakter maradjon látható (alap: 3)
---@return string
function env.mask(value, visible)
    if value == nil or value == '' then return '<üres>' end
    visible = visible or 3
    if #value <= visible then return ('*'):rep(#value) end
    return value:sub(1, visible) .. ('*'):rep(math.min(#value - visible, 8))
end

Nova.env = env
return env
