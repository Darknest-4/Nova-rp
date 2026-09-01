--[[
    nova_lib :: Result
    ---------------------------------------------------------------------------
    Tipizált siker/hiba visszatérési érték.

    Miért nem `nil, 'hibaüzenet'`?
      - A hibaüzenet szöveg lenne, azt viszont nem lehet lokalizálni.
        A Result hibakódot + paramétereket hordoz, amiből a kliens a saját
        nyelvén rendereli a szöveget (lásd docs/01-architecture/localization.md).
      - A hívó nem tudja "véletlenül" figyelmen kívül hagyni: az `unwrap()`
        hibát dob, ha hibás Resultot próbálsz kicsomagolni.

    Ez a modul szándékosan nem hív natívot, így FXServer nélkül is tesztelhető.
]]

local Nova = rawget(_G, 'Nova') or {}
_G.Nova = Nova

---@class NovaResult
---@field ok boolean
---@field value any            csak ok = true esetén
---@field code string|nil      csak ok = false esetén, pl. 'FEATURE_DISABLED'
---@field details table|nil    hibakód paraméterei (lokalizációhoz és loghoz)
local Result = {}
Result.__index = Result

---Sikeres eredmény.
---@param value any
---@return NovaResult
function Result.ok(value)
    return setmetatable({ ok = true, value = value }, Result)
end

---Hibás eredmény.
---@param code string        stabil, nyelvfüggetlen hibakód (SCREAMING_SNAKE_CASE)
---@param details? table     a hibakódhoz tartozó paraméterek
---@return NovaResult
function Result.err(code, details)
    if type(code) ~= 'string' or code == '' then
        error('Result.err: a hibakód nem lehet üres string', 2)
    end
    return setmetatable({ ok = false, code = code, details = details }, Result)
end

---Igaz, ha az érték Result példány.
---@param value any
---@return boolean
function Result.is(value)
    return getmetatable(value) == Result
end

---@return boolean
function Result:isOk()
    return self.ok == true
end

---@return boolean
function Result:isErr()
    return self.ok == false
end

---Kicsomagolja az értéket. Hibás Result esetén hibát dob — ezt csak ott
---használd, ahol a hiba tényleg programozói hiba lenne.
---@return any
function Result:unwrap()
    if not self.ok then
        error(('Result:unwrap() hibás eredményen: %s'):format(self.code), 2)
    end
    return self.value
end

---Kicsomagolja az értéket, hiba esetén az alapértelmezettet adja vissza.
---@param default any
---@return any
function Result:unwrapOr(default)
    if not self.ok then return default end
    return self.value
end

---Sikeres érték átalakítása. Hiba esetén változatlanul továbbadja a hibát.
---@param fn fun(value: any): any
---@return NovaResult
function Result:map(fn)
    if not self.ok then return self end
    return Result.ok(fn(self.value))
end

---Láncolás: a függvény maga is Resultot ad vissza.
---@param fn fun(value: any): NovaResult
---@return NovaResult
function Result:andThen(fn)
    if not self.ok then return self end
    local next = fn(self.value)
    if not Result.is(next) then
        error('Result:andThen: a függvénynek Resultot kell visszaadnia', 2)
    end
    return next
end

---Naplózható/olvasható alak.
---@return string
function Result:__tostring()
    if self.ok then
        return ('Result.ok(%s)'):format(tostring(self.value))
    end
    return ('Result.err(%s)'):format(self.code)
end

Nova.Result = Result
return Result
