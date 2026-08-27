# NOVA RP

Moduláris, skálázható FiveM (Cfx.re / FXServer) GTA V roleplay platform.

> **Állapot: PHASE 0 — RESEARCH & ARCHITECTURE.**
> Ebben a repository-ban jelenleg **nincs gameplay kód**, és szándékosan nincs is.
> A Phase 0 kimenete a kutatás, az architektúra-terv és a döntési javaslatok.
> Implementáció csak jóváhagyás után indul.

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

### Döntések és tervezés

| Dokumentum | Tartalom |
| --- | --- |
| [docs/decisions/](docs/decisions/) | ADR-ek (Architecture Decision Records) — jelenleg mind `Proposed` |
| [docs/roadmap.md](docs/roadmap.md) | 28 fázis, mérföldkövek, becslések, függőségek |
| [docs/risks.md](docs/risks.md) | Kockázati regiszter |

### Később készülő dokumentumok (Phase 2-től)

`QUICKSTART.md`, `SETUP.md`, `INSTALLATION.md`, `DEVELOPMENT.md`, `PRODUCTION.md`,
`TROUBLESHOOTING.md`, `DATABASE.md`, `CONFIGURATION.md`, `PERMISSIONS.md`,
`LOCALIZATION.md`, `TESTING.md`, `DEPLOYMENT.md`, `BACKUP.md`, `SECURITY.md`.

Ezek tartalmi vázlata és felelőse a [roadmap](docs/roadmap.md)-ben szerepel. Azért nem
készültek el most, mert olyan parancsokat és fájlneveket kellene tartalmazniuk, amelyek
az implementációs döntések előtt kitaláltak lennének — a projekt egyik alapszabálya
viszont, hogy nem írunk le olyat, amiben nem vagyunk biztosak.

## Következő lépés

A Phase 0 lezárásához három döntés kell (részletesen:
[docs/decisions/](docs/decisions/)):

1. **ADR-0001** — FiveM Legacy vs. FiveM for GTAV Enhanced célplatform
2. **ADR-0002** — saját mag vs. meglévő framework (Qbox / ox_core / ESX) alap
3. **ADR-0003** — production hosting: Windows vs. Linux FXServer

Jóváhagyás után indul a Phase 2 (Project Bootstrap).

## Licenc

Nincs még eldöntve — a döntés függ az ADR-0002 kimenetétől (GPL-3.0 alapú framework
használata copyleft-kötelezettséget von maga után). Lásd:
[docs/00-research/dependencies.md](docs/00-research/dependencies.md).
