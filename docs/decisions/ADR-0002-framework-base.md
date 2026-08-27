# ADR-0002: Saját mag vs. meglévő framework (Qbox / ox_core / ESX)

- **Állapot:** `Proposed` — jóváhagyásra vár
- **Dátum:** 2026-08-27
- **Blokkoló:** igen — ez határozza meg a repository szerkezetét, a licencet és a roadmapet

## Kontextus

A NOVA RP specifikációja olyan platform-képességeket ír elő, amelyek egyik létező
FiveM frameworkben sincsenek meg:

| Követelmény | ESX | QBCore | Qbox | ox_core |
| --- | --- | --- | --- | --- |
| Per-player, futásidejű nyelvváltás mindenre | ❌ | ❌ | ❌ | ❌ |
| Központi feature flag rendszer (nested, rollout, permission-based) | ❌ | ❌ | ❌ | ❌ |
| Node-alapú RBAC lejárattal, scope-pal, audittal | ❌ | részleges | részleges | részleges |
| Séma-validált konfiguráció boot-időben | ❌ | ❌ | ❌ | ❌ |
| Tick-költségvetés és mért teljesítmény-kapuk | ❌ | ❌ | ❌ | ❌ |

Az ellenőrzött tények (részletesen:
[dependencies.md](../00-research/dependencies.md)):

- **ox_lib** (3.39.0) és **oxmysql**: **LGPL-3.0-or-later**, aktívan karbantartva
  (utolsó commit 2026-08-17 / 2026-07-03).
- **qbx_core** (Qbox, 1.24.0): **GPL-3.0**, aktív (2026-08-22), `/server:10731`+ igény.
- **ox_inventory** (2.47.9): **GPL-3.0**, aktív.
- **esx_core** (v1.14.1): **GPL-3.0**, aktív.
- **ox_core** (1.5.14): ⚠️ **licenc-ellentmondás** a saját fájljai között
  (LICENSE = LGPL, package.json = LGPL, NOTICE.md = GPL). Amíg nem tisztázott,
  GPL-ként kezeljük.
- Az `ox_lib` locale modulja **szerverenként egy nyelvet** ismer
  (`GetConvar('ox:locale', 'en')`) — strukturálisan nem tudja a per-player nyelvet.

A GPL-3.0 nem apró részlet: ha a NOVA RP származékos műnek minősül, a teljes
szerverkódot GPL-3.0 alatt kell átadni bárkinek, aki megkapja a szoftvert
(társfejlesztő, hosting partner, vásárló). Az ox_core `NOTICE.md` kifejezetten tiltja
az olyan terjesztést (titkosítás, obfuszkáció), ami a licenc jogait korlátozná.

> ⚠️ Nem vagyunk jogászok. Kereskedelmi vagy zárt terjesztés esetén ezt jogi
> szakvéleménnyel kell megerősíteni.

## Vizsgált lehetőségek

### A) Saját NOVA mag + LGPL könyvtárak (ox_lib, oxmysql) — **javasolt**

- ➕ Licencszabadság: mi döntjük el, nyílt vagy zárt.
- ➕ A specifikáció minden követelménye megvalósítható úgy, ahogy le van írva.
- ➕ Teljes kontroll a teljesítmény felett (tick-költségvetés betartható).
- ➕ Nincs örökölt, ismeretlen minőségű kód a forró útvonalon.
- ➖ **Sokkal több munka**: az inventory, a jármű-, a job- és a housing-rendszert
  nekünk kell megírni.
- ➖ A kész third-party script-ökoszisztéma nem működik közvetlenül (bridge kell).
- ➖ Nincs upstream, aki helyettünk javít biztonsági hibát.

### B) Qbox (qbx_core) alap

- ➕ Gyors indulás, nagy és növekvő script-ökoszisztéma, modern kódbázis.
- ➕ Aktív karbantartás, ox-stack natív integráció.
- ➖ **GPL-3.0**: a NOVA RP nyílt forráskódúvá válik.
- ➖ A NOVA-specifikus követelmények (per-player locale, feature flag, RBAC) így is
  megírandók — csak most egy idegen adatmodell köré.
- ➖ Upstream-függés: törő változások és a mi igényeinktől eltérő irány.

### C) ox_core alap

- ➕ Modern, TypeScript-alapú, aktív.
- ➖ Licenc-ellentmondás tisztázatlan → jelenleg vállalhatatlan kockázat.
- ➖ Kisebb ökoszisztéma, mint a Qboxé.

### D) ESX alap

- ➕ Legnagyobb kész tartalom, legtöbb magyar nyelvű tapasztalat.
- ➖ GPL-3.0. Régi architektúra, sok legacy minta, ami pont az ellentéte a
  specifikáció teljesítmény- és biztonsági elvárásainak.

## Döntés (javaslat)

> **A) Saját NOVA mag + LGPL könyvtárak (ox_lib, oxmysql), opcionális kompatibilitási
> bridge-ekkel.**

Konkrétan:

1. A `nova_core` teljesen saját (config, locale, permission, db, net, logging,
   health, metrics, scheduler, world).
2. `vendor/` alatt **módosítatlan**, pinned `ox_lib` és `oxmysql`, licencszöveggel
   és attribúcióval együtt.
3. Az `ox_lib`-et **UI-, cache-, zóna- és callback-célra** használjuk, a lokalizációra
   **nem** (mert nem tudja, amit kell).
4. GPL-3.0 gameplay-resource **nem** kerül a projektbe, amíg ez az ADR érvényes.
5. **Bridge-ek külön, opcionális resource-ként** (`nova_bridge_ox`, `nova_bridge_qb`),
   hogy a közösségi scriptek használhatók legyenek — a bridge licencjogi helyzetét
   külön kell értékelni, mielőtt kiadjuk.

## Indoklás

A döntő érv nem a „legyen sajátunk" büszkeség, hanem ez: **a specifikáció négy
alapkövetelménye (teljes per-player lokalizáció, központi feature flag, node-alapú
RBAC audittal, séma-validált konfiguráció) egyik framework magjában sincs meg.**
Bármelyikre építve is meg kell írnunk őket — akkor viszont egy idegen adatmodell
köré, örökölt kompromisszumokkal és GPL-kötelezettséggel.

Ha a NOVA RP-t úgyis 80%-ban mi írjuk, akkor jobb, ha a maradék 20% is a mi
szabályaink szerint működik.

## Következmények

- **Nehezebb lesz:** hosszabb út az első játszható verzióig; nincs kész inventory,
  jármű- és job-rendszer; a biztonsági javítások a mi felelősségünk.
- **Könnyebb lesz:** a teljesítmény-, biztonsági és lokalizációs követelmények
  betarthatók; a licenc szabad; nincs upstream-kényszer.
- **Ütemterv-hatás:** a [roadmap](../roadmap.md) becslései ezt a döntést tükrözik.
  A B) opció nagyságrendileg **4–8 hónappal** rövidítené a Phase 8–17 szakaszt, de
  GPL-kötelezettséggel és kisebb kontrollal.

## Ha a döntés B) lesz (Qbox)

Akkor ezek változnak, és ezt előre kimondjuk:

1. A projekt **GPL-3.0** licencet kap, és ezt a README-ben vállaljuk.
2. A `nova_core` megmarad, de **rétegként a qbx_core felett** (locale, feature flag,
   RBAC, config) — nem helyette.
3. A roadmap Phase 8–17 szakasza jelentősen rövidül, a Phase 27 (optimalizáció)
   viszont hosszabb lesz, mert örökölt kódot is hangolnunk kell.
4. Az `ox_inventory` (GPL) használható lesz, ami önmagában több hónap munkát spórol.

**Ez teljesen legitim választás** — csak tudatosan kell meghozni, mert visszafelé
nagyon drága.

## Felülvizsgálat

Újranézzük, ha: (a) a fejlesztői kapacitás jelentősen változik, (b) az ox_core
licenchelyzete tisztázódik és LGPL-nek bizonyul, (c) a piacra jutási határidő
fontosabbá válik a kontrollnál.
