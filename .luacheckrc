-- luacheck konfiguráció a NOVA RP Lua kódjához.
-- Futtatás:  luacheck resources tests

std = 'lua54'
max_line_length = 120
codes = true

-- A CitizenFX runtime globális függvényei. Ezek a szerveren léteznek, de a
-- luacheck nem tud róluk. A lista SZŰK szándékosan: ha egy natívot használni
-- akarsz, vedd fel ide — így a lista dokumentálja, mire támaszkodunk.
read_globals = {
    -- Alap
    'CreateThread', 'Wait', 'SetTimeout', 'Citizen',
    'GetCurrentResourceName', 'GetResourceMetadata', 'GetResourceState',
    'LoadResourceFile', 'SaveResourceFile',
    -- Convarok (csak szerveroldal)
    'GetConvar', 'GetConvarInt', 'SetConvar',
    -- Eventek
    'AddEventHandler', 'RegisterNetEvent', 'TriggerEvent',
    'TriggerServerEvent', 'TriggerClientEvent', 'RemoveEventHandler',
    -- Parancsok és exportok
    'RegisterCommand', 'exports', 'GetInvokingResource',
    -- Játékos / entitás (szerveroldali használat)
    'GetPlayers', 'GetPlayerName', 'GetPlayerIdentifiers', 'GetPlayerPed',
    'GetEntityCoords', 'DoesEntityExist', 'DeleteEntity',
    'SetEntityRoutingBucket', 'SetPlayerRoutingBucket', 'SetEntityOrphanMode',
    -- State bag
    'Entity', 'Player', 'GlobalState', 'LocalPlayer',
    -- JSON (CitizenFX beépített)
    'json',
    -- HTTP
    'SetHttpHandler', 'PerformHttpRequest',
}

-- A NOVA globális névtere. Ez az EGYETLEN globálisunk — minden más modul
-- ez alá kerül (lásd docs/01-architecture/overview.md 7.).
globals = { 'Nova' }

-- Az fxmanifest.lua nem közönséges Lua: deklaratív DSL, amit az FXServer
-- külön runtime-ban futtat. A direktívái így nem "ismeretlen globálisok".
files['**/fxmanifest.lua'] = {
    read_globals = {
        'fx_version', 'game', 'games', 'name', 'description', 'author', 'version',
        'repository', 'lua54', 'node_version', 'use_experimental_fxv2_oal',
        'shared_script', 'shared_scripts', 'client_script', 'client_scripts',
        'server_script', 'server_scripts', 'dependency', 'dependencies',
        'provide', 'ui_page', 'files', 'data_file', 'escrow_ignore',
        'convar_category', 'this_is_a_map', 'rdr3_warning',
        -- NOVA-specifikus metaadat
        'nova_locales',
    },
}

files['tests/**/*.lua'] = {
    -- A busted DSL globálisai.
    read_globals = {
        'describe', 'it', 'before_each', 'after_each',
        'setup', 'teardown', 'assert', 'spy', 'stub', 'mock', 'pending',
    },
    globals = { 'Nova', 'GetConvar', 'GetConvarInt', 'GetCurrentResourceName',
                'TriggerClientEvent', 'LoadResourceFile' },
}

-- A vendor/ tartalma nem a mi kódunk: módosítatlanul telepítjük.
exclude_files = {
    -- A szögletes zárójel a glob-mintában karakterosztályt jelentene,
    -- ezért escape-elve: [[] = egy '[' karakter.
    'resources/[[]vendor[]]/**',
    'tools/node_modules/**',
}
