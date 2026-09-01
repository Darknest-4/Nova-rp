fx_version 'cerulean'
game 'gta5'

name 'nova_lib'
description 'NOVA RP — alapkönyvtár: Result, tábla-segédek, séma-validátor, convar-olvasás'
author 'NOVA RP'
version '0.1.0'
repository 'https://github.com/Darknest-4/Nova-rp'

-- Megjegyzés: a `lua54 'yes'` direktíva a hivatalos dokumentáció szerint
-- deprecated — 2025 júniusa óta minden Lua szkript 5.4-en fut.
-- Ezért szándékosan nem szerepel itt.

-- A betöltési sorrend KÖTÖTT: a schema.lua a result.lua-ra és a tbl.lua-ra épül.
shared_scripts {
    'shared/result.lua',
    'shared/tbl.lua',
    'shared/str.lua',
    'shared/schema.lua',
}

server_scripts {
    'shared/env.lua', -- convarok csak szerveroldalon olvashatók
}

-- A projekt egészére vonatkozó minimális FXServer build a nova_bootstrap
-- manifestjében van kimondva, indoklással. Ez a modul önmagában csak
-- OneSync-et igényel.
dependencies {
    '/onesync',
}
