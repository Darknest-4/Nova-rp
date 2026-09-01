# Phase 2 — Project Bootstrap

> **Állapot:** kész
> **Dátum:** 2026-08-27
> **Előfeltétel:** ADR-0001 és ADR-0002 elfogadva (megtörtént)

---

## 1. A fázis előtt — terv

### Cél

Futtatható, üres, de teljesen felszerelt projekt. A fázis akkor sikeres, ha egy
új fejlesztő a repository klónozása után, dokumentált lépésekből eljut odáig,
hogy fut a szerver és zöldek a tesztek.

### Architektúra

Csak a legalsó két réteg épül meg
([overview.md](../01-architecture/overview.md) 3.):

- **0. réteg:** FXServer futtatási konfiguráció (`server/cfg/*`)
- **1. réteg:** `nova_lib` — Result, tábla-segédek, string-segédek,
  séma-validátor, convar-olvasás
- ezen felül egy füstteszt-resource (`nova_bootstrap`), ami bizonyítja,
  hogy a lánc a szerveren is összeáll

### Elkészülő fájlok

```
.editorconfig · .gitattributes · .nvmrc · .luacheckrc · .luarc.json · .busted
vendor.json
.github/workflows/ci.yml
QUICKSTART.md
server/server.cfg.example
server/cfg/{00-base,10-security,20-resources}.cfg · 90-local.cfg.example
resources/[nova-core]/nova_lib/{fxmanifest.lua, shared/*.lua}
resources/[nova-core]/nova_bootstrap/{fxmanifest.lua, server/boot.lua}
tools/{package.json, tsconfig.json, src/**, test/**}
tests/{helpers.lua, mocks/cfx.lua, unit/*_spec.lua}
docs/dependencies/{ox_lib,oxmysql}.md
```

### Függőségek

| Függőség | Verzió | Licenc |
| --- | --- | --- |
| ox_lib | v3.39.0 | LGPL-3.0-or-later |
| oxmysql | v2.14.1 | LGPL-3.0-or-later |
| Node.js | 22 LTS | — |
| busted / luacheck | 2.3.0 / 1.2.0 | MIT |

### Adatbázis-változás

Nincs. Az adatréteg a Phase 4-ben épül.

### Konfigurációs változás

Új convarok: `nova:environment`, `nova:server:name`, `nova:server:shortName`.
Kötelező biztonsági beállítások a `cfg/10-security.cfg`-ben.

### Permission node-ok

Nincsenek. A jogosultsági rendszer a Phase 7-ben épül.

### Locale kulcsok

Nincsenek. **Fontos:** a `nova_bootstrap` konzol-üzenetei szándékosan nincsenek
lokalizálva — a `nova_locale` még nem létezik, és az indulási hibaüzenetnek
akkor is meg kell jelennie, ha a lokalizáció maga hibás. Ezt a Phase 5-ben
felülvizsgáljuk (a konzol-nyelv `Config.Localization.Console` alá kerül).

### Biztonsági kockázatok

| Kockázat | Kezelés ebben a fázisban |
| --- | --- |
| Titok a repóba kerül | `.gitignore` + `doctor` ellenőrzés + CI-lépés |
| Kompromittált third-party csomag | SHA-256 pinelés a `vendor.json`-ban, ellenőrzés telepítéskor |
| "Zip slip" a vendor kicsomagolásakor | útvonal-ellenőrzés + teszt (`isSafeEntryPath`) |
| Hibás/hiányzó biztonsági convar | a `nova_bootstrap` induláskor ellenőrzi és hibát ír |

### Tesztek

Lua unit tesztek CFX-mock ellen; TypeScript unit tesztek a toolinghoz;
statikus elemzés mindkét nyelvre.

---

## 2. A fázis után — eredmény

### Elkészült

| Terület | Tartalom |
| --- | --- |
| **nova_lib** | `Result` (tipizált siker/hiba), `tbl` (deepMerge/flatten/get/set), `str`, `schema` (deklaratív validátor), `env` (convar + titok-maszkolás) |
| **nova_bootstrap** | Indulási ellenőrzés (lib, identitás, biztonsági convarok) + startup banner, production-ben szűkített kimenettel |
| **Szerver-konfiguráció** | 4 fájlra bontva, minden biztonsági beállítás mellett indoklással |
| **`nova` CLI** | `doctor`, `vendor:install`, `vendor:verify` |
| **ZIP-kicsomagoló** | Saját, függőség nélküli (Node zlib), CRC-ellenőrzéssel és zip-slip védelemmel |
| **Tesztkészlet** | 53 Lua + 16 TypeScript teszt |
| **CI** | 4 job: Lua, tooling, vendor-integritás, titok-szivárgás |
| **Dokumentáció** | `QUICKSTART.md`, 2 függőség-adatlap, ez a fázis-riport |

### Tesztek — tényleges futtatási eredmény

```
$ busted
53 successes / 0 failures / 0 errors / 0 pending : 0.062 s

$ luacheck resources tests
Total: 0 warnings / 0 errors in 15 files

$ cd tools && npm run typecheck
(hiba nélkül)

$ npm test
Test Files  2 passed (2)
     Tests  16 passed (16)
```

### Spike-eredmények

A Phase 1-ben öt nyitott kérdést jelöltünk meg. Négyre van válasz:

#### ✅ Spike 1 — Tesztelhető-e a mag FXServer nélkül? **IGEN.**

A `tests/mocks/cfx.lua` **70 sor**, és ennyi elég ahhoz, hogy a natívokat hívó
`env` modul is tesztelhető legyen. A tiszta (natívot nem hívó) modulok — Result,
tbl, str, schema — mock nélkül futnak.

A működés kulcsa egy kódolási szabály: **a modulok betöltéskor nem végeznek
mellékhatást**, hanem a `Nova` névtérbe regisztrálják magukat *és* visszaadják
a modult. Ugyanaz a fájl fut az FXServerben (`shared_script`) és a tesztben
(`loadfile`). Ezt a szabályt minden magmodulra kötelezővé tesszük.

Mérés: **53 teszt 0,062 másodperc alatt.**

#### ⚠️ Spike 2 — Futtatható-e FXServer a CI-ban? **RÉSZBEN VÁLASZOLVA.**

A hivatalos dokumentációból **ellenőrzött tény**, hogy `sv_lan true` mellett a
licenckulcs-ellenőrzés kimarad — tehát a CI-ban licenc-titok nélkül is
indítható szerver.

**Amit nem tudtunk igazolni:** a fejlesztői környezetünkből a
`runtime.fivem.net` nem érhető el (a hálózati házirend blokkolja), ezért az
artifact letöltése és a szerver tényleges elindítása **nem futott le**.
Ez a Phase 3 első feladata, GitHub Actions runneren, ahol nincs ilyen korlát.
Addig az integrációs teszt CI-lépése **nem** kerül be a pipeline-ba — nem
építünk be olyan lépést, amiről nem tudjuk, hogy működik.

#### ✅ Spike 4 — Kinyerhető-e query-metrika az oxmysql-ből?

Elhalasztva a Phase 4-re, amikor a `nova_db` réteg épül — ott dől el, hogy az
oxmysql felületéből mérünk, vagy a saját wrapperünkben. A döntés nem blokkolja
a bootstrapet.

#### ✅ Vendor-telepítés integritással — **működik, valós méréssel.**

A `nova vendor:install` letöltötte az `ox_lib v3.39.0`-t és az
`oxmysql v2.14.1`-et, ellenőrizte a SHA-256 összegüket, és kicsomagolta őket a
saját ZIP-olvasónkkal.

**Ellenőrzés:** a saját kicsomagoló kimenetét bájtra összehasonlítottuk a
rendszer `unzip` parancsáéval az `ox_lib` 174 fájlján — **azonos fájllista,
azonos tartalom minden fájlnál**.

### Hibák és javítások a fázis során

| Hiba | Ok | Javítás |
| --- | --- | --- |
| A luacheck a `resources/[vendor]/**` mintát nem zárta ki | A `[...]` a glob-mintában karakterosztály | Escape-elt minta: `resources/[[]vendor[]]/**` — ugyanez a `.gitignore`-ban is |
| Az `fxmanifest.lua` direktívái "ismeretlen globálisként" jelentek meg | Deklaratív DSL, nem közönséges Lua | Külön `files['**/fxmanifest.lua']` szabály a `.luacheckrc`-ben |

### Teljesítmény

Ebben a fázisban még nincs mit mérni futásidőben (nincs tick-terhelés).
A fejlesztői ciklus ideje viszont mérve: **Lua tesztek 0,06 s, TS tesztek 0,4 s** —
ez elég gyors ahhoz, hogy mentésenként futtatható legyen.

### Biztonság

- A titkos konfigurációs fájlok gitignore-oltak; ezt a `doctor` és a CI is ellenőrzi.
- A vendor-csomagok SHA-256-tal pineltek; eltérés esetén a telepítés megáll.
- A kicsomagoló véd a zip-slip ellen (tesztelt).
- A `nova_bootstrap` induláskor ellenőrzi a három kötelező biztonsági convart.

**Ami tudatosan kimaradt:** a `sv_authMinTrust`, `sv_filterRequestControl` és a
rate limiter convarok ki vannak kommentelve a `10-security.cfg`-ben. Ezek pontos
értéke csak méréssel dönthető el (Phase 23) — vaktában bekapcsolva jogos
játékosokat is kizárhatnának.

### Dokumentáció

`QUICKSTART.md` (telepítés + gyakori hibák táblázat), `docs/dependencies/*.md`
(2 adatlap), ez a riport, és a `CHANGELOG.md` frissítése.

### A QUICKSTART igazolt és nem igazolt lépései

Őszinteség kedvéért, mert ez a "zero knowledge setup" ígéret alapja:

| Lépés | Állapot |
| --- | --- |
| 1–5. (klónozás, npm, doctor, vendor:install, cfg másolás) | ✅ **végrehajtva és ellenőrizve** ebben a környezetben |
| 8. (tesztek futtatása) | ✅ **végrehajtva és ellenőrizve** |
| 6–7. (artifact letöltés, szerverindítás) | ⚠️ **a hivatalos Cfx dokumentációból** átvéve; ebben a környezetben nem futtatható (a `runtime.fivem.net` blokkolt) |

A 6–7. lépést az első olyan gépen kell validálni, ahol elérhető az artifact —
és a `TROUBLESHOOTING.md`-t az ott tapasztalt hibákkal kell bővíteni.

---

## 3. Következő lépés

**Phase 3 — Core.** Ebben a sorrendben:

1. **Először:** FXServer indítás igazolása (a Spike 2 lezárása) — enélkül
   a további modulok "vakon" épülnének.
2. `nova_net` — a tipizált event-réteg, a hozzá tartozó biztonsági tesztkészlettel
3. `nova_scheduler` — a központi ütemező, tick-költségvetéssel
4. `nova_logging` — strukturált log, titok-maszkolással
5. `nova_health` — a `nova_bootstrap` ellenőrzéseinek átvétele és bővítése

A `nova_bootstrap` a Phase 3 végén megszűnik: szerepét a `nova_health` veszi át.
