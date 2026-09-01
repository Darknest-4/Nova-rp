--[[
    nova_lib :: schema
    ---------------------------------------------------------------------------
    Deklaratív séma-validátor. Erre épül:
      - a konfiguráció boot-idejű ellenőrzése (nova_config)
      - a kliens -> szerver eventek payload-validációja (nova_net)

    Tervezési döntések:
      - MINDEN hibát összegyűjt, nem az elsőnél áll meg. Egy hibás konfignál
        a fejlesztő látni akarja mind a 6 hibát, nem egyesével.
      - A hibák nyelvfüggetlen kódok + paraméterek (nem magyar szövegek),
        így lokalizálhatók és géppel feldolgozhatók.
      - `strict` módban az ismeretlen kulcs HIBA. Egy elgépelt konfigkulcs
        némán az alapértelmezéssel futna tovább — ez a legalattomosabb hibafajta.

    Natívot nem hív, FXServer nélkül tesztelhető.

    Séma-mezők:
      type      'string' | 'number' | 'integer' | 'boolean' | 'table' | 'array' | 'any'
      optional  boolean          hiányozhat-e
      default   any              hiány esetén ezt kapja (optional-t nem igényel)
      min, max  number           szám tartomány (inkluzív)
      minLen    integer          string hossz / tömb elemszám alsó határa
      maxLen    integer          string hossz / tömb elemszám felső határa
      pattern   string           Lua minta stringre
      enum      any[]            megengedett értékek
      fields    table<string, spec>  table típusnál a mezők sémája
      strict    boolean          table típusnál: ismeretlen kulcs hiba (alap: true)
      items     spec             array típusnál az elemek sémája
]]

local Nova = rawget(_G, 'Nova') or {}
_G.Nova = Nova

-- Betöltési sorrend: result.lua és tbl.lua előbb (lásd fxmanifest.lua).
local Result = Nova.Result
local tbl = Nova.tbl
if not Result or not tbl then
    error('nova_lib :: schema — a result.lua és a tbl.lua modult előbb be kell tölteni')
end

local schema = {}

local function addIssue(issues, path, code, extra)
    local issue = { path = path, code = code }
    if extra then
        for key, value in pairs(extra) do issue[key] = value end
    end
    issues[#issues + 1] = issue
end

local function typeName(value)
    local luaType = type(value)
    if luaType == 'table' then
        local isArray = true
        local count = 0
        for key in pairs(value) do
            count = count + 1
            if type(key) ~= 'number' then isArray = false end
        end
        if isArray and count == #value then return 'array' end
    end
    return luaType
end

local function matchesType(value, expected)
    if expected == 'any' then return true end
    if expected == 'integer' then
        return type(value) == 'number' and value % 1 == 0
    end
    if expected == 'array' then
        return typeName(value) == 'array'
    end
    if expected == 'table' then
        return type(value) == 'table'
    end
    return type(value) == expected
end

local validateValue

---@param value any
---@param spec table
---@param path string
---@param issues table[]
---@return any coerced
local function validateTable(value, spec, path, issues)
    local out = {}
    local strict = spec.strict ~= false

    for key, fieldSpec in pairs(spec.fields or {}) do
        local childPath = path == '' and key or (path .. '.' .. key)
        out[key] = validateValue(value[key], fieldSpec, childPath, issues)
    end

    if strict and spec.fields then
        for key in pairs(value) do
            if spec.fields[key] == nil then
                addIssue(issues, path == '' and tostring(key) or (path .. '.' .. tostring(key)),
                    'UNKNOWN_KEY')
            end
        end
    end

    if not spec.fields then return value end
    return out
end

---@param value any
---@param spec table
---@param path string
---@param issues table[]
---@return any coerced
function validateValue(value, spec, path, issues)
    if value == nil then
        if spec.default ~= nil then
            if type(spec.default) == 'table' then return tbl.deepCopy(spec.default) end
            return spec.default
        end
        if not spec.optional then
            addIssue(issues, path, 'REQUIRED', { expected = spec.type })
        end
        return nil
    end

    if not matchesType(value, spec.type) then
        addIssue(issues, path, 'TYPE', { expected = spec.type, got = typeName(value) })
        return value
    end

    if spec.enum then
        local found = false
        for _, allowed in ipairs(spec.enum) do
            if allowed == value then found = true break end
        end
        if not found then
            addIssue(issues, path, 'ENUM', { expected = spec.enum, got = value })
        end
    end

    if type(value) == 'number' then
        if spec.min and value < spec.min then
            addIssue(issues, path, 'RANGE', { min = spec.min, got = value })
        end
        if spec.max and value > spec.max then
            addIssue(issues, path, 'RANGE', { max = spec.max, got = value })
        end
    end

    if type(value) == 'string' then
        local length = #value
        if spec.minLen and length < spec.minLen then
            addIssue(issues, path, 'LENGTH', { minLen = spec.minLen, got = length })
        end
        if spec.maxLen and length > spec.maxLen then
            addIssue(issues, path, 'LENGTH', { maxLen = spec.maxLen, got = length })
        end
        if spec.pattern and not value:match(spec.pattern) then
            addIssue(issues, path, 'PATTERN', { pattern = spec.pattern })
        end
    end

    if spec.type == 'array' then
        local length = #value
        if spec.minLen and length < spec.minLen then
            addIssue(issues, path, 'LENGTH', { minLen = spec.minLen, got = length })
        end
        if spec.maxLen and length > spec.maxLen then
            addIssue(issues, path, 'LENGTH', { maxLen = spec.maxLen, got = length })
        end
        if spec.items then
            local out = {}
            for index = 1, length do
                out[index] = validateValue(value[index], spec.items,
                    ('%s[%d]'):format(path, index), issues)
            end
            return out
        end
        return value
    end

    if spec.type == 'table' then
        return validateTable(value, spec, path, issues)
    end

    return value
end

---Validál egy értéket séma szerint.
---@param value any
---@param spec table
---@param rootPath? string   a hibaüzenetekben megjelenő gyökér-útvonal
---@return NovaResult        ok: a kiegészített érték (default-okkal), err: 'SCHEMA_INVALID'
function schema.validate(value, spec, rootPath)
    local issues = {}
    local coerced = validateValue(value, spec, rootPath or '', issues)

    if #issues > 0 then
        return Result.err('SCHEMA_INVALID', { issues = issues })
    end
    return Result.ok(coerced)
end

---Emberi olvasásra szánt hibalista. A végleges, felhasználónak szánt szöveget
---a nova_locale rendereli — ez a konzol- és CI-kimenethez van.
---@param issues table[]
---@return string
function schema.describe(issues)
    local lines = {}
    for _, issue in ipairs(issues) do
        local where = issue.path ~= '' and issue.path or '<root>'
        if issue.code == 'REQUIRED' then
            lines[#lines + 1] = ('%s: kötelező mező hiányzik (várt típus: %s)')
                :format(where, tostring(issue.expected))
        elseif issue.code == 'TYPE' then
            lines[#lines + 1] = ('%s: várt típus %s, kapott %s')
                :format(where, tostring(issue.expected), tostring(issue.got))
        elseif issue.code == 'RANGE' then
            lines[#lines + 1] = ('%s: tartományon kívüli érték (%s), határ: %s')
                :format(where, tostring(issue.got), tostring(issue.min or issue.max))
        elseif issue.code == 'LENGTH' then
            lines[#lines + 1] = ('%s: hossz %s, határ: %s')
                :format(where, tostring(issue.got), tostring(issue.minLen or issue.maxLen))
        elseif issue.code == 'ENUM' then
            lines[#lines + 1] = ('%s: nem engedett érték (%s)'):format(where, tostring(issue.got))
        elseif issue.code == 'PATTERN' then
            lines[#lines + 1] = ('%s: nem felel meg a mintának (%s)'):format(where, issue.pattern)
        elseif issue.code == 'UNKNOWN_KEY' then
            lines[#lines + 1] = ('%s: ismeretlen kulcs (elgépelés?)'):format(where)
        else
            lines[#lines + 1] = ('%s: %s'):format(where, issue.code)
        end
    end
    return table.concat(lines, '\n')
end

Nova.schema = schema
return schema
