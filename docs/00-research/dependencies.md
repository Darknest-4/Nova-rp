# Dependencies — ellenőrzött third-party függőségek

> A projekt szabálya: minden third-party resource/library esetén ellenőrizni kell a
> **forrást, verziót, licencet, függőségeket és biztonsági kockázatot**, és dokumentálni.
> Ez a dokumentum ennek az eredménye.
>
> **Ellenőrzés dátuma: 2026-08-27.** Az adatok a repository-k közvetlen klónozásából
> származnak (nem release-oldalról, nem tutorialból).

---

## 1. Jelöltek és állapotuk

| Resource | Repo | Utolsó commit | Verzió | Licenc (LICENSE fájl szerint) | Aktív? |
| --- | --- | --- | --- | --- | --- |
| **ox_lib** | `overextended/ox_lib` | 2026-08-17 | 3.39.0 | **LGPL-3.0-or-later** | ✅ igen |
| **oxmysql** | `overextended/oxmysql` | 2026-07-03 | — | **LGPL-3.0-or-later** | ✅ igen |
| **ox_core** | `overextended/ox_core` | 2026-08-17 | 1.5.14 | ⚠️ **ellentmondásos** (lásd 3.) | ✅ igen |
| **ox_inventory** | `overextended/ox_inventory` | 2026-08-07 | 2.47.9 | **GPL-3.0** | ✅ igen |
| **qbx_core (Qbox)** | `Qbox-project/qbx_core` | 2026-08-22 | 1.24.0 | **GPL-3.0** (es_extended eredetű) | ✅ igen |
| **esx_core (ESX)** | `esx-framework/esx_core` | 2026-08-16 | v1.14.1 | **GPL-3.0** | ✅ igen |
| **txAdmin** | FXServer-rel szállítva | — | build-hez kötött | — | ✅ (beépített) |

Megjegyzés: a hivatalos Cfx dokumentáció `server-manual/frameworks.md` listája
(ESX, ND, QBCore, Qbox, vRP, VORP) informatív, a Cfx **nem támogat** egyetlen frameworköt sem.

## 2. Manifest-szintű követelmények (közvetlenül a `fxmanifest.lua`-ból)

```lua
-- ox_lib 3.39.0
dependencies { '/server:7290', '/onesync' }

-- ox_inventory 2.47.9
dependencies { '/server:6116', '/onesync', 'oxmysql', 'ox_lib' }

-- qbx_core 1.24.0
dependencies { '/server:10731', '/onesync', 'ox_lib', 'oxmysql' }
```

**Következmény:** a Qbox-alapú út legalább **FXServer build 10731**-et követel meg —
ez összhangban van azzal, hogy amúgy is naprakész artifactot kell futtatnunk.
Mindegyik függőség `/onesync`-et követel, ami nálunk adott.

## 3. Licencelemzés — ez a legfontosabb rész

> ⚠️ **Nem vagyunk jogászok.** Az alábbi elemzés a licencszövegek olvasásán alapul, és
> a döntéshez ügyvédi megerősítés ajánlott, ha a projekt zárt forráskódú vagy kereskedelmi.

### 3.1 LGPL-3.0 (ox_lib, oxmysql)

- Az LGPL célja, hogy a **könyvtárat** használó, de attól elkülönülő mű ne legyen
  köteles ugyanazon licenc alá kerülni.
- A FiveM resource-modellben az ox_lib "linkelése" `@ox_lib/init.lua` shared_script
  betöltéssel és exportokkal történik — ez inkább dinamikus linkelés jellegű.
- **Gyakorlati álláspont:** az ox_lib és az oxmysql használata **nem** kényszeríti a
  NOVA RP kódját GPL alá, feltéve hogy magukat a könyvtárakat módosítatlanul,
  a licencszöveggel és attribúcióval együtt terjesztjük. Ha módosítjuk őket,
  a **módosítás** kerül LGPL alá, a mi kódunk nem.

### 3.2 GPL-3.0 (ox_inventory, qbx_core, esx_core)

- A GPL-3.0 copyleft: aki a származékos művet megkapja, jogosult a teljes forráskódra.
- Ha a NOVA RP magja **qbx_core-ra épül** (annak API-jára és adatmodelljére), az erős
  érv amellett, hogy a NOVA RP származékos mű → **a teljes szervert GPL-3.0 alatt kell
  kiadni**, ha bárkinek átadjuk (pl. hosting partner, társfejlesztő, eladott másolat).
- Ugyanez igaz az ox_inventory-ra: az inventory API-jára épülő gameplay-kód
  származékosnak minősülhet.
- Az ox_core `NOTICE.md` kifejezetten kimondja: titkosítás/obfuszkáció, ami megakadályozza
  a jogosultságok gyakorlását, **nem megengedett**. Tehát escrow-olt/zárt terjesztés
  ezekkel kizárt.

### 3.3 ⚠️ Talált ellentmondás: ox_core licenc

Az `overextended/ox_core` repository-ban:

| Hely | Állítás |
| --- | --- |
| `LICENSE` fájl | GNU **Lesser** General Public License, Version 3 |
| `package.json` → `license` | `LGPL-3.0-or-later` |
| `NOTICE.md` | *"This project is licensed under the **GPL-3.0** or later"* |

Ez valós, dokumentált ellentmondás a projekt saját fájljai között. **Amíg ez nem
tisztázott (upstream issue vagy a szerzők megerősítése), az ox_core-t úgy kezeljük,
mintha GPL-3.0 lenne** — ez a konzervatív, biztonságos értelmezés.

**Teendő:** ha az ox_core alapú út kerül szóba, nyitni kell egy upstream kérdést, és
a választ ide dokumentálni. Ezt a döntés előtt kell megtenni, nem utána.

---

## 4. Döntési mátrix — mire épüljön a NOVA RP

| Szempont | **A) Saját mag + LGPL libek** | **B) Qbox (qbx_core) alap** | **C) ox_core alap** | **D) ESX alap** |
| --- | --- | --- | --- | --- |
| Licenc-kötelezettség | Szabad (mi döntünk) | **GPL-3.0 kötelező** | GPL-3.0 (feltételezve) | **GPL-3.0 kötelező** |
| Kezdeti fejlesztési idő | **Nagy** (mindent mi írunk) | Kicsi | Kicsi–közepes | Kicsi |
| Kontroll a kód felett | **Teljes** | Részleges (upstream diktál) | Részleges | Részleges |
| Lokalizáció per-player | **Tervezhető** | ❌ nincs (lásd 5.) | ❌ nincs | ❌ nincs |
| Permission rendszer | **Saját RBAC, ahogy kell** | Alap ACE/role, bővítendő | Alap | Gyenge |
| Feature flag rendszer | **Beépítve tervezve** | Nincs egységes | Nincs egységes | Nincs |
| Kész gameplay-tartalom | Nincs | **Sok** (script-ökoszisztéma) | Közepes | **Legtöbb** |
| Skálázási kontroll (tick-budget) | **Teljes** | Öröklünk ismeretlen költséget | Jó (modern kód) | Rossz (régi minták) |
| Upstream biztonsági javítások | Nekünk kell | Kapjuk | Kapjuk | Kapjuk |
| Third-party script kompatibilitás | Bridge kell | **Natív** | Közepes | **Natív** |

### Ajánlás

> **A) Saját NOVA mag + LGPL könyvtárak (ox_lib, oxmysql), opcionális kompatibilitási
> bridge-ekkel.**

Indoklás:

1. A NOVA RP kiírt követelményei (per-player lokalizáció mindenre, központi feature flag
   rendszer, node-alapú RBAC lejáró jogosultságokkal és audittal, tick-költségvetés,
   konfigurációs validáció) **egyik létező frameworkben sincsenek meg**. Bármelyikre
   építve ezeket úgyis meg kell írni — de akkor egy idegen adatmodell köré, GPL-kötelezettséggel.
2. A GPL-3.0 stratégiai döntés, nem technikai apróság: eldönti, lehet-e a NOVA RP
   zárt vagy kereskedelmi. Ezt **tudatosan** kell választani.
3. A `ox_lib` és `oxmysql` LGPL — ezeket biztonsággal használhatjuk. Az `oxmysql`
   kiváltása saját node-mysql2 wrapperre később is lehetséges, ha kell.

**Ha a prioritás a gyors piacra kerülés, akkor a B) Qbox a helyes válasz** — de akkor
a projekt nyílt forráskódú lesz, és a NOVA-specifikus követelmények egy része
(pl. per-player lokalizáció) a Qbox köré épített rétegként valósul meg.

Ez a döntés: [ADR-0002](../decisions/ADR-0002-framework-base.md). **Jóváhagyás szükséges.**

---

## 5. Konkrét technikai megállapítás: a lokalizáció miatt nem elég egy meglévő framework

Az `ox_lib` locale modulját közvetlenül elolvastuk
(`imports/locale/shared.lua`, `resource/locale/server.lua`):

```lua
-- ox_lib/resource/locale/server.lua
function lib.getLocaleKey() return GetConvar('ox:locale', 'en') end
```

Vagyis:

- **Szerveroldalon egyetlen, globális nyelv van** (`ox:locale` convar).
- A `locale(key, ...)` egy **egyetlen, betöltött szótárból** dolgozik, `string.format`
  stílusú (`%s`) helyettesítéssel.
- A kliensoldal a *kliens* beállítását használja, ami nem a mi adatbázisunkból jön.
- Fallback: az `en` betöltése, majd a választott nyelv rámergelése — tehát van fallback,
  de csak `en`-re, és nincs hiányzó-kulcs riportolás.

**Ez a modell strukturálisan nem tudja azt, amit a NOVA RP megkövetel:** hogy ugyanaz a
szerveroldali esemény két játékosnak két különböző nyelven jelenjen meg, és hogy a
játékos futásidőben, újracsatlakozás nélkül nyelvet válthasson.

Ezért a `nova_locale` **saját modul** lesz. Az ox_lib-et emiatt nem dobjuk el
(UI-komponensek, cache, callback, zone-ok miatt hasznos), de a lokalizációt nem rá építjük.
Részletek: [localization.md](../01-architecture/localization.md).

---

## 6. Elfogadott függőségek (javaslat, Phase 2-től)

| Függőség | Verzió-politika | Miért |
| --- | --- | --- |
| `ox_lib` | pinned tag, `vendor/` alatt, dokumentált frissítéssel | UI, cache, callback, zónák, LGPL |
| `oxmysql` | pinned tag | Kiforrott MySQL-réteg (node-mysql2), prepared statement, async |
| `txAdmin` | FXServer beépített | Process-felügyelet, restart, live console |
| Node.js (tooling) | LTS (22.x), `.nvmrc`-ben rögzítve | Locale validátor, migráció, build, tesztek |
| MariaDB | 11.4 LTS (vagy MySQL 8.4 LTS) | oxmysql = MySQL/MariaDB; LTS = hosszú támogatás |
| Redis | 7.x, **opcionális** | Csak ha külső panel vagy shardolás lesz |

**Amit szándékosan NEM használunk induláskor:**

- ❌ GPL-3.0 gameplay-resource-ok (ox_inventory, qbx_*, esx_*) — amíg az ADR-0002 nem dönt
- ❌ Escrow-olt (védett forrású) resource-ok — nem auditálhatók, Enhanced-en nem is működnek
- ❌ Bármi, aminek nincs nyilvános forrása, licence vagy karbantartója

## 7. Függőség-felvételi eljárás (kötelező, Phase 2-től)

Új third-party függőség csak akkor kerülhet be, ha van hozzá kitöltött adatlap:

```
Név / repo / commit hash:
Verzió:
Licenc (a LICENSE fájlból, nem a README-ből):
Függőségei:
Karbantartottság (utolsó commit, nyitott issue-k):
Milyen jogot igényel (DB, HTTP, fájl, natívok)?
Milyen adathoz fér hozzá?
Mit veszítünk, ha megszűnik? (exit-terv)
Alternatívák:
Döntés + indoklás + jóváhagyó:
```

Az adatlapok helye: `docs/dependencies/<név>.md`.
