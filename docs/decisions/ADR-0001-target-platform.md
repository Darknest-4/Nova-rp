# ADR-0001: Célplatform — FiveM Legacy vs. FiveM for GTAV Enhanced

- **Állapot:** ✅ `Accepted` — elfogadva 2026-08-27
- **Dátum:** 2026-08-27
- **Döntés:** a lentebb javasolt **C) opció** (Legacy elsődleges + Enhanced-kompatibilis kód)

## Kontextus

2026-ban a Cfx.re két platformágat tart fenn:

- **FiveM Legacy** — a GTA V „legacy" (Gen8/Gen9 régi) kliens, a teljes létező
  ökoszisztéma erre épül.
- **FiveM for GTAV Enhanced** — a GTA V Enhanced kiadáshoz, jelenleg **early access**.

A hivatalos „What's Changed in FiveM for GTAV Enhanced" dokumentum alapján ellenőrzött
különbségek (részletesen: [platform-research.md](../00-research/platform-research.md) 1.3):

**Enhanced előnyei számunkra**

| Előny | Jelentőség |
| --- | --- |
| Nincs P2P sync, tiszta client-server modell | Kisebb latency, kevesebb kliens-manipulációs felület |
| `sv_entityLockdown` **`full`** mód | Erősebb entitás-védelem, mint a Legacy `strict` |
| Konfigurálható rate limiterek (token bucket) | Platform-szintű DoS-védelem, amit Legacy-n nem kapunk meg |
| `sv_syncTickRate` explicit hangolás | Mérhető latency/CPU kompromisszum |
| `onesync_mapCellAreaSize`, map bounds | World grid hangolása nagy CCU-hoz |
| Pure mode mindig aktív | Kliens-integritás alapból |
| Sync recording/replay | Determinisztikus sync-regressziós teszt lehetősége |

**Enhanced hátrányai / kockázatai**

| Hátrány | Jelentőség |
| --- | --- |
| **Asset Escrow: „not implemented yet"** | Vásárolt, védett resource-ok nem használhatók |
| **Mumble deprecated**, új Voice API | A teljes voice-stack újratervezendő; a bevett közösségi megoldások Legacy-re épülnek |
| Csak a legújabb gamebuild támogatott | Nem rögzülhetünk stabil buildre |
| Ökoszisztéma-lefedettség ismeretlen | 🔴 nem ellenőriztük, mely third-party resource fut Enhanced-en |
| Early access | Törő változások esélye a fejlesztés alatt |
| KVP-migráció szükséges | Kis, de valós migrációs teher |
| Játékosbázis megoszlása | 🔴 nem tudjuk, a magyar RP-közönség hány százaléka fut Enhanced klienssel |

## Vizsgált lehetőségek

### A) Csak Legacy
- ➕ Legnagyobb ökoszisztéma, legtöbb tapasztalat, legkisebb ismeretlen.
- ➖ Lemondunk a rate limiterekről, a `full` lockdownról és a jobb sync-modellről.
- ➖ Hosszú távon zsákutca, ha a Cfx az Enhanced felé mozdul.

### B) Csak Enhanced
- ➕ Technikailag a legjobb alap egy most induló, nagy projektnek.
- ➖ Early access kockázat, escrow hiánya, voice újratervezés, ismeretlen kompatibilitás.
- ➖ Ha a játékosbázis még nem ott van, kevés játékossal indulunk.

### C) Legacy elsődleges + Enhanced-kompatibilis kód (kettős cél) — **javasolt**
- ➕ Ma működő szerver, holnapi váltási lehetőség.
- ➖ Kettős tesztelés, absztrakciós költség.
- ➖ Néhány Enhanced-előny (rate limiterek) csak akkor él, ha ott futunk.

## Döntés

> **C) — Legacy az elsődleges célplatform, de a kód Enhanced-kompatibilisen íródik.**
>
> *Elfogadva: 2026-08-27.*

Ez a gyakorlatban ezt jelenti:

1. **Nem használunk olyat, ami Enhanced-en megszűnt**: nincs P2P-feltételezés, nincs
   `onesync_enableBeyond`/`sv_enhancedHostSupport`/`sv_protectServerEntities` használat,
   nincs resource-builder, nincs `sv_netHttp2`, nincs `moo 31337` a production-ben.
2. **A voice réteg absztrahált** (`nova_voice`): egy interfész, mögötte
   platform-specifikus megvalósítás. Így az Enhanced Voice API-ra váltás egy modul
   cseréje, nem az egész szerver átírása.
3. **Nem használunk escrow-olt resource-ot** — ez amúgy is biztonsági követelmény
   (lásd `security.md` 10.).
4. **Nincs C#** — nem kell Mono → .NET 10 migrációval foglalkoznunk.
5. **A platform-specifikus convarok konfigurációból jönnek**, platform-detektálással:
   ami Enhanced-only (rate limiterek, `entityLockdown full`), az ott aktiválódik, és
   Legacy-n csendben kimarad — nem hibával.
6. **CI-ban Enhanced smoke teszt** a Phase 2 spike után, amint kiderül, hogy a
   függőségeink futnak-e ott.
7. **Felülvizsgálati pont a Phase 26 (load test) előtt**: ha addigra az Enhanced
   kikerül early accessből, és a függőségeink futnak rajta, a váltás komolyan
   mérlegelendő — a rate limiterek és a `full` lockdown 1000 CCU-nál valódi érték.

## Következmények

- **Könnyebb lesz:** ma elindulni, létező tudásra és resource-okra támaszkodni.
- **Nehezebb lesz:** minden platform-specifikus funkciónál kétszer gondolkodni, és
  a voice réteget absztrakcióval megírni ahelyett, hogy egy kész megoldást beemelnénk.
- **Ha az Enhanced korábban érik be**, a váltás költsége a fenti 7 szabály miatt
  hetekben mérhető, nem hónapokban.

## Felülvizsgálat

Kötelezően újranézzük, ha: (a) az Enhanced kikerül early accessből, (b) az asset
escrow megjelenik Enhanced-en, (c) a Cfx bejelenti a Legacy támogatás végét,
(d) a load teszt azt mutatja, hogy az Enhanced rate limiterek nélkül nem tartható a cél.

## Amit a döntéshez tudni kell, de még nem tudunk

- Milyen arányban futnak a magyar RP-játékosok Enhanced klienssel? *(piaci adat, nem technikai)*
- A `vendor/` függőségeink (ox_lib, oxmysql) futnak-e Enhanced-en? *(Phase 2 spike)*
