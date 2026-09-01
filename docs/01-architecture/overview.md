# Architecture Overview

> Ez a dokumentum a NOVA RP platform szerkezetét írja le: tech stack, rétegek,
> modulok, indítási folyamat és a repository felépítése.
> Kapcsolódó részletes tervek: [configuration](configuration.md),
> [localization](localization.md), [permissions](permissions.md),
> [database](database.md), [security](security.md), [testing](testing.md),
> [deployment](deployment.md).

---

## 1. Alapelvek

1. **A kliens sosem authority.** Minden állapotváltozás szerveroldalon dől el.
2. **Semmi nincs kódba égetve**, ami szöveg, szám, jogosultság, URL vagy név.
3. **Minden modul ki/be kapcsolható**, és kikapcsolva nem fut, nem regisztrál eventet,
   nem hoz dependency-hibát.
4. **Minden modul tesztelhető** — a magmodulok FXServer nélkül is futtathatók.
5. **Kevés, jól strukturált resource**, nem sok apró script.
6. **Egyirányú függőségek.** A gameplay függ a magtól, a mag soha nem függ gameplay-től.
7. **Minden szerveroldali szöveg kulcs**, nem string.
8. **Fail fast, értelmes hibával.** Hibás konfiguráció mellett nem indulunk el
   félig működő állapotban.

## 2. Tech stack

| Réteg | Választás | Indoklás |
| --- | --- | --- |
| Szerver-runtime | **FXServer** (Cfx.re), OneSync Infinity | Platform adott |
| Gameplay nyelv | **Lua 5.4** (alapértelmezett runtime 2025 júniusa óta) | Natív hozzáférés, legkisebb overhead, legjobb ökoszisztéma |
| Típusellenőrzés Lua-hoz | **Lua Language Server** annotációk (`---@class`, `---@param`) + CI-ellenőrzés | Statikus hibák kiszűrése futásidő előtt |
| Lint | **selene** (vagy luacheck) + `.editorconfig` | Egységes kód, tiltott minták kikényszerítése |
| Unit teszt (Lua) | **busted** + saját CFX-mock réteg | A magmodulok játék nélkül tesztelhetők |
| NUI | **React 18 + TypeScript + Vite** | Komponens-alapú UI, gyors build, típusbiztos üzenetek |
| Tooling / CLI | **Node.js 22 LTS + TypeScript** | Locale validátor, migráció, config-validátor, release |
| Adatbázis | **MariaDB 11.4 LTS** (MySQL 8.4 LTS kompatibilis) | `oxmysql` = node-mysql2 → MySQL/MariaDB |
| DB-hozzáférés | **oxmysql** (LGPL) mögé rejtett saját `nova_db` réteg | Prepared statement, async, cserélhető |
| Cache (opcionális) | **Redis 7** | Csak ha külső panel vagy több példány lesz |
| Monitoring | **Prometheus** (`/perf` + node_exporter + mysqld_exporter) + **Grafana** | A `/perf` beépített, nem kell exportert írni |
| Logaggregáció | **Loki** (vagy fájl + rotáció, kis környezetben) | Strukturált JSON logok kereshetően |
| CI | **GitHub Actions** | A repo már ott van |
| Verziózás | **SemVer** + `CHANGELOG.md` (Keep a Changelog) | Kiírt követelmény |

**Amit szándékosan nem választunk:**

- ❌ **C# / .NET** — Legacy-n Mono, Enhanced-en .NET 10; kettős karbantartás,
  migrációs kockázat, nincs elég nyeresége Lua-hoz képest a mi eseteinkben.
- ❌ **Szerveroldali JS gameplay-hez** — Node 16 az alapértelmezett (22 opcionális),
  a natív hívások overhead-je és a runtime-váltás bonyolítja a profilozást.
  Node marad a **build- és tooling-oldalon**, ahol viszont kiváló.
- ❌ **ORM a gameplay-útvonalon** — kiszámíthatatlan query-k, rejtett N+1, mérhetetlen.

---

## 3. Rétegek

```
┌──────────────────────────────────────────────────────────────────┐
│ 4. FELÜLET               nova_hud · nova_ui · admin panel (NUI)  │
├──────────────────────────────────────────────────────────────────┤
│ 3. GAMEPLAY   player · inventory · money · vehicles · jobs ·     │
│               factions · police · ems · housing · business ·     │
│               phone · illegal                                     │
├──────────────────────────────────────────────────────────────────┤
│ 2. PLATFORM (nova_core)                                          │
│    config · locale · permission · db · net · logging ·           │
│    health · metrics · scheduler · world                          │
├──────────────────────────────────────────────────────────────────┤
│ 1. ALAP       nova_lib (típusok, Result, validátor, util)        │
│               vendor: ox_lib · oxmysql                            │
├──────────────────────────────────────────────────────────────────┤
│ 0. PLATFORM   FXServer · OneSync Infinity · MariaDB              │
└──────────────────────────────────────────────────────────────────┘
```

**Függőségi szabály:** egy réteg csak a nála alacsonyabb rétegtől függhet.
A CI ellenőrzi (statikus import/export-elemzéssel), hogy ez nem sérül.

### 3.1 Magmodulok (nova_core)

| Modul | Felelősség | Kikapcsolható? |
| --- | --- | --- |
| `nova_lib` | Típusdefiníciók, `Result`/`Error` típus, séma-validátor, string/table/math util, cache primitívek | ❌ (alap) |
| `nova_config` | Konfiguráció betöltése, rétegzése, séma-validálása; **feature flag rendszer** | ❌ |
| `nova_locale` | Lokalizációs runtime, per-player nyelv, fallback lánc, hot reload | ❌ |
| `nova_db` | Query-réteg oxmysql fölött; tranzakció, batch, write-behind cache, metrikák, migráció-ellenőrzés | ❌ |
| `nova_net` | **Tipizált event-réteg**: séma-validáció, rate limit, permission check, távolság-ellenőrzés, audit | ❌ |
| `nova_permission` | RBAC: node-ok, role-ok, öröklés, allow/deny, lejárat, cache, audit | ❌ |
| `nova_logging` | Strukturált log, log-szintek, audit log, Discord/webhook sink, PII-szűrés | ❌ |
| `nova_health` | Boot-diagnosztika, health check-ek, `/health` HTTP végpont, `/nova health` parancs | ❌ |
| `nova_metrics` | Belső metrikák (tick idő, event/perc, DB latency) → `/perf` mellé | ✅ |
| `nova_scheduler` | **Egyetlen** központi ütemező: batch, throttle, debounce, per-tick költségvetés | ❌ |
| `nova_world` | Entitás-életciklus: szerveroldali entitás-létrehozás, entitás-költségvetés, cleanup, routing bucket kezelés | ❌ |

### 3.2 Gameplay-modulok

Minden gameplay-modul azonos szerkezetű, és **kizárólag a `nova_core` publikus API-ját**
használja — soha nem nyúl közvetlenül DB-hez, sem nyers net eventhez.

```
nova_<modul>/
├── fxmanifest.lua
├── config/            # alapértelmezett konfiguráció + séma
├── locales/           # hu.json, en.json, de.json
├── permissions.lua    # a modul által definiált permission node-ok
├── migrations/        # a modul saját DB-migrációi (sorszámozva)
├── server/
│   ├── main.lua       # belépési pont, feature flag guard
│   ├── api.lua        # exportált publikus API
│   └── ...
├── client/
├── shared/
└── tests/
```

---

## 4. Indítási folyamat (boot sequence)

Ez a sorrend kötött, és a `nova_health` naplózza minden lépés eredményét.

```
1.  nova_lib          betöltés
2.  nova_config       config betöltés → séma-validáció → feature flag feloldás
                      ├─ HIBA esetén: részletes, megoldást javasló hibaüzenet, LEÁLLÁS
3.  nova_logging      log-célok inicializálása (a config alapján)
4.  nova_db           kapcsolat-teszt → migrációs állapot ellenőrzése
                      ├─ nem alkalmazott migráció: fail (prod) / figyelmeztetés (dev)
5.  nova_locale       locale fájlok betöltése, integritás-ellenőrzés
                      ├─ hiányzó kulcs: figyelmeztetés + riport, NEM leállás
6.  nova_permission   role/permission cache felépítése DB-ből
7.  nova_net          event-regiszter felépítése, rate limit szabályok
8.  nova_scheduler    ütemező indítása
9.  nova_world        entitás-regiszter, routing bucket alapkonfiguráció
10. gameplay modulok  csak azok, amelyek feature flagje engedélyezett
11. nova_health       teljes health check lefuttatása
12. STARTUP BANNER    (a 4.1 szerint)
```

### 4.1 Startup banner

```
  ███ NOVA RP
  Version:      1.4.2 (build 2026.08.27-a1b2c3d)
  Environment:  production
  Artifact:     FXServer 12xxx (recommended)
  Config:       OK        (142 kulcs, 0 hiba, 3 figyelmeztetés)
  Database:     OK        (MariaDB 11.4.x, 38/38 migráció alkalmazva)
  Localization: OK        (hu, en, de — 2841 kulcs, 0 hiányzó)
  Permissions:  OK        (11 role, 187 node)
  Features:     24 engedélyezve, 5 letiltva
  Health:       OK
```

**Production-ben a banner nem tartalmazhat:** DB hostot/usert/jelszót, licenckulcsot,
webhook URL-t, tokent, játékos-adatot, belső IP-t. Development-ben bővebb (de titok akkor sem).

### 4.2 Ha valami hiányzik

Nincs néma összeomlás és nincs értelmezhetetlen stacktrace. Formátum:

```
[NOVA][FATAL] Database connection failed.

  Mi történt:
    A(z) 'nova' adatbázishoz nem sikerült csatlakozni a következő címen:
    127.0.0.1:3306 (user: nova_app)

  Lehetséges okok:
    1. Az adatbázis-szolgáltatás nem fut.        → systemctl status mariadb
    2. Hibás jelszó a NOVA_DB_PASSWORD env-ben.  → lásd docs/SETUP.md#adatbazis
    3. A felhasználónak nincs joga.              → lásd docs/DATABASE.md#jogosultsagok
    4. Tűzfal blokkolja a 3306-os portot.

  Dokumentáció: docs/TROUBLESHOOTING.md#db-connection-failed
```

---

## 5. Kommunikációs minták

### 5.1 Server → Client

| Minta | Mikor | Példa |
| --- | --- | --- |
| **State bag** | Gyakran változó, scope-hoz kötött állapot | jármű zárva/nyitva, játékos job-ja |
| **Tipizált net event** | Egyszeri esemény, akció | értesítés, UI megnyitása |
| **Global state** | Szerver-szintű, ritkán változó | időjárás, feature flag pillanatkép |

Broadcast (`-1`) csak ritka, valóban globális eseményre. Minden más scope-alapú.

### 5.2 Client → Server

**Kizárólag** a `nova_net` rétegen keresztül:

```lua
-- Deklaráció (shared): a szerződés egy helyen, típussal
Nova.Net.Define('bank:transfer', {
    direction  = 'c2s',
    schema     = { target = 'number', amount = 'number:1..10000000' },
    rateLimit  = { per = 'player', max = 3, window = 10 },   -- 3 / 10 mp
    permission = nil,                                        -- nem admin művelet
    distance   = { to = 'bank_atm', max = 3.0 },             -- helyszínhez kötött
    feature    = 'economy.banking',
})

-- Kezelés (server): ide már csak validált, jogosult, rate-limitelt hívás jut el
Nova.Net.On('bank:transfer', function(source, data)
    -- data.target és data.amount típusa és tartománya garantált
end)
```

A `nova_net` minden elutasítást naplóz (`reason`, `source`, `payload` hash) — ez lesz az
anticheat-jelzések elsődleges forrása.

### 5.3 Modulok között

`exports` helyett **egységes API-objektum**, ami feature flag-tudatos:

```lua
local ok, err = Nova.Inventory.AddItem(playerId, 'water_bottle', 1)
-- ha a feature ki van kapcsolva: ok = false, err = 'FEATURE_DISABLED'
-- soha nem nil-crash, soha nem "attempt to index a nil value (exports)"
```

---

## 6. Project tree

```
nova-rp/
├── README.md
├── CHANGELOG.md
├── LICENSE                          # ADR-0002 után
├── .editorconfig · .gitignore · .nvmrc
├── .github/
│   └── workflows/
│       ├── ci.yml                   # lint, típus, unit, locale, migráció
│       ├── integration.yml          # FXServer + MariaDB integrációs teszt
│       └── release.yml              # tag → csomag + changelog
│
├── docs/
│   ├── 00-research/                 # platform-research, scale-analysis, dependencies
│   ├── 01-architecture/             # ez a mappa
│   ├── decisions/                   # ADR-ek
│   ├── dependencies/                # függőség-adatlapok
│   ├── reports/                     # load test és audit riportok
│   ├── roadmap.md · risks.md
│   └── (Phase 2-től) SETUP.md, QUICKSTART.md, INSTALLATION.md, …
│
├── server/                          # FXServer futtatási konfiguráció (bináris NINCS a repóban)
│   ├── server.cfg.example
│   └── cfg/
│       ├── 00-base.cfg              # endpointok, hostname, maxclients
│       ├── 10-security.cfg          # lockdown, purelevel, statebag strict, rate limiterek
│       ├── 20-resources.cfg         # ensure sorrend (generált!)
│       └── 90-local.cfg.example     # gépspecifikus, gitignore-olt
│
├── resources/
│   ├── [vendor]/                    # NEM verziókövetett — `nova vendor:install` tölti le
│   │   ├── ox_lib/                  # verzióra rögzítve + SHA-256 ellenőrzés (vendor.json)
│   │   └── oxmysql/
│   ├── [nova-core]/
│   │   ├── nova_lib/ nova_config/ nova_locale/ nova_db/ nova_net/
│   │   ├── nova_permission/ nova_logging/ nova_health/ nova_metrics/
│   │   └── nova_scheduler/ nova_world/
│   ├── [nova-gameplay]/
│   │   ├── nova_player/ nova_inventory/ nova_money/ nova_vehicles/
│   │   ├── nova_jobs/ nova_factions/ nova_police/ nova_ems/
│   │   ├── nova_housing/ nova_business/ nova_phone/ nova_illegal/
│   │   └── nova_admin/
│   └── [nova-ui]/
│       ├── nova_ui/                 # közös NUI host (React), egy WebView
│       ├── nova_hud/
│       └── nova_loadscreen/
│
├── database/
│   ├── migrations/                  # 0001_init.sql, 0002_players.sql, …
│   ├── seeds/                       # dev seed adatok (soha nem prod)
│   └── schema.md                    # generált séma-dokumentáció
│
├── tools/                           # Node 22 + TypeScript CLI
│   ├── src/
│   │   ├── locale/                  # validátor, riport, kulcs-kigyűjtés kódból
│   │   ├── migrate/                 # migráció-futtató (up/down/status/verify)
│   │   ├── config/                  # config séma-validátor
│   │   ├── resources/               # 20-resources.cfg generálás feature flagekből
│   │   └── release/                 # verzió, changelog, csomagolás
│   ├── package.json · tsconfig.json
│   └── README.md
│
├── tests/
│   ├── unit/                        # busted (Lua) — mock CFX API-val
│   ├── integration/                 # FXServer-ben futó teszt-resource forgatókönyvei
│   ├── mocks/                       # CFX natív mockok
│   └── loadtest/                    # nova_loadtest forgatókönyvek
│
└── ui/                              # NUI források (build → resources/[nova-ui]/nova_ui/web)
    ├── src/
    ├── package.json · vite.config.ts
    └── locales -> szimbolikus kapcsolat a resource locale-okra
```

**Miért `[vendor]` külön mappában:** a third-party kód módosítatlanul, saját licencével
együtt, jól láthatóan elkülönül a sajátunktól — ez licencjogilag és auditálhatóság
szempontjából is fontos. A tartalmát **nem verziókövetjük**: a `vendor.json` rögzíti a
pontos verziót és a release-csomag SHA-256 összegét, a `nova vendor:install` pedig
letölti és ellenőrzi. Így a függőség bitre meghatározott, a repo mégsem hízik, és egy
kicserélt upstream csomag azonnal kiderül.

**Miért generált a `20-resources.cfg`:** a feature flagek döntik el, mely resource induljon.
Ha a `Features.Housing.Enabled = false`, a housing resource **el sem indul** — nem
regisztrál eventet, nem foglal memóriát, nem jelenik meg az admin panelben.
A generálást a `tools` CLI végzi, a fájl a repóban van, hogy diffelhető legyen.

---

## 7. Névkonvenciók

| Elem | Konvenció | Példa |
| --- | --- | --- |
| Resource | `nova_<domain>` | `nova_inventory` |
| Net event | `nova:<domain>:<action>` | `nova:bank:transfer` |
| Permission node | `nova.<domain>.<action>[.<scope>]` | `nova.admin.player.kick` |
| Locale kulcs | `<domain>.<subject>.<variant>` | `bank.transfer.success` |
| Config kulcs | `Domain.Subdomain.Key` (PascalCase) | `Economy.Banking.MaxTransfer` |
| Feature flag | `<domain>.<feature>` | `phone.socialMedia` |
| DB tábla | `snake_case`, egyes szám nélkül | `player_vehicles` |
| Migráció | `NNNN_leiras.sql` | `0007_add_vehicle_liens.sql` |
| Lua fájl | `snake_case.lua` | `permission_cache.lua` |
| Lua publikus fv | `PascalCase` | `Nova.Money.Add` |
| Lua lokális fv | `camelCase` | `local function resolveNode()` |

---

## 8. Nyitott kérdések a Phase 2 spike-hoz

Ezekre implementáció előtt kis, időkorlátos kísérlettel válaszolunk, nem tippeléssel:

1. **busted + FXServer Lua kompatibilitás:** mennyi CFX-mock kell ahhoz, hogy a
   magmodulok játékon kívül fussanak? (Cél: `nova_lib`, `nova_config`, `nova_locale`,
   `nova_permission` 100%-ban játék nélkül tesztelhető.)
2. **CI-ban futó FXServer:** `sv_lan true` mellett licenckulcs nélkül indul-e a Linux
   artifact GitHub Actions runneren, és mennyi ideig tart egy ciklus?
3. **NUI architektúra:** egy közös NUI host (egy WebView, több nézet) vs. resource-onkénti
   NUI. Memória- és teljesítménymérés dönt.
4. **oxmysql metrika-kivezetés:** kinyerhető-e query-szintű latency saját metrikába,
   vagy a `nova_db` rétegben kell mérnünk.
5. **Enhanced-kompatibilitás:** a kiválasztott vendor-függőségek futnak-e Enhanced-en.
