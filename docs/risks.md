# Kockázati regiszter

> Súlyosság = (valószínűség × hatás). A regiszter élő dokumentum: minden fázis végén
> felülvizsgáljuk, és az új kockázatok bekerülnek.

## Jelölések

| Szint | Jelentés |
| --- | --- |
| 🔴 **KRITIKUS** | Megölheti a projektet vagy súlyos kárt okoz. Aktív kezelés kötelező. |
| 🟠 **MAGAS** | Jelentős csúszás vagy minőségromlás. Terv kell rá. |
| 🟡 **KÖZEPES** | Kezelhető, de figyelni kell. |
| 🟢 **ALACSONY** | Tudomásul véve. |

---

## R1 🔴 A hatókör nagyobb, mint a rendelkezésre álló kapacitás

**Leírás:** a specifikáció 28 fázisa egy teljes RP-platform. A becslés ~24 hónap
egy főnek ([roadmap](roadmap.md)). Ha a csapatméret vagy a határidő ezzel nem áll
összhangban, a projekt félkészen áll meg — ami rosszabb, mint a szűkebb, de kész termék.

**Kezelés:**
- Mérföldkövenkénti, kiadható állapotok (M2 után már játszható a szerver).
- Explicit hatókör-döntés az ADR-0002-nél: saját mag (lassabb) vagy Qbox-alap (gyorsabb).
- A fázisonkénti tényleges ráfordítás visszamérése és a becslések frissítése.
- **Nem kezelés:** „majd gyorsabban dolgozunk".

## R2 🔴 Az 1000+ CCU cél nem teljesül a tervezett feature-készlettel

**Leírás:** a platform tud 2048 slotot, de a mi kódunk terhelése ismeretlen. Előfordulhat,
hogy 400–600 CCU-nál elfogy a tick-headroom.

**Kezelés:**
- Tick-költségvetés az első naptól, CI-ban mérve.
- Lépcsőzetes load teszt, riportokkal (Phase 26).
- Shard-tudatos adatmodell (ADR-0004) — a B opció előkészítve.
- **Kommunikációs szabály:** mérésig nem állítunk CCU-számot.

## R3 🔴 Biztonsági incidens (money/item exploit) éles környezetben

**Leírás:** egy duplikációs hiba órák alatt tönkreteheti a gazdaságot és a
közösség bizalmát.

**Kezelés:**
- Hatrétegű védelem ([security.md](01-architecture/security.md) 2.).
- Minden pénz/item művelet tranzakcióban, idempotencia-kulccsal.
- Teljes könyvelés (`money_transactions`) → visszakövethető és korrigálható.
- Anomália-detektor + riasztás.
- Feature flag = azonnali izoláció incidens esetén.
- Phase 23 audit **kötelező kapu** az élesítés előtt.

## R4 🟠 Licenc-probléma (GPL-3.0 fertőzés)

**Leírás:** ha GPL-3.0 kódra épülünk, a teljes szerver GPL alá kerülhet. Ez utólag
gyakorlatilag visszafordíthatatlan.

**Kezelés:**
- ADR-0002 tudatos döntés, **implementáció előtt**.
- Csak LGPL vendor-függőség, ha a szabad licenc a cél.
- Az ox_core licenc-ellentmondása dokumentálva; amíg nincs tisztázva, GPL-ként kezeljük.
- Jogi szakvélemény, ha kereskedelmi terjesztés merül fel.

## R5 🟠 Legacy/Enhanced platformváltás kényszere

**Leírás:** ha a Cfx a Legacy támogatás végét jelenti be a fejlesztés közben, és a
kódunk Legacy-specifikus, az hónapokat vihet el.

**Kezelés:**
- ADR-0001: Enhanced-kompatibilis kódolási szabályok az első naptól.
- Voice réteg absztrahálva.
- Nincs escrow-függőség, nincs C#.
- Enhanced smoke teszt a CI-ban, amint lehetséges.

## R6 🟠 Third-party függőség megszűnése vagy kompromittálódása

**Leírás:** az ox-ökoszisztéma korábban is élt át fenntartói bizonytalanságot.
Egy elhagyott vagy megtámadott függőség komoly kockázat.

**Kezelés:**
- Minimális függőség-készlet (ox_lib, oxmysql).
- Pinned commit hash, `vendor/`-ban, módosítatlanul.
- Frissítés csak diff-áttekintéssel, külön PR-ben.
- **Exit-terv minden függőséghez** a függőség-adatlapon.
- Az `oxmysql` mögött saját `nova_db` réteg → kiváltható saját wrapperrel.

## R7 🟠 A lokalizációs rendszer költsége alábecsült

**Leírás:** a „minden lokalizált" követelmény minden modult érint, folyamatosan.
Ha nem automatizált, a fordítások szétcsúsznak, és a rendszer csendben elhal.

**Kezelés:**
- A validátor **CI-kapu**, nem opcionális eszköz.
- Hardcode-detektor a code review-ban.
- A kulcs-konvenció generálja a legtöbb content-kulcsot (nem kell kézzel).
- Fordítói munkafolyamat és felelős kijelölése (Phase 5).

## R8 🟡 A write-behind cache adatvesztést okoz összeomláskor

**Leírás:** a flush-ablakon belüli crash elveszti a nem mentett, nem kritikus adatot.

**Kezelés:**
- Pénz, tulajdon, jogosultság **soha** nem write-behind.
- Rövid ablak a fontos adatra (inventory 5 mp).
- Kötelező flush-pontok (kilépés, karakterváltás, leállás, restart-figyelmeztetés).
- txAdmin auto-restart hang esetén → graceful shutdown flush-sal.

## R9 🟡 Linux „courtesy port" instabilitás

**Leírás:** a hivatalos dokumentáció szerint Linuxon nehezebb a natív hibák javítása.

**Kezelés:**
- ADR-0003: a platform-döntés mérés alapján, a Phase 26 után.
- Nincs platform-specifikus kód → a váltás olcsó marad.
- Crash-dump gyűjtés és megőrzés mindkét platformon.

## R10 🟡 Artifact-frissítés törő változást hoz

**Leírás:** a Cfx támogatási ablaka miatt frissíteni **kell** (3 hónap után lekerülünk
a szerverlistáról), de egy új artifact törhet működő funkciót.

**Kezelés:**
- Havi, ütemezett frissítés staging-en, 1 hét megfigyeléssel.
- `manifest.json`-ben rögzített minimum build szám, boot-időben ellenőrizve.
- Rollback-terv (a régi artifact megőrzése).

## R11 🟡 A txAdmin megkerüli a NOVA jogosultsági rendszert

**Leírás:** a txAdmin in-game admin menüje saját jogosultsági rendszert használ,
és a mi auditunk nem látja.

**Kezelés:**
- Minimális txAdmin admin-lista (tulajdonos + üzemeltető).
- A txAdmin hozzáférés 2FA-val, nem publikus porton.
- A `SECURITY.md` és a `PERMISSIONS.md` explicit szabálya.
- A txAdmin saját action log rendszeres áttekintése.

## R12 🟡 Nem szabványos nyelv plural-szabálya

**Leírás:** a beépített plural-szabálykészletek nem fednek le minden nyelvet
(pl. arab, ír, litván). Ilyen nyelv felvétele kódmódosítást igényelne —
ami ütközik a „új nyelv kódmódosítás nélkül" követelménnyel.

**Kezelés:**
- A gyakori szabálykészletek beépítve (germanic, slavic, romance, none, arabic).
- A korlát dokumentálva ([localization.md](01-architecture/localization.md) 3.5).
- Ha ilyen nyelv merül fel: egy adatfájlos szabály-DSL bevezetése (kis, körülhatárolt feladat).

## R13 🟡 Load teszt eszközök korlátai

**Leírás:** valós, nagy CCU-t nehéz szimulálni; a kereskedelmi „fake player"
szolgáltatások megbízhatósága és ToS-megfelelése nem ellenőrzött.

**Kezelés:**
- Háromrétegű mérési stratégia
  ([scale-analysis.md](00-research/scale-analysis.md) 5.2).
- A szintetikus szerveroldali terhelés adja a legtöbb információt a legkisebb kockázattal.
- Valós hullámok a közösséggel, lépcsőzetesen.

## R14 🟢 Bus factor

**Leírás:** ha egyetlen ember ismeri a rendszert vagy fér hozzá a titkokhoz,
a kiesése megbénítja a projektet.

**Kezelés:**
- Dokumentáció-first megközelítés (a tudás a repóban, nem fejekben).
- ADR-ek: a döntések indoklása megmarad.
- Minden kritikus hozzáféréshez legalább két ember (jelszókezelő).
- Runbookok minden üzemeltetési feladathoz.

---

## Felülvizsgálat

| Mikor | Ki | Mit |
| --- | --- | --- |
| Minden fázis végén | fejlesztés | Új kockázatok, szintek frissítése |
| Havonta | üzemeltetés | R2, R3, R10 aktuális állapota |
| Minden incidens után | mindenki | Volt-e regiszterben? Ha nem, miért nem? |
