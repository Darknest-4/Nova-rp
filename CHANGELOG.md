# Changelog

A projekt minden lényeges változása itt kerül rögzítésre.

A formátum a [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) ajánlását követi,
a verziózás a [Semantic Versioning](https://semver.org/spec/v2.0.0.html) szerint történik.

## [Unreleased]

### Added

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
