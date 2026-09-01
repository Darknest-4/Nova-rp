# NOVA RP

Moduláris, skálázható FiveM (Cfx.re / FXServer) GTA V roleplay platform.

> **Állapot: PHASE 2 — PROJECT BOOTSTRAP kész.**
> A szerver elindul, a magkönyvtár (`nova_lib`) megvan, a tesztek és a CI futnak.
> **Gameplay kód még nincs** — az a Phase 8-tól kezdődik.
>
> Kezdéshez: **[QUICKSTART.md](QUICKSTART.md)** — klónozástól futó szerverig.
> Haladás: [docs/roadmap.md](docs/roadmap.md) · [docs/phases/](docs/phases/)

---

## Mi ez a projekt

A NOVA RP nem resource-gyűjtemény, hanem egy egységes platform. Minden rendszere:
moduláris, tesztelhető, dokumentált, konfigurálható, lokalizálható, permission-alapú,
szerveroldalon validált, ki/be kapcsolható és cserélhető.

Elsődleges nyelv: **magyar (`hu`)**, de a rendszerben egyetlen felhasználónak szánt szöveg
sem lehet kódba égetve. Támogatott nyelvek induláskor: `hu`, `en`, `de` — új nyelv
hozzáadása kódmódosítás nélkül történik.

## Dokumentáció

### Phase 0 — Research

| Dokumentum | Tartalom |
| --- | --- |
| [docs/00-research/platform-research.md](docs/00-research/platform-research.md) | A jelenlegi FiveM / Cfx.re környezet ellenőrzött tényei, forrásokkal és bizonyossági szinttel |
| [docs/00-research/scale-analysis.md](docs/00-research/scale-analysis.md) | A 2000+ slot / 1000+ CCU cél reális elemzése, architektúra-opciók, mérési terv |
| [docs/00-research/dependencies.md](docs/00-research/dependencies.md) | Third-party függőségek: verzió, licenc, kockázat, döntés |

### Phase 1 — Architecture

| Dokumentum | Tartalom |
| --- | --- |
| [docs/01-architecture/overview.md](docs/01-architecture/overview.md) | Tech stack, rétegek, modultérkép, boot-sorrend, project tree |
| [docs/01-architecture/configuration.md](docs/01-architecture/configuration.md) | Config rendszer, feature flag rendszer, validáció |
| [docs/01-architecture/localization.md](docs/01-architecture/localization.md) | Lokalizációs rendszer, per-player nyelv, fallback, validátor |
| [docs/01-architecture/permissions.md](docs/01-architecture/permissions.md) | RBAC, permission node-ok, öröklés, temporary grant, audit |
| [docs/01-architecture/database.md](docs/01-architecture/database.md) | Séma-terv, migrációk, tranzakciók, indexek, backup |
| [docs/01-architecture/security.md](docs/01-architecture/security.md) | Fenyegetésmodell, net-réteg, validáció, rate limit, exploit-védelem |
| [docs/01-architecture/testing.md](docs/01-architecture/testing.md) | Unit / integration / security / load teszt stratégia, CI |
| [docs/01-architecture/deployment.md](docs/01-architecture/deployment.md) | Környezetek, release, monitoring, backup, disaster recovery |

### Phase 2 — Bootstrap

| Dokumentum | Tartalom |
| --- | --- |
| [QUICKSTART.md](QUICKSTART.md) | Klónozástól futó szerverig, gyakori hibák táblázatával |
| [docs/phases/phase-02-bootstrap.md](docs/phases/phase-02-bootstrap.md) | A fázis terve és eredménye, mért teszteredményekkel és spike-válaszokkal |
| [docs/dependencies/](docs/dependencies/) | Függőség-adatlapok: verzió, checksum, licenc, exit-terv |

### Döntések és tervezés

| Dokumentum | Tartalom |
| --- | --- |
| [docs/decisions/](docs/decisions/) | ADR-ek (Architecture Decision Records) — a négy alapdöntés elfogadva |
| [docs/roadmap.md](docs/roadmap.md) | 28 fázis, mérföldkövek, becslések, függőségek |
| [docs/risks.md](docs/risks.md) | Kockázati regiszter |

### Később készülő dokumentumok

`SETUP.md`, `INSTALLATION.md`, `DEVELOPMENT.md`, `PRODUCTION.md`,
`TROUBLESHOOTING.md`, `DATABASE.md`, `CONFIGURATION.md`, `PERMISSIONS.md`,
`LOCALIZATION.md`, `TESTING.md`, `DEPLOYMENT.md`, `BACKUP.md`, `SECURITY.md`.

Mindegyikhez tartozik egy fázis, ahol elkészül — a listát és az indoklást a
[deployment.md](docs/01-architecture/deployment.md) 8. pontja tartalmazza.
Azért nem készülnek el előre, mert olyan parancsokat és fájlneveket kellene
tartalmazniuk, amelyeket még nem futtattunk le — a projekt alapszabálya viszont,
hogy nem írunk le olyat, amiben nem vagyunk biztosak.

## Meghozott döntések

| ADR | Döntés | Dátum |
| --- | --- | --- |
| [0001](docs/decisions/ADR-0001-target-platform.md) | **FiveM Legacy** az elsődleges célplatform, Enhanced-kompatibilis kódolási szabályokkal | 2026-08-27 |
| [0002](docs/decisions/ADR-0002-framework-base.md) | **Saját NOVA mag** + LGPL könyvtárak (ox_lib, oxmysql). Nem épülünk GPL-3.0 frameworkre | 2026-08-27 |
| [0003](docs/decisions/ADR-0003-hosting-platform.md) | Dev/staging **Linux**; a production platform a Phase 26 mérése után dől el | 2026-08-27 |
| [0004](docs/decisions/ADR-0004-scale-strategy.md) | **Egy világ** + routing bucket instance-ok, **shard-tudatos adatmodellel** | 2026-08-27 |

A becslésekhez használt kapacitás-feltevés: **1 fő**.

## Következő lépés

**Phase 3 — Core.** Első feladat az FXServer-indítás igazolása CI-ban
(a Phase 2 nyitva maradt spike-ja), majd a `nova_net`, `nova_scheduler`,
`nova_logging` és `nova_health` modulok.

## Licenc

Még nincs kiválasztva, de az [ADR-0002](docs/decisions/ADR-0002-framework-base.md)
döntése nyomán **szabadon megválasztható**: a projekt nem épül GPL-3.0 kódra, csak
LGPL-3.0 könyvtárakat használ (ox_lib, oxmysql), amelyek nem terjesztik ki a
copyleftet a saját kódunkra. A konkrét licenc kiválasztása a Phase 3 végéig esedékes.
