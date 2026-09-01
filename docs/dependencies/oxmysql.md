# Függőség-adatlap — oxmysql

| Mező | Érték |
| --- | --- |
| **Repository** | https://github.com/overextended/oxmysql |
| **Rögzített verzió** | `v2.14.1` |
| **SHA-256 (release zip)** | `29fa0992174257f548dc1ef8dc9431fd1ce995696b5c58fbe98ca0cb6a0e6aba` |
| **Licenc** | **LGPL-3.0-or-later** (a repo `LICENSE` fájlja alapján) |
| **Karbantartottság** | Aktív — utolsó ellenőrzött commit: 2026-07-03 |
| **Ellenőrzés dátuma** | 2026-08-27 |
| **Telepítés** | `nova vendor:install` (letöltés + checksum + kicsomagolás) |

## Mire használjuk

MySQL/MariaDB elérés. Az `oxmysql` a `node-mysql2` köré épül, és a szerveroldali
Node runtime-ban fut. Amit ad: aszinkron, nem blokkoló lekérdezések, prepared
statement / named placeholder támogatás, kapcsolatkezelés.

**A NOVA kód soha nem hívja közvetlenül.** Mindig a `nova_db` réteg mögül,
amely hozzáteszi: a lekérdezés-metrikákat, a lassú query naplózását, a
write-behind cache-t, a tranzakció-segédeket és a hibakezelést. Ez teszi
lehetővé, hogy az `oxmysql` később kiváltható legyen anélkül, hogy száz
helyen kellene kódot átírni.

## Miért MySQL/MariaDB, és nem PostgreSQL

Az `oxmysql` (és vele az egész FiveM-ökoszisztéma) MySQL-protokollra épül.
PostgreSQL-hez saját drivert kellene írnunk és minden későbbi integrációt
elveszítenénk. Ez tudatos kompromisszum — lásd
[docs/01-architecture/database.md](../01-architecture/database.md) 1. pont.

## Licenc-következmények

LGPL-3.0: a NOVA saját kódja nem válik copyleft-kötelessé attól, hogy használja.
Módosítatlanul, a licencszöveggel együtt terjesztjük.

## Kockázatok és exit-terv

| Kockázat | Kezelés |
| --- | --- |
| Karbantartás leállása | A `nova_db` absztrakció miatt saját `node-mysql2` wrapperre cserélhető |
| Teljesítmény-probléma nagy CCU-nál | A `nova_db` méri a query-latenciát; a Phase 26 load teszt ezt külön vizsgálja |
| Sérült/kicserélt release-csomag | SHA-256 ellenőrzés a telepítéskor |
| Kapcsolati string a repóba kerül | A `mysql_connection_string` kizárólag a gitignore-olt `server/cfg/90-local.cfg`-ben él |

## Frissítési eljárás

Azonos az `ox_lib`-nél leírttal: verzió + checksum a `vendor.json`-ban,
adatlap frissítése, teljes tesztkészlet, külön PR.
