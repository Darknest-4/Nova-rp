# Changelog

A projekt minden lényeges változása itt kerül rögzítésre.

A formátum a [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) ajánlását követi,
a verziózás a [Semantic Versioning](https://semver.org/spec/v2.0.0.html) szerint történik.

## [Unreleased]

### Added — Phase 2: Project Bootstrap

- **`nova_lib` magkönyvtár** (`resources/[nova-core]/nova_lib/`):
  - `Result` — tipizált siker/hiba érték nyelvfüggetlen hibakóddal (nem szöveggel),
    hogy a hibaüzenetek lokalizálhatók legyenek
  - `tbl` — `deepMerge`, `deepCopy` (ciklus-biztos), `flatten`, `get`/`set`
    pont-útvonallal, determinisztikus `sortedKeys`
  - `str` — `trim`, `split`, `startsWith`/`endsWith`, `interpolate`, `padRight`
  - `schema` — deklaratív validátor: típus, tartomány, hossz, minta, enum,
    beágyazott mezők, tömbök, alapértékek, **ismeretlen kulcs elutasítása**;
    minden hibát összegyűjt, nem áll meg az elsőnél
  - `env` — tipizált convar-olvasás, kötelező titkok ellenőrzése, titok-maszkolás
- **`nova_bootstrap`** — indulási ellenőrzés (könyvtár, identitás, kötelező
  biztonsági convarok) és startup banner, production-ben szűkített kimenettel.
- **Szerver-konfiguráció** négy fájlra bontva (`server/cfg/`), minden biztonsági
  beállításnál indoklással; a titkok a gitignore-olt `90-local.cfg`-be kerülnek.
- **`nova` CLI** (`tools/`, Node 22 + TypeScript):
  - `doctor` — környezet-ellenőrzés, minden hiányhoz pontos javító paranccsal
  - `vendor:install` — függőségek telepítése rögzített verzióból,
    **SHA-256 integritás-ellenőrzéssel**
  - `vendor:verify` — telepítés és függőség-adatlapok megléte
  - saját, függőség nélküli ZIP-kicsomagoló CRC-ellenőrzéssel és
    zip-slip elleni védelemmel (a kimenete bájtra megegyezik a rendszer `unzip`-ével)
- **Tesztkészlet:** 53 Lua unit teszt (busted, FXServer nélkül, CFX-mock ellen)
  és 16 TypeScript teszt (vitest). Futásidő: 0,06 s + 0,4 s.
- **CI** (`.github/workflows/ci.yml`): Lua lint és teszt, tooling típusellenőrzés
  és teszt, vendor-integritás, titok-szivárgás ellenőrzése.
- **Dokumentáció:** `QUICKSTART.md`, `docs/phases/phase-02-bootstrap.md`,
  `docs/dependencies/{ox_lib,oxmysql}.md`.
- Fejlesztői konfiguráció: `.editorconfig`, `.gitattributes`, `.nvmrc`,
  `.luacheckrc`, `.luarc.json`, `.busted`.

### Fixed

- **CI:** a `--local` luarocks-telepítés után a `busted` nem találta a saját
  moduljait; a `LUA_PATH`/`LUA_CPATH` átadása megoldja.
- **CI:** `npm audit` — a `vitest 2.x` sérülékeny `vite`/`esbuild` verziót hozott
  magával. Frissítve `vitest 4.1.11`-re: 0 sebezhetőség, az audit-küszöb változatlan.

  A javítások után a CI mind a négy jobja zöld (`run #2`).

### Changed

- **ADR-0001…0004 elfogadva.** Célplatform: FiveM Legacy, Enhanced-kompatibilis
  kódolási szabályokkal. Alap: saját NOVA mag + LGPL könyvtárak (nem GPL-3.0
  framework). Hosting: dev/staging Linux, a production platform mérés után dől el.
  Skálázás: egy világ, shard-tudatos adatmodellel.
- A vendor-függőségeket **nem verziókövetjük**: a `vendor.json` rögzíti a verziót
  és a checksumot, a telepítés ellenőrzött letöltésből történik.

### Ismert korlát

- Az FXServer tényleges elindítása ebben a fejlesztői környezetben nem volt
  futtatható (a `runtime.fivem.net` hálózati okból elérhetetlen), ezért a
  `QUICKSTART.md` 6–7. lépése a hivatalos Cfx dokumentációból származik, nem
  saját végrehajtásból. Ennek igazolása a Phase 3 első feladata.

### Added — Phase 0–1: Research & Architecture

- **Phase 0 — Research.** A jelenlegi FiveM / Cfx.re környezet feltérképezése a
  hivatalos dokumentáció forrásrepository-ja alapján
  (`citizenfx/fivem-docs`, HEAD `87d92b2`, 2026-08-20):
  - `docs/00-research/platform-research.md` — ellenőrzött platform-tények
    (OneSync limitek, Legacy vs. Enhanced, runtime-ok, biztonsági convarok,
    txAdmin, deferrals, pool-limitek), forrásokkal és bizonyossági szinttel.
  - `docs/00-research/scale-analysis.md` — a 2000 slot / 1000 CCU cél elemzése,
    architektúra-opciók, tervezési szabályok, mérési terv.
  - `docs/00-research/dependencies.md` — third-party függőségek ellenőrzött verzióval,
    licenccel és kockázattal; döntési mátrix a framework-alapról.
- **Phase 1 — Architecture.** Teljes architektúra-terv implementáció előtt:
  - `docs/01-architecture/overview.md` — tech stack, rétegek, modultérkép,
    boot-sorrend, project tree, névkonvenciók.
  - `docs/01-architecture/configuration.md` — konfigurációs rétegek, séma-validáció,
    feature flag rendszer, branding.
  - `docs/01-architecture/localization.md` — per-player lokalizáció, fallback-lánc,
    plural-kezelés, futásidejű nyelvváltás, validátor.
  - `docs/01-architecture/permissions.md` — RBAC node-okkal, örökléssel, lejárattal,
    scope-pal és audittal.
  - `docs/01-architecture/database.md` — sématerv, migrációk, tranzakciók,
    write-behind stratégia, backup.
  - `docs/01-architecture/security.md` — fenyegetésmodell, hatrétegű védelem,
    `nova_net` réteg, audit, incidenskezelés.
  - `docs/01-architecture/testing.md` — teszt-piramis, CFX-mock, CI, QA-kapuk.
  - `docs/01-architecture/deployment.md` — környezetek, release, rollback,
    monitoring, health check, disaster recovery.
- **Döntési dokumentumok** (`docs/decisions/`): ADR-0001 (célplatform),
  ADR-0002 (framework-alap), ADR-0003 (hosting platform), ADR-0004 (skálázás) —
  mind `Proposed` állapotban, jóváhagyásra várva.
- `docs/roadmap.md` — 28 fázis, mérföldkövek, becslések, fázis-protokoll.
- `docs/risks.md` — 14 tételes kockázati regiszter kezelési tervvel.

### Megjegyzés

Ebben a szakaszban **szándékosan nem készült gameplay kód.** A Phase 0 kimenete
kutatás és terv; az implementáció az ADR-0001 és ADR-0002 jóváhagyása után indul.
