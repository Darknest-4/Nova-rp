--[[
    nova_lib :: tbl
    ---------------------------------------------------------------------------
    Tábla-segédfüggvények. Ezekre épül a konfigurációs rétegzés (deepMerge),
    a lokalizációs szótár laposítása (flatten) és a séma-validátor.

    Natívot nem hív, FXServer nélkül tesztelhető.
]]

local Nova = rawget(_G, 'Nova') or {}
_G.Nova = Nova

local tbl = {}

---Igaz, ha a tábla tömbszerű (1..n folytonos egész kulcsok, más kulcs nincs).
---Üres tábla tömbnek számít.
---@param value any
---@return boolean
function tbl.isArray(value)
    if type(value) ~= 'table' then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' or key % 1 ~= 0 or key < 1 then return false end
        count = count + 1
    end
    return count == #value
end

---Kulcsok száma (a `#` operátor csak tömbökre működik).
---@param value table
---@return integer
function tbl.count(value)
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

---Mély másolat. Ciklikus hivatkozást is kezel.
---@generic T
---@param value T
---@param seen? table
---@return T
function tbl.deepCopy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[tbl.deepCopy(key, seen)] = tbl.deepCopy(item, seen)
    end
    return setmetatable(copy, getmetatable(value))
end

---Mély összefésülés: a `source` felülírja a `target` értékeit.
---Tömböket NEM fésül össze elemenként, hanem lecserél — konfigurációnál ez a
---helyes viselkedés (egy lista felülírása szándékos, nem hozzáfűzés).
---@param target table   ezt módosítja és adja vissza
---@param source table
---@return table
function tbl.deepMerge(target, source)
    for key, item in pairs(source) do
        if type(item) == 'table' and type(target[key]) == 'table'
            and not tbl.isArray(item) and not tbl.isArray(target[key]) then
            tbl.deepMerge(target[key], item)
        else
            target[key] = tbl.deepCopy(item)
        end
    end
    return target
end

---Beágyazott táblát lapos, pontokkal elválasztott kulcsú táblává alakít.
---Tömböket levélértéknek tekint (nem bont szét indexekre).
---
---    { money = { received = 'x' } }  -->  { ['money.received'] = 'x' }
---@param source table
---@param prefix? string
---@param out? table
---@return table<string, any>
function tbl.flatten(source, prefix, out)
    out = out or {}
    for key, item in pairs(source) do
        local path = prefix and (prefix .. '.' .. tostring(key)) or tostring(key)
        if type(item) == 'table' and not tbl.isArray(item) and next(item) ~= nil then
            tbl.flatten(item, path, out)
        else
            out[path] = item
        end
    end
    return out
end

---Érték kiolvasása pont-útvonallal. Hiányzó ág esetén nil, nem hiba.
---@param source table
---@param path string   pl. 'Economy.Banking.MaxTransfer'
---@return any
function tbl.get(source, path)
    local node = source
    for segment in path:gmatch('[^.]+') do
        if type(node) ~= 'table' then return nil end
        node = node[segment]
        if node == nil then return nil end
    end
    return node
end

---Érték beállítása pont-útvonallal, a hiányzó ágak létrehozásával.
---@param target table
---@param path string
---@param value any
---@return table
function tbl.set(target, path, value)
    local node = target
    local segments = {}
    for segment in path:gmatch('[^.]+') do segments[#segments + 1] = segment end

    for index = 1, #segments - 1 do
        local segment = segments[index]
        if type(node[segment]) ~= 'table' then node[segment] = {} end
        node = node[segment]
    end

    node[segments[#segments]] = value
    return target
end

---Rendezett kulcslista — determinisztikus kimenethez (log, riport, generált fájl).
---@param source table
---@return string[]
function tbl.sortedKeys(source)
    local keys = {}
    for key in pairs(source) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    return keys
end

Nova.tbl = tbl
return tbl
