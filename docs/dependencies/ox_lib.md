# Függőség-adatlap — ox_lib

| Mező | Érték |
| --- | --- |
| **Repository** | https://github.com/overextended/ox_lib |
| **Rögzített verzió** | `v3.39.0` |
| **SHA-256 (release zip)** | `1df6724dfc1d2d287299ff023a29c9e999eb77832cb918a4f1761d5c18a54501` |
| **Licenc** | **LGPL-3.0-or-later** (a repo `LICENSE` fájlja és az `fxmanifest.lua` `license` mezője egyaránt ezt mondja) |
| **Karbantartottság** | Aktív — utolsó ellenőrzött commit: 2026-08-17 |
| **Ellenőrzés dátuma** | 2026-08-27 |
| **Telepítés** | `nova vendor:install` (letöltés + checksum + kicsomagolás) |

## Mire használjuk

- UI-komponensek (context menü, input dialógus, notifikáció-alap, progress bar)
- Cache- és callback-segédek
- Zóna-kezelés (poly/box/sphere)
- Fejlesztői kényelmi függvények (`lib.print`, típusdefiníciók)

## Mire NEM használjuk

**A lokalizációra.** Ellenőriztük a forrását: az `ox_lib` locale modulja
szerveroldalon egyetlen, globális nyelvet ismer:

```lua
-- ox_lib/resource/locale/server.lua
function lib.getLocaleKey() return GetConvar('ox:locale', 'en') end
```

A NOVA RP viszont **játékosonként** külön nyelvet követel meg, futásidejű
váltással. Ezt a `nova_locale` valósítja meg — lásd
[docs/01-architecture/localization.md](../01-architecture/localization.md).

## Licenc-következmények

Az LGPL-3.0 célja, hogy a könyvtárat használó, de attól elkülönülő mű ne
kerüljön automatikusan ugyanazon licenc alá.

- A NOVA RP saját kódja **nem** válik LGPL-essé attól, hogy használja.
- Az `ox_lib`-et **módosítatlanul**, a licencszövegével és attribúciójával
  együtt terjesztjük — ezért is telepítjük release-csomagból, és nem
  másoljuk be a repóba szerkeszthető formában.
- Ha valaha módosítanunk kellene, a módosítás kerül LGPL alá, és közzé kell
  tenni. Ilyen esetben előbb próbáljunk upstream PR-t nyitni.

## Kockázatok és exit-terv

| Kockázat | Kezelés |
| --- | --- |
| A projekt karbantartása leáll | A pinelt verzió tovább működik; a használt felület szűk, saját megvalósítás reális |
| Törő változás új verzióban | A verzió pinelt; frissítés csak külön PR-ben, diff-áttekintéssel |
| Sérült/kicserélt release-csomag | SHA-256 ellenőrzés a telepítéskor — eltérés esetén a telepítés megáll |
| Túlzott függés | A NOVA kód közvetlenül csak az UI- és zóna-felületet hívja; a többit saját modul burkolja |

## Frissítési eljárás

1. Új verzió és annak SHA-256 összegének megállapítása
2. `vendor.json` frissítése (verzió + asset URL + checksum)
3. Ennek az adatlapnak a frissítése (verzió, dátum, változás-jegyzet)
4. `nova vendor:install` + teljes tesztkészlet
5. Külön PR, diff-áttekintéssel — **soha ne közös PR-ben gameplay-változással**
