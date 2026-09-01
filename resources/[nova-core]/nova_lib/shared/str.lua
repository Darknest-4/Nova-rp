--[[
    nova_lib :: str
    ---------------------------------------------------------------------------
    String-segédfüggvények. A lokalizációs renderer és a konzol-kimenet
    (startup banner, health riport) épít rájuk.

    Natívot nem hív, FXServer nélkül tesztelhető.
]]

local Nova = rawget(_G, 'Nova') or {}
_G.Nova = Nova

local str = {}

---Whitespace levágása mindkét oldalról.
---@param value string
---@return string
function str.trim(value)
    return (value:gsub('^%s*(.-)%s*$', '%1'))
end

---Szétvágás elválasztó mentén. Az elválasztó nyers szöveg, nem minta.
---@param value string
---@param separator string
---@return string[]
function str.split(value, separator)
    if separator == '' then
        error('str.split: az elválasztó nem lehet üres', 2)
    end

    local parts = {}
    local position = 1
    while true do
        local from, to = value:find(separator, position, true)
        if not from then
            parts[#parts + 1] = value:sub(position)
            break
        end
        parts[#parts + 1] = value:sub(position, from - 1)
        position = to + 1
    end
    return parts
end

---@param value string
---@param prefix string
---@return boolean
function str.startsWith(value, prefix)
    return value:sub(1, #prefix) == prefix
end

---@param value string
---@param suffix string
---@return boolean
function str.endsWith(value, suffix)
    return suffix == '' or value:sub(-#suffix) == suffix
end

---Kulcsos helyettesítés: `{name}` alakú helyőrzők cseréje.
---
---Ez a NYERS behelyettesítés. A lokalizáció ennél többet tud (nyelvfüggő
---szám- és dátumformázás, többes szám) — azt a nova_locale végzi.
---Hiányzó paraméter esetén a helyőrző érintetlen marad, hogy a hiány látható
---legyen, ne néma üres string.
---@param template string
---@param params? table<string, any>
---@return string
function str.interpolate(template, params)
    if not params then return template end
    return (template:gsub('{([%w_%.]+)}', function(key)
        local value = params[key]
        if value == nil then return nil end -- érintetlenül hagyja a helyőrzőt
        return tostring(value)
    end))
end

---Jobbra töltés adott hosszra (konzol-táblázatokhoz).
---@param value string
---@param width integer
---@param fill? string
---@return string
function str.padRight(value, width, fill)
    fill = fill or ' '
    if #value >= width then return value end
    return value .. fill:rep(width - #value)
end

Nova.str = str
return str
