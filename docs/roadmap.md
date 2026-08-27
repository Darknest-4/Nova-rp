# Development Roadmap

> **A becslésekről őszintén:** a megadott időtartamok **1 fő teljes állású, tapasztalt
> FiveM-fejlesztőre** vonatkoznak, és az [ADR-0002](decisions/ADR-0002-framework-base.md)
> „A) saját mag" opcióját feltételezik. Több fejlesztővel a magfázisok nem osztódnak
> jól (Brooks törvénye), a gameplay-fázisok viszont igen — ott 2–3 fő közel arányos
> gyorsulást hoz. **Ezek becslések, nem ígéretek**; minden fázis végén frissítjük őket
> a tényleges ráfordítás alapján.
>
> A Qbox-alap (B opció) a Phase 8–17 szakaszt nagyságrendileg **4–8 hónappal** rövidíti.

## Mérföldkövek

| Mérföldkő | Fázisok | Mit jelent |
| --- | --- | --- |
| **M0 — Foundation** | 0–2 | A repo áll, a CI zöld, a szerver elindul, „hello world" resource fut |
| **M1 — Platform** | 3–7 | A mag működik: config, DB, locale, permission — gameplay nélkül |
| **M2 — Playable** | 8–11 | Be lehet lépni, karakter, pénz, item, jármű: játszható alap |
| **M3 — Roleplay** | 12–17 | Jobok, frakciók, rendőrség, mentő, ingatlan, vállalkozás |
| **M4 — Experience** | 18–22 | Telefon, UI, illegális rendszerek, adminpanel, Discord |
| **M5 — Production** | 23–28 | Biztonság, monitoring, tesztek, load, optimalizálás, hardening |

---

## Phase 0 — Research ✅ **KÉSZ**

- **Cél:** a jelenlegi FiveM/Cfx környezet feltérképezése, kockázatok azonosítása.
- **Eredmény:** [platform-research.md](00-research/platform-research.md),
  [scale-analysis.md](00-research/scale-analysis.md),
  [dependencies.md](00-research/dependencies.md).
- **Nyitott:** ADR-0001, ADR-0002 jóváhagyása.

## Phase 1 — Architecture ✅ **KÉSZ** (jóváhagyásra vár)

- **Cél:** teljes architektúra-terv implementáció előtt.
- **Eredmény:** a `docs/01-architecture/` teljes tartalma + 4 ADR.
- **Kapu:** az ADR-0001 és ADR-0002 elfogadása. **Enélkül a Phase 2 nem indul.**

---

## Phase 2 — Project Bootstrap · *2–3 hét*

- **Cél:** futtatható, üres, de teljesen felszerelt projekt.
- **Tartalom:** repo-szerkezet, `.editorconfig`, lint, LLS-konfiguráció, `tools/` CLI
  váza, CI pipeline, `server.cfg` sablon, vendor-függőségek pinelése, `nova_lib`,
  „hello world" resource, `QUICKSTART.md` első verziója.
- **Spike-ok (időkorlátos kísérletek, lásd [overview.md](01-architecture/overview.md) 8.):**
  1. busted + CFX-mock életképesség
  2. FXServer a CI-ban (`sv_lan true`)
  3. NUI-architektúra (közös host vs. resource-onkénti)
  4. oxmysql metrika-kivezetés
  5. Enhanced-kompatibilitás a vendor-függőségekre
- **Kapu:** `git clone` → dokumentált lépések → futó szerver, **egy új fejlesztő gépén is**.

## Phase 3 — Core · *3–4 hét*

- `nova_lib` (Result/Error, séma-validátor, util), `nova_net` (tipizált event-réteg),
  `nova_scheduler`, `nova_logging`, `nova_health` alapok.
- **Kapu:** a net-réteg biztonsági tesztkészlete zöld; a scheduler tick-költsége mérve.

## Phase 4 — Database · *2–3 hét*

- `nova_db`, migrációs CLI, alapséma (accounts, characters, audit, config_overrides),
  tranzakció-API, write-behind cache, metrikák.
- **Kapu:** migráció fel/le, checksum-védelem, párhuzamossági tesztek zöldek.

## Phase 5 — Localization · *2–3 hét*

- `nova_locale` (per-player, fallback-lánc, plural, formázók, hot reload),
  locale validátor CLI, `LOCALIZATION.md`.
- **Kapu:** nyelvváltás újracsatlakozás nélkül; validátor 0 ERROR; hiányzó kulcs nem crashel.

## Phase 6 — Configuration · *2 hét*

- `nova_config` (rétegek, séma, feature flag rendszer), config validátor,
  resource-lista generátor, generált `CONFIGURATION.md`.
- **Kapu:** hibás config → a szerver nem indul, értelmes hibával; kikapcsolt feature
  → a resource el sem indul.

## Phase 7 — Permissions · *2–3 hét*

- `nova_permission` (node-ok, role-ok, öröklés, allow/deny, lejárat, scope, cache),
  ACE-híd, audit, `nova perm explain`.
- **Kapu:** a permission tesztmátrix ([permissions.md](01-architecture/permissions.md) 10.)
  teljes egészében zöld; 10 000 ellenőrzés < 5 ms.

> **M1 — Platform kész.** Innentől minden gameplay ugyanarra az alapra épül.

---

## Phase 8 — Player · *3–4 hét*

Fiók- és karakterkezelés, karakterválasztó (routing bucket), létrehozás, státuszok,
mentés, `playerConnecting` deferral (whitelist, ban, verzió, nyelv).

## Phase 9 — Inventory · *5–7 hét*

Slot-alapú inventory metaadattal, súly, konténerek, csere, dobás, bolt, craft-alap.
**A legkockázatosabb gameplay-modul** (duplikáció, race, teljesítmény) — itt a
biztonsági és párhuzamossági tesztek a fejlesztéssel egy időben készülnek.

## Phase 10 — Money / Economy · *3–4 hét*

Készpénz/bank/fekete pénz, tranzakciók, könyvelés, payday, adók, ATM, átutalás,
gazdasági metrikák (infláció-figyelés).

## Phase 11 — Vehicles · *4–5 hét*

Tulajdon, garázs, kulcs, állapot-perzisztencia, üzemanyag, javítás, zálog/lefoglalás.

> **M2 — Playable.** Belépés, karakter, pénz, item, jármű — az első valódi playtest.

---

## Phase 12 — Jobs · *4–5 hét* · Phase 13 — Factions · *3–4 hét*

Job-keretrendszer (adatvezérelt, nem hardcode), rangok, fizetés, feladatok;
frakciók, tagság, hierarchia, scope-os jogosultságok, frakció-kassza.

## Phase 14 — Police · *4–5 hét* · Phase 15 — EMS · *3–4 hét*

MDT, bilincs, bizonyíték, körözés, büntetés; sérülés-modell, újraélesztés, kórház.
Mindkettő a frakció- és job-keretre épül, nem külön birodalom.

## Phase 16 — Housing · *4–5 hét* · Phase 17 — Businesses · *4–5 hét*

Ingatlan, bérlés, tárolás, dekoráció; vállalkozás, alkalmazottak, készlet, bevétel.

> **M3 — Roleplay.** A szerver tartalmilag teljes RP-élményt ad.

---

## Phase 18 — Phone · *5–6 hét*

Hívás, SMS, névjegy, banki alkalmazás, marketplace, hírek, (opcionálisan social media).
Minden alkalmazás külön feature flag mögött.

## Phase 19 — UI · *4–5 hét*

Egységes NUI design system, HUD, értesítések, menük, loading screen — mind lokalizálva,
mind akadálymentességi alapokkal (kontraszt, méretezhető szöveg).

## Phase 20 — Illegal systems · *4–6 hét*

Drog, rablás, csempészet, feketepiac — **mind feature flag mögött**, mert
jogi/moderációs okból ki kell kapcsolhatónak lenniük.

## Phase 21 — Admin Panel · *5–6 hét*

Játékos-kezelés, jogosultság-kezelés, feature flag kapcsolók, log- és auditnézet,
gazdasági eszközök, health panel — minden művelet auditálva és jogosultsághoz kötve.

## Phase 22 — Discord · *2–3 hét*

Bot, szerepkör-szinkron, whitelist, log-csatornák, státusz — **konfigurálható
csatornánkénti nyelvvel**, titkok környezeti változóból.

> **M4 — Experience.**

---

## Phase 23 — Security · *3–4 hét*

Teljes biztonsági audit ([security.md](01-architecture/security.md) 9.),
exploit-tesztkészlet, convar-hangolás mérés alapján, anomália-detektor élesítése.
**Kimenet:** `docs/reports/security-audit-<dátum>.md`.

## Phase 24 — Monitoring · *2–3 hét*

Prometheus + Grafana dashboardok, riasztások, Loki, backup-automatizálás és
**visszaállítás-teszt**, runbookok.

## Phase 25 — Automated Testing · *3–4 hét*

A tesztkészlet teljessé tétele, lefedettségi célok, éjszakai futások,
teljesítmény-regressziós figyelés.

## Phase 26 — Load Testing · *4–6 hét*

`nova_loadtest`, szintetikus mérések, lépcsőzetes valós tesztek
(50 → 2000), platform-összehasonlítás (ADR-0003), riportok minden lépcsőről.

## Phase 27 — Optimization · *4–6 hét*

A load teszt által feltárt szűk keresztmetszetek javítása — **adat alapján**,
nem megérzésből. Minden optimalizáció előtt/után mérés.

## Phase 28 — Production Hardening · *3–4 hét*

Végső audit ([security.md](01-architecture/security.md), a specifikáció 42. pontja
szerinti 13 terület), DR-gyakorlat, dokumentáció-teljesség ellenőrzése,
„zero knowledge" telepítési próba egy külső fejlesztővel.

> **M5 — Production.** A „production ready" kifejezés **csak akkor** használható, ha
> a specifikáció 43. pontjának mind a 9 feltétele teljesül.

---

## Összesítés

| Mérföldkő | Becsült idő (1 fő) |
| --- | --- |
| M0 (Phase 0–2) | ~1 hónap |
| M1 (Phase 3–7) | ~3 hónap |
| M2 (Phase 8–11) | ~4 hónap |
| M3 (Phase 12–17) | ~6 hónap |
| M4 (Phase 18–22) | ~5 hónap |
| M5 (Phase 23–28) | ~5 hónap |
| **Összesen** | **~24 hónap (1 fő), ~12–15 hónap (3 fős csapat)** |

**Ezt az számot érdemes komolyan venni.** Egy teljes, saját RP-platform két év
munkája egy embernek. Ha ez nem fér bele, két őszinte út van:

1. **Szűkíteni a hatókört** — pl. a Phase 16–20 elhagyása az első kiadásból.
2. **Meglévő frameworkre építeni** (ADR-0002 B opció) — GPL-kötelezettséggel,
   kisebb kontrollal, de lényegesen gyorsabban.

A harmadik út — „mindent megcsinálunk, csak gyorsabban" — nem létezik, és ha valaki
ezt ígéri, az vagy a minőségből, vagy a biztonságból von le.

---

## Fázis-protokoll

**Minden fázis ELŐTT** (a specifikáció 45. pontja):
cél · architektúra · érintett fájlok · függőségek · DB-változások · config-változások ·
permission node-ok · locale kulcsok · biztonsági kockázatok · teszttervek.

**Minden fázis UTÁN** (46. pont):
mi készült el · milyen tesztek futottak · milyen hibák voltak · mit javítottunk ·
teljesítmény-mérés · biztonsági megállapítások · dokumentáció · következő lépés.

Ezek a `docs/phases/phase-NN-<név>.md` fájlokba kerülnek, és a fázis lezárása
a QA-kapu ([testing.md](01-architecture/testing.md) 10.) teljesítése.
