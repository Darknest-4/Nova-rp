fx_version 'cerulean'
game 'gta5'

name 'nova_bootstrap'
description 'NOVA RP — indulási ellenőrzés és startup banner (Phase 2 füstteszt)'
author 'NOVA RP'
version '0.1.0'
repository 'https://github.com/Darknest-4/Nova-rp'

server_scripts {
    'server/boot.lua',
}

--[[
    Minimális FXServer build: 12739.

    Indoklás: a `setr sv_stateBagStrictMode` convar — amivel megtiltjuk, hogy a
    kliens replikált state baget írjon — a hivatalos dokumentáció szerint a
    12739-es szerververzióban jelent meg. Ez a NOVA RP kötelező biztonsági
    beállítása (lásd docs/01-architecture/security.md 3.), ezért a projekt
    egésze ezt tekinti alsó határnak.

    Ez a szám a Phase 26 (load test) után felülvizsgálandó: mindig a Cfx által
    ajánlott ('recommended') artifactot futtatjuk, ami ennél jóval újabb.
]]
dependencies {
    '/server:12739',
    '/onesync',
    'nova_lib',
}
