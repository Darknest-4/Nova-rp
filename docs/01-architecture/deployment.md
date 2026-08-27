# Deployment, Monitoring & Operations Plan

> Cél: kiszámítható, visszafordítható telepítés; mérhető üzemeltetés; tesztelt
> katasztrófa-helyreállítás.

---

## 1. Környezetek

| Környezet | Cél | Adat | Ki fér hozzá |
| --- | --- | --- | --- |
| **development** | Fejlesztői gép | Seed adat, dummy | Fejlesztő |
| **staging** | Production-hű próba | **Anonimizált** prod-másolat | Fejlesztő, QA, staff |
| **production** | Élő szerver | Éles | Üzemeltetés |

Szabályok:

- A staging **ugyanazt az artifactot, ugyanazokat a resource-verziókat és
  ugyanazt a pool-konfigurációt** futtatja, mint a production. Eltérő pool-méret esetén
  a kliensnek újra kell indulnia szerverváltáskor — ezt a tesztelők azonnal megérzik.
- Production-adat **soha nem másolható** anonimizálás nélkül staging-re.
- `Config.Server.Environment` határozza meg a viselkedést (banner részletessége,
  debug-parancsok, migrációs szigor, hot reload).

---

## 2. Release-folyamat

```
feature branch → PR (CI zöld) → main → tag (v1.4.0) → CI csomagol → staging →
elfogadási teszt → production (ütemezett ablakban)
```

### 2.1 Verziózás

**SemVer** (`MAJOR.MINOR.PATCH`):

| Változás | Példa |
| --- | --- |
| MAJOR | Törő DB-migráció, API-változás, ami modulokat érint |
| MINOR | Új feature, visszafelé kompatibilis |
| PATCH | Hibajavítás, fordítás, konfigurációs alapérték |

Minden release-hez **CHANGELOG** (Keep a Changelog formátum: Added / Changed /
Deprecated / Removed / Fixed / Security).

### 2.2 Csomag tartalma

```
nova-rp-1.4.0.tar.gz
├── resources/            # a NOVA resource-ok + vendor (pinned)
├── database/migrations/
├── server/cfg/           # a generált konfiguráció (TITKOK NÉLKÜL)
├── VERSION               # 1.4.0+a1b2c3d
├── CHANGELOG.md
└── manifest.json         # artifact-követelmény, migrációs szint, feature hash
```

**A csomag nem tartalmaz:** FXServer binárist, titkot, `.env`-et, játékos-adatot.

### 2.3 Telepítési lépések (production)

```
1.  Bejelentés a játékosoknak (txAdmin ütemezett restart, figyelmeztetésekkel)
2.  BACKUP: DB dump + txData + jelenlegi resource-könyvtár
3.  Karbantartási mód (a szerver nem fogad új csatlakozást)
4.  Graceful shutdown → minden write-behind cache flush-ol
5.  Csomag kicsomagolása egy ÚJ könyvtárba (nem felülírás!)
6.  npm run db:migrate:status → npm run db:migrate
7.  Symlink átállítása az új verzióra
8.  Szerver indítása
9.  Health check (automatikus, lásd 4.)
10. Füstteszt: belépés, karakter, pénz, item, nyelvváltás, admin-parancs
11. Karbantartási mód kikapcsolása
12. 30 perc megfigyelés (tick, hibaarány, DB-latency)
```

### 2.4 Rollback

Mivel a régi verzió külön könyvtárban maradt, a kód-visszaállítás **symlink-váltás
+ restart** — percek kérdése.

**Az adatbázis a nehéz eset:**

| Eset | Eljárás |
| --- | --- |
| Nem volt migráció | Symlink vissza + restart. Kész. |
| Volt kompatibilis migráció (expand) | Symlink vissza + restart; a séma előrébb van, de a régi kód működik |
| Volt törő migráció | **DB-visszaállítás backupból** → a visszaállítás óta eltelt idő adata elvész |

**Ezért:** minden törő migrációt expand/contract mintában bontunk két release-re
(előbb az új szerkezet a régi mellé, kód áttérés, csak a következő release-ben törlünk).
Így a rollback szinte mindig adatvesztés nélküli.

### 2.5 Artifact-frissítés

A Cfx támogatási szabálya miatt (recommended: a következő kiadás után 6 hét;
3 hónapnál régebbi artifact = nem látszik a szerverlistán) az artifact-frissítés
**ütemezett, tesztelt feladat**, nem tűzoltás:

```
havonta: új recommended artifact → staging → 1 hét megfigyelés → production
```

Az `manifest.json` rögzíti a minimálisan szükséges build számot (pl. a
függőségeink `/server:10731` igénye), és a `nova_health` induláskor ellenőrzi.

---

## 3. Infrastruktúra

```
┌───────────────┐   ┌──────────────┐   ┌─────────────────┐
│ Game server   │   │ Adatbázis    │   │ Ops             │
│ FXServer      │◄─►│ MariaDB 11.4 │◄─►│ Prometheus      │
│ txAdmin       │   │ (NVMe)       │   │ Grafana         │
│ NOVA resource │   │ replika      │   │ Loki            │
└───────────────┘   └──────────────┘   │ backup-tároló   │
        ▲                              └─────────────────┘
        │ DDoS-védelem / tűzfal
     Játékosok
```

Szabályok:

- A DB **nem** a game serverrel egy gépen (production).
- Csak a szükséges portok publikusak: játék UDP/TCP `30120` (vagy amit beállítunk).
  **A txAdmin (`40120`), a DB (`3306`), a Prometheus és a Grafana soha nem publikus** —
  VPN vagy SSH-tunnel mögött.
- `sv_endpointPrivacy true`, `sv_httpFileServerProxyOnly` + `sv_proxyIPRanges`,
  ha proxy mögött futunk.

### 3.1 Windows vs. Linux

A hivatalos Cfx dokumentáció szerint a Linux build **„courtesy port"**, és a hibák
nagyobb eséllyel kerülnek javításra Windows-on. Ez valós, dokumentált tény, nem vélemény.

| | Windows Server | Linux (Debian 12 / Ubuntu 24.04) |
| --- | --- | --- |
| Hivatalos támogatás | **Erősebb** | Gyengébb (courtesy port) |
| Crash-diagnosztika | Jobb natív eszközök | Korlátozottabb |
| Automatizálás, konténerizálás | Gyengébb | **Erősebb** |
| Üzemeltetési költség | Licencdíj | Ingyenes |
| Csapat-ismeret | ? | ? |

**Javaslat:** development és staging **Linux** (automatizálás, CI, reprodukálhatóság),
a production platformját pedig a Phase 26 load teszt döntse el **mérés alapján**,
mindkettőn lefuttatva. Ez [ADR-0003](../decisions/ADR-0003-hosting-platform.md).

---

## 4. Health check és diagnosztika

### 4.1 Rétegek

| Szint | Mit ellenőriz | Hol érhető el |
| --- | --- | --- |
| **Boot** | DB, migrációk, config, locale, permission, függőségek, titkok, verzió | Konzol + banner |
| **Folyamatos** | DB-latency, tick, memória, hibaarány, event-forgalom | Prometheus |
| **On-demand** | Minden fenti + részletek | `/health` HTTP, `/nova health` parancs, admin panel |

### 4.2 `/health` végpont

A resource-ok regisztrálhatnak HTTP handlert, így a `nova_health` saját végpontot ad:

```json
{
  "status": "ok",
  "version": "1.4.0+a1b2c3d",
  "environment": "production",
  "uptimeSeconds": 84213,
  "checks": {
    "database":     { "status": "ok", "latencyMs": 3, "migrations": "38/38" },
    "cache":        { "status": "ok" },
    "resources":    { "status": "ok", "started": 34, "failed": 0 },
    "eventSystem":  { "status": "ok", "eventsPerMinute": 12483, "rejected": 4 },
    "permissions":  { "status": "ok", "roles": 11, "nodes": 187 },
    "localization": { "status": "ok", "languages": 3, "missingKeys": 0 },
    "storage":      { "status": "ok", "freeDiskPercent": 62 },
    "integrations": { "status": "degraded", "discord": "rate_limited" }
  },
  "players": 412
}
```

- A végpont **hitelesítést igényel** (token vagy IP-allowlist) — az állapotinformáció
  felderítési értékű egy támadónak.
- HTTP státusz: `200` ok, `503` ha bármely kritikus check hibás → külső
  felügyeleti rendszer közvetlenül használhatja.

### 4.3 CLI-diagnosztika

```
> nova health              # teljes health check, emberi olvasásra
> nova health --json       # gépi feldolgozásra
> nova config check        # konfiguráció újravalidálása
> nova locale check        # lokalizációs riport
> nova perm explain 42 nova.admin.player.kick
     → ALLOW  (role:admin ← role:moderator grant #187, lejár: 2026-09-27)
> nova db status           # migrációk, kapcsolat, lassú query top-lista
> nova features            # aktív/inaktív feature flagek
```

A `nova perm explain` külön kiemelendő: jogosultsági hibák diagnózisa enélkül
kitalálósdi.

---

## 5. Monitoring

### 5.1 Adatforrások

| Forrás | Mit ad |
| --- | --- |
| FXServer `/perf` | **Beépített Prometheus-metrikák** (`sv_prometheusBasicAuthUser/Password`) |
| `nova_metrics` | Saját metrikák: event/perc, elutasítás, DB-latency, cache-hit, tick-bontás |
| node_exporter | CPU, RAM, hálózat, lemez |
| mysqld_exporter | Query-arány, lassú query, kapcsolatok, replikációs késés |
| Loki / fájl | Strukturált logok |
| txAdmin | Process-állapot, crash-detektálás, játékoslista |

### 5.2 Dashboardok

1. **Overview** — CCU, tick, CPU, RAM, hibaarány, DB p95
2. **Performance** — resource-onkénti CPU-idő, hitch warningok, GC
3. **Database** — query-arány, latency-percentilisek, lassú query top-10, pool
4. **Security** — elutasított eventek, rate-limitek, jogosulatlan kísérletek, anomáliák
5. **Economy** — pénz be/ki, item-forgalom, infláció-jelzők
6. **Player** — csatlakozások, kilépések, sessionhossz, nyelvi megoszlás

### 5.3 Riasztások

| Riasztás | Küszöb | Súlyosság |
| --- | --- | --- |
| Szerver nem válaszol | 60 mp | **critical** |
| Tick > 16,6 ms | 5 percen át | high |
| DB p95 > 100 ms | 5 percen át | high |
| Hibaarány > 10/perc | 5 percen át | high |
| Jogosulatlan admin-event kísérlet | ≥ 1 | **critical** |
| Lemez > 85% | — | high |
| Backup elmaradt | 26 óra | **critical** |
| Rendellenes pénznövekedés | konfigurált | high |
| Artifact 8 hétnél régebbi | — | medium |

**Riasztási elv:** csak az riasszon, amire ember reagálni tud. A zajos riasztás
rosszabb, mint a hiánya, mert leszoktat a reagálásról.

---

## 6. Backup és disaster recovery

Backup-mátrix: lásd [database.md](database.md) 8.

### 6.1 Helyreállítási forgatókönyvek

| Forgatókönyv | Eljárás | Cél-RTO |
| --- | --- | --- |
| Resource-hiba | Feature flag ki → javítás → deploy | 15 perc |
| Rossz release | Symlink-rollback + restart | 10 perc |
| DB adatsérülés | Utolsó dump + binlog PITR az incidens előtti pontig | 60 perc |
| Game server elvesztése | Új gép + csomag + `.env` visszaállítás | 2 óra |
| DB szerver elvesztése | Replika előléptetése vagy backup-visszaállítás | 2 óra |
| Teljes infrastruktúra | Teljes újraépítés dokumentáció + offsite backup alapján | 8 óra |

**Minden forgatókönyvhöz runbook** készül (`docs/runbooks/`), és a top 3-at
**negyedévente gyakoroljuk** — nem élesben, hanem külön környezetben.
A be nem gyakorolt runbook incidens közben nem működik.

### 6.2 Amit a DR-terv megkövetel

- Az `.env` (titkok) **külön, titkosított** biztonsági mentése, a kódtól elkülönítve.
- A `sv_licenseKey` és a Cfx Portal hozzáférés dokumentált helye (jelszókezelő).
- Legalább két ember férjen hozzá minden kritikus rendszerhez (bus factor ≥ 2).
- A DNS/IP-váltás menete leírva (`static-ips` a Cfx dokumentációban).

---

## 7. Ütemezett karbantartás

| Feladat | Gyakoriság |
| --- | --- |
| Szerver-restart (txAdmin, figyelmeztetéssel) | naponta, forgalmi minimumban |
| Backup-ellenőrzés (létezik, mérete rendben) | naponta, automatikus |
| **Backup-visszaállítás tesztje** | negyedévente |
| Artifact-frissítés | havonta |
| Függőség-frissítés (`vendor/`, npm) | havonta |
| Lassú query áttekintés | hetente |
| Biztonsági log áttekintés | hetente |
| Log-rotáció és megőrzés érvényesítése | automatikus |
| DR-gyakorlat | negyedévente |
| Kapacitás-áttekintés (CCU-trend, headroom) | havonta |

---

## 8. Onboarding-dokumentáció (Phase 2-től, „zero knowledge" elvárás)

A specifikáció 18. és 50. pontja szerint minden lépéshez kell: **pontos parancs +
pontos fájlnév + pontos hely + várt eredmény + gyakori hibák + hibajavítás.**

Ezért ezek a dokumentumok **csak akkor** készülnek el, amikor a valódi parancsokat
végig tudjuk futtatni és ellenőrizni — kitalált parancsokat tartalmazó telepítési
útmutató rosszabb, mint a semmi.

| Dokumentum | Mikor | Tartalom |
| --- | --- | --- |
| `QUICKSTART.md` | Phase 2 vége | clone → install → configure → db → build → start → test |
| `SETUP.md` / `INSTALLATION.md` | Phase 2–4 | A 28 lépéses telepítés, Windows és Linux ágon |
| `DEVELOPMENT.md` | Phase 2 | Fejlesztői környezet, workflow, hot reload, debug |
| `DATABASE.md` | Phase 4 | Séma, migrációk, jogosultságok, hangolás |
| `CONFIGURATION.md` | Phase 6 | **Generált** a sémákból |
| `PERMISSIONS.md` | Phase 7 | Node-ok, role-ok, panel, ACE-híd |
| `LOCALIZATION.md` | Phase 5 | Fordítói útmutató, validátor, új nyelv |
| `TESTING.md` | Phase 25 | Tesztek futtatása, írása, CI |
| `PRODUCTION.md` | Phase 28 | Élesítés, hangolás, kapacitás |
| `DEPLOYMENT.md` | Phase 28 | Release, rollback, artifact-frissítés |
| `BACKUP.md` | Phase 24 | Backup, visszaállítás, PITR, gyakorlat |
| `SECURITY.md` | Phase 23 | Üzemeltetői biztonsági kézikönyv |
| `TROUBLESHOOTING.md` | folyamatos | Hibaüzenetenként: ok → megoldás |

A `TROUBLESHOOTING.md`-t a fejlesztés során **folyamatosan töltjük**: minden
értelmes hibaüzenethez, amit a `nova_health` vagy a `nova_config` ad, azonnal
bekerül a hozzá tartozó szakasz. Így a végére nem kell „visszaemlékezni" rá.
