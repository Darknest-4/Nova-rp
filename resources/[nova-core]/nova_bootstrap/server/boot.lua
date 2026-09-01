--[[
    nova_bootstrap :: boot
    ---------------------------------------------------------------------------
    A Phase 2 füsttesztje: bizonyítja, hogy a szerver elindul, a nova_lib
    betöltődött, és a kötelező beállítások a helyükön vannak.

    Ez NEM a végleges health check. Azt a nova_health valósítja meg (Phase 3),
    teljes ellenőrző készlettel és HTTP végponttal. Ez itt szándékosan kevés:
    annyit tud, amennyit a Phase 2-ben bizonyítani akarunk.

    Amit ellenőriz:
      1. a nova_lib API elérhető-e
      2. a kötelező identitás-convarok be vannak-e állítva (branding nincs kódban)
      3. a kötelező biztonsági convarok a dokumentált értéken vannak-e
]]

local RESOURCE = GetCurrentResourceName()

---A boot-ellenőrzés eredménye. Rétegenként: név, státusz, üzenet.
---@type { name: string, status: 'ok'|'warn'|'fail', message: string }[]
local report = {}

local function record(name, status, message)
    report[#report + 1] = { name = name, status = status, message = message }
end

---A dokumentált, kötelező biztonsági beállítások.
---Forrás: docs/01-architecture/security.md 3. pont.
---A `setr sv_stateBagStrictMode` replikált convar, ezért `GetConvar` olvassa.
local REQUIRED_SECURITY = {
    { key = 'sv_scriptHookAllowed',  expected = 'false',  reason = 'ScriptHook = azonnali sebezhetőség' },
    { key = 'sv_entityLockdown',     expected = 'strict', reason = 'a kliens ne hozhasson létre entitást' },
    { key = 'sv_stateBagStrictMode', expected = 'true',   reason = 'a kliens ne írhasson replikált state baget' },
}

---A `sv_scriptHookAllowed` 0/1 és false/true alakban is előfordul.
local function normalizeBool(value)
    value = tostring(value):lower()
    if value == '1' or value == 'true' or value == 'yes' then return 'true' end
    if value == '0' or value == 'false' or value == 'no' then return 'false' end
    return value
end

local function checkLib()
    if type(Nova) ~= 'table' or type(Nova.Result) ~= 'table' or type(Nova.schema) ~= 'table' then
        record('nova_lib', 'fail',
            'a nova_lib nem töltődött be — ellenőrizd az ensure sorrendet a cfg/20-resources.cfg-ben')
        return false
    end

    -- Élő füstteszt: a séma-validátor tényleg működik-e ebben a runtime-ban.
    local probe = Nova.schema.validate({ port = 3306 }, {
        type = 'table',
        fields = { port = { type = 'integer', min = 1, max = 65535 } },
    })
    if not probe:isOk() then
        record('nova_lib', 'fail', 'a séma-validátor önellenőrzése megbukott')
        return false
    end

    record('nova_lib', 'ok', 'betöltve, séma-validátor működik')
    return true
end

local function checkIdentity()
    local name = GetConvar('nova:server:name', '')
    local environment = GetConvar('nova:environment', '')

    if name == '' then
        record('identity', 'fail',
            'a nova:server:name convar nincs beállítva (server/cfg/00-base.cfg)')
        return
    end

    local validEnvironments = { development = true, staging = true, production = true }
    if not validEnvironments[environment] then
        record('identity', 'fail', ('érvénytelen nova:environment: "%s" — várt: development | staging | production')
            :format(environment))
        return
    end

    record('identity', 'ok', ('%s · %s'):format(name, environment))
end

local function checkSecurity()
    local problems = {}
    for _, rule in ipairs(REQUIRED_SECURITY) do
        local actual = normalizeBool(GetConvar(rule.key, '<nincs beállítva>'))
        if actual ~= rule.expected then
            problems[#problems + 1] = ('%s = %s (várt: %s — %s)')
                :format(rule.key, actual, rule.expected, rule.reason)
        end
    end

    if #problems > 0 then
        record('security', 'fail', table.concat(problems, ' | '))
        return
    end
    record('security', 'ok', ('%d kötelező beállítás rendben'):format(#REQUIRED_SECURITY))
end

---A startup banner. Production-ben szándékosan kevesebbet ír ki:
---a szerver állapota nem felderítési információ egy támadónak.
local function printBanner()
    local environment = GetConvar('nova:environment', 'unknown')
    local isProduction = environment == 'production'
    local name = GetConvar('nova:server:name', '(nincs beállítva)')
    local version = GetResourceMetadata(RESOURCE, 'version', 0) or '0.0.0'

    local lines = {
        '',
        '  ███ ' .. name,
        ('  %s %s'):format(Nova.str.padRight('Verzió:', 14), version),
        ('  %s %s'):format(Nova.str.padRight('Környezet:', 14), environment),
    }

    for _, entry in ipairs(report) do
        local mark = entry.status == 'ok' and 'OK' or (entry.status == 'warn' and 'FIGYELEM' or 'HIBA')
        local detail = (isProduction and entry.status == 'ok') and '' or ('  — ' .. entry.message)
        lines[#lines + 1] = ('  %s %s%s')
            :format(Nova.str.padRight(entry.name .. ':', 14), mark, detail)
    end

    lines[#lines + 1] = ''
    print(table.concat(lines, '\n'))
end

---A boot-riport lekérdezhető más resource-okból (a nova_health veszi majd át).
---@return table
exports('getBootReport', function()
    return Nova.tbl.deepCopy(report)
end)

CreateThread(function()
    if not checkLib() then
        -- A nova_lib nélkül a többi ellenőrzés értelmezhetetlen lenne.
        print(('\n  [NOVA][FATAL] %s\n'):format(report[1].message))
        return
    end

    checkIdentity()
    checkSecurity()
    printBanner()

    for _, entry in ipairs(report) do
        if entry.status == 'fail' then
            print(('[NOVA][FATAL] %s: %s'):format(entry.name, entry.message))
            print('[NOVA] Dokumentáció: QUICKSTART.md · docs/01-architecture/security.md')
        end
    end
end)
