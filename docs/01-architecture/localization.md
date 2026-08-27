# Localization Plan — `nova_locale`

> **Kiemelt prioritású rendszer.** A NOVA RP-ben egyetlen, felhasználónak szánt szöveg
> sem lehet kódba égetve. A lokalizáció nem UI-funkció, hanem platformszolgáltatás.

---

## 1. Követelmények (a specifikációból)

| # | Követelmény | Hogyan teljesül |
| --- | --- | --- |
| R1 | Alapértelmezett nyelv `hu`, de csak alapértelmezettként | `Config.Localization.Default`, sehol nincs `hu` a kódban |
| R2 | `hu`, `en`, `de` + tetszőleges további nyelv | Adatvezérelt nyelvregiszter, nincs nyelvlista a kódban |
| R3 | Új nyelv **kódmódosítás nélkül** | Locale fájl + config bejegyzés + validáció + reload |
| R4 | Mindenre kiterjed (UI, HUD, item, job, NPC, log, Discord, loadscreen…) | Lásd 2. |
| R5 | Futásidejű nyelvváltás újracsatlakozás nélkül | Lásd 5. |
| R6 | Hiányzó fordítás **nem crashel**, fallback-lánc | Lásd 4. |
| R7 | A játékos nyelve DB-ben, stabil nyelvkóddal | `players.locale`, BCP-47 részhalmaz |
| R8 | Automatikus validátor (hiányzó/dupla/placeholder-hiba/üres/invalid) | Lásd 7. |
| R9 | A gameplay-content is lokalizálható (item, jármű, ingatlan…) | Lásd 6. |

---

## 2. Lefedettségi mátrix

| Terület | Ki rendereli | Melyik nyelven |
| --- | --- | --- |
| NUI (inventory, phone, admin panel, HUD) | kliens | a játékos nyelve |
| Értesítések, hibaüzenetek, siker-üzenetek | kliens | a játékos nyelve |
| 3D szövegek, markerek, help text | kliens | a játékos nyelve |
| Chat-üzenetek (rendszer) | kliens, címzettenként | **címzettenként** a saját nyelve |
| Parancsok súgója, hibái | kliens | a játékos nyelve |
| Item / jármű / ingatlan / vállalkozás nevek, leírások | kliens | a játékos nyelve |
| Job / frakció / rang nevek | kliens | a játékos nyelve |
| NPC-dialógus, küldetésszöveg, tutorial | kliens | a játékos nyelve |
| Loading screen, launcher | kliens | kliens-beállítás → mentett preferencia |
| Discord-üzenetek | szerver | `Config.Localization.Discord` (csatornánként állítható) |
| Admin log **megjelenítése** | kliens/panel | a *néző* admin nyelve |
| Admin log **tárolása** | szerver | **nyelvfüggetlen**: kulcs + paraméterek, nem kész szöveg |
| Szerver konzol-log | szerver | `Config.Localization.Console` (default: `en`, hogy kereshető legyen) |

**Kulcsfontosságú tervezési döntés:** a log és az audit **soha nem tárol lefordított
szöveget**, csak `{key, params}` párost. Így a log utólag bármely nyelven megjeleníthető,
és a fordítás javítása visszamenőleg is hat.

---

## 3. Architektúra

### 3.1 Hol dől el a fordítás

```
   SZERVER                                        KLIENS
┌────────────────────────┐                  ┌──────────────────────────┐
│ üzleti logika          │                  │ nova_locale (client)     │
│   ↓                    │   {key, params}  │   dict[locale]           │
│ Nova.Notify(src,       │ ───────────────► │   render(key, params)    │
│   'money.received',    │   (MessagePack)  │   ↓                      │
│   { amount = 5000 })   │                  │ NUI / HUD / chat         │
└────────────────────────┘                  └──────────────────────────┘
```

**A szerver kulcsot és paramétereket küld, nem szöveget.** Előnyei:

- kicsi payload (kulcs + számok, nem mondat),
- a nyelvváltás azonnali, mert a kliens rendereli,
- ugyanaz az esemény minden játékosnak a saját nyelvén jelenik meg,
- a fordítás javítása nem igényel szerveroldali változást.

**Kivételek, ahol a szerver renderel** (mert nincs kliens a másik oldalon):
Discord webhook, konzol-log, külső API. Ilyenkor a szerver a **teljes szótárat**
memóriában tartja minden nyelvre (kis méret: néhány MB), és explicit nyelvet kap:

```lua
Nova.Locale.Render('hu', 'money.received', { amount = 5000 })
```

### 3.2 Fájlszerkezet

Locale fájlok **resource-onként**, hogy a modul önhordó és kikapcsolható maradjon:

```
resources/[nova-core]/nova_locale/locales/          # platform-szintű kulcsok
resources/[nova-gameplay]/nova_money/locales/
    hu.json
    en.json
    de.json
```

`fxmanifest.lua`-ban:

```lua
nova_locales 'locales'      -- opcionális; ez az alapértelmezett útvonal
```

### 3.3 Fájlformátum — JSON, hierarchikus

```json
{
  "money": {
    "received": "{amount} Ft érkezett a számládra.",
    "not_enough": "Nincs elég pénzed. Hiányzik: {missing} Ft.",
    "items_taken": {
      "one":   "{count} tárgyat vettél el.",
      "other": "{count} tárgyat vettél el."
    }
  }
}
```

Betöltéskor laposítjuk: `money.received`, `money.not_enough`, `money.items_taken`.

**Miért JSON és nem Lua/YAML:**

- gépi validálhatóság és szerkeszthetőség (fordítói eszközök, Crowdin-szerű platformok),
- nem futtatható kód → egy locale fájl nem lehet támadási felület,
- a `json.decode` beépített és gyors.

### 3.4 Placeholder-szintaxis

**Névvel ellátott helyettesítők, kapcsos zárójellel:** `{amount}`, `{playerName}`.

❌ Nem `string.format` (`%s`, `%d`): a pozicionális helyettesítők nyelvek között
felcserélődhetnek, és a validátor sem tud róluk értelmesen nyilatkozni.

Formázási módosítók (a formázás **nyelvfüggő**, ezért a rendererben van):

| Szintaxis | Jelentés | `hu` | `en` | `de` |
| --- | --- | --- | --- | --- |
| `{amount}` | nyers érték | `5000` | `5000` | `5000` |
| `{amount:number}` | ezres tagolás | `5 000` | `5,000` | `5.000` |
| `{amount:money}` | pénznem (configból) | `5 000 Ft` | `$5,000` | `5.000 €` |
| `{time:duration}` | időtartam | `2 óra 5 perc` | `2h 5m` | `2 Std. 5 Min.` |
| `{date:datetime}` | dátum/idő | `2026.08.27. 14:30` | `Aug 27, 2026 2:30 PM` | `27.08.2026 14:30` |
| `{name:upper}` | nagybetű | locale-tudatos | | |

A `money` formátum a `Config.Economy.Currency` + nyelvi formázási szabály kombinációja —
így egy pénznemváltás nem igényel 3 nyelv átírását.

### 3.5 Többes szám (plural)

CLDR plural-kategóriákat használunk (`zero`, `one`, `two`, `few`, `many`, `other`).
Nyelvenként a szabály **adatként** van megadva, nem kódban:

```json
// locales/_meta/hu.json
{
  "code": "hu",
  "name": "Magyar",
  "nativeName": "Magyar",
  "fallback": "en",
  "plural": "germanic",          // one | other   (n == 1 → one)
  "numberFormat": { "group": " ", "decimal": "," },
  "dateFormat": "YYYY.MM.DD."
}
```

Beépített plural-szabálykészletek: `germanic` (hu, en, de, …), `slavic_ru`,
`slavic_pl`, `romance`, `asian_none` (nincs többes szám), `arabic`.
Új nyelvhez, ha nincs illő szabály, **akkor** kell kód — ezt a `risks.md` rögzíti.

---

## 4. Fallback-lánc

```
1. a játékos nyelve                     (players.locale)
2. a nyelv saját fallbackje             (_meta/<lang>.json → "fallback")
3. Config.Localization.Default          (pl. "hu")
4. Config.Localization.UltimateFallback (pl. "en")
5. maga a kulcs, [] jelöléssel          → "[money.received]"
```

**Soha nincs crash, soha nincs üres string.** A `[kulcs]` alak azonnal láthatóvá teszi a
hiányt tesztelés közben, és ilyenkor a `nova_locale` egyszer (nem minden híváskor)
naplózza a hiányzó kulcsot, aggregálva.

Példa a specifikációból: `de` játékos, hiányzó `de` kulcs → `en` (a `de` fallbackje) →
ha ott sincs → `hu` (server default) → ha ott sincs → `[kulcs]`.

Fejlesztői módban (`Config.Localization.StrictDev = true`) a hiányzó kulcs **hibát**
dob a CI-integrációs tesztben — így a hiány nem tud production-be jutni.

---

## 5. Nyelvváltás futásidőben

```
Játékos: Beállítások → Nyelv → Deutsch
   ↓
client: nova:locale:setLanguage { code = 'de' }
   ↓
server: validáció (a 'de' engedélyezett-e a configban?)
        → DB: UPDATE players SET locale = 'de'   (write-behind, azonnali flush)
        → Player state bag: locale = 'de'
        → válasz: a 'de' szótár delta-ja, ha a kliens még nem tölthette be
   ↓
client: dict csere → NUI 'locale:changed' event → minden nézet újrarenderel
        → HUD, 3D szövegek, markerek frissítése
   ↓
KÉSZ — újracsatlakozás nélkül
```

**Kliensoldali szótár-kezelés:**

- A kliens induláskor **csak a saját nyelvét** tölti be (+ a fallbackeket), nem mindet.
- Nyelvváltáskor az új szótár betöltése `LoadResourceFile`-lal (helyi fájl, nincs
  hálózati költség), mert a locale fájlok a resource-csomag részei.
- A NUI ugyanezt a szótárat kapja meg egyszer, `postMessage`-en.

**Első csatlakozás (még nincs DB-rekord):**
1. a `playerConnecting` deferral opcionálisan felkínálja a nyelvválasztót
   (Adaptive Card — a platform támogatja), vagy
2. a kliens `GetConvar('nova:locale')`-jét / a kliens nyelvi beállítását javasoljuk, majd
3. a karakterlétrehozás első lépése a nyelvválasztás.
A választás ezután a DB-ből jön minden belépéskor.

---

## 6. Content-lokalizáció

A gameplay-tartalom **soha nem tárol megjelenítendő szöveget**, csak kulcsot.

```lua
-- resources/[nova-gameplay]/nova_inventory/config/items.lua
{
    id        = 'water_bottle',
    nameKey   = 'items.water_bottle.name',           -- konvenció szerint elhagyható
    descKey   = 'items.water_bottle.description',
    weight    = 500,
    stackable = true,
}
```

Ha a `nameKey` hiányzik, a rendszer a konvencióból képzi: `items.<id>.name`.
Így a legtöbb itemhez nem kell külön kulcsot megadni — **de a validátor akkor is
ellenőrzi, hogy a kulcs létezik minden engedélyezett nyelven.**

Ugyanez vonatkozik: járművek, ingatlanok, vállalkozások, jobok, frakciók, rangok,
küldetések, NPC-k, achievementek.

**DB-ben tárolt, játékos által létrehozott tartalom** (pl. vállalkozás neve, SMS
szövege) természetesen nem fordítható — ezt a rendszer explicit `raw` értékként kezeli,
és a validátor nem is várja el hozzá a kulcsot.

---

## 7. Locale validátor (CI-kötelező)

`tools/src/locale/` — Node 22 + TypeScript CLI.

```bash
npm run locale:validate            # teljes ellenőrzés, hibánál exit 1
npm run locale:validate -- --fix   # rendezés, formázás, üres kulcsok kiemelése
npm run locale:report              # lefedettségi riport nyelvenként
npm run locale:extract             # kulcsok kigyűjtése a forráskódból
```

### Ellenőrzések

| # | Ellenőrzés | Súlyosság |
| --- | --- | --- |
| 1 | Érvénytelen JSON | ERROR |
| 2 | Hiányzó kulcs (a referencianyelvhez képest) | ERROR |
| 3 | Ismeretlen/felesleges kulcs (nincs a referenciában) | WARNING |
| 4 | Duplikált kulcs (JSON-on belül, vagy laposítás után ütközés) | ERROR |
| 5 | Üres fordítás (`""` vagy csak whitespace) | ERROR |
| 6 | **Hiányzó placeholder** (a referenciában van, a fordításban nincs) | ERROR |
| 7 | **Ismeretlen placeholder** (a fordításban van, a referenciában nincs) | ERROR |
| 8 | Ismeretlen formázó (`{x:foo}`) | ERROR |
| 9 | Hiányzó plural-kategória a nyelv szabályaihoz képest | ERROR |
| 10 | Kódban hivatkozott, de sehol nem definiált kulcs | ERROR |
| 11 | Definiált, de kódban nem használt kulcs | WARNING |
| 12 | Hiányzó `_meta/<lang>.json` | ERROR |
| 13 | Fallback-lánc körkörös vagy nem létező nyelvre mutat | ERROR |
| 14 | Content-kulcs hiány (item/job/vehicle id-hez nincs név/leírás) | ERROR |
| 15 | Gyanús hardcode a kódban (magyar/német ékezetes literál) | WARNING |

### Példa kimenet (a specifikációban kért eset)

```
✖ 2 hiba, 1 figyelmeztetés

resources/[nova-gameplay]/nova_money/locales/de.json
  ERROR  money.received
         Missing placeholder: {amount}
         reference (hu): "{amount} Ft érkezett a számládra."
         de:             "{value} erhalten"
  ERROR  money.received
         Unexpected placeholder: {value}

resources/[nova-gameplay]/nova_money/locales/en.json
  WARN   money.legacy_notice
         Unused key (nincs rá hivatkozás a forráskódban)

Lefedettség:  hu 100.0% (412/412) · en 99.5% (410/412) · de 87.1% (359/412)
```

### Hardcode-detektor (15. ellenőrzés)

Statikus elemzés a Lua/TS forrásokon: gyanús minden olyan string literál, amely
felhasználónak megjelenő függvénybe kerül (`Notify`, `Chat`, `ShowHelp`, `Draw3DText`,
`AddCommandHelp`, …). A találat CI-figyelmeztetés; szándékos kivétel a
`--[[ nova-locale-ignore ]]` megjegyzéssel jelölhető, **indoklással**.

---

## 8. Hot reload

```
> nova locale reload            # szerverkonzolról
[NOVA] Locale reload: 3 nyelv, 2841 kulcs, 14 ms
[NOVA] 47 kliensnek kiküldve a változás-jelzés
```

Fejlesztői környezetben fájlfigyelés is (`Config.Localization.WatchFiles = true`),
production-ben kikapcsolva.

---

## 9. Új nyelv hozzáadása (a végállapot)

```
1. tools/            npm run locale:new -- --code pl --name "Polski" --fallback en
                     → létrehozza a _meta/pl.json-t és a pl.json vázakat minden resource-ban
2. fordítás          a generált fájlok kitöltése
3. config            Config.Localization.Available += "pl"
4. validáció         npm run locale:validate
5. reload / restart  nova locale reload
```

**Kódmódosítás: nincs.** Kivétel: ha a nyelvhez olyan plural-szabály kell, ami még
nincs a beépített készletben (lásd 3.5) — ez a rendszer egyetlen ismert, dokumentált
korlátja.

---

## 10. Teljesítmény

| Szempont | Megoldás |
| --- | --- |
| Szótár-méret | Kliens: csak a saját nyelv + fallback (~100–300 KB) |
| Render-költség | Előre fordított (compiled) minta: a kulcs első használatakor a
  `{...}` darabolást egyszer végezzük el, utána cache-elt szegmenslistából épül a string |
| Memória szerveren | Minden nyelv memóriában (log/Discord miatt): 3 nyelv ~3–8 MB |
| NUI | A szótár egyszer, `postMessage`-en; a React `useLocale()` hookkal, kontextusban |
| Hiányzó kulcs naplózása | Aggregált, kulcsonként egyszer/óra — nem log-flood |

---

## 11. Publikus API

```lua
-- SZERVER
Nova.Locale.Of(source)                             --> 'hu'
Nova.Locale.Render(lang, key, params)              --> string (log, Discord, konzol)
Nova.Locale.Exists(lang, key)                      --> boolean
Nova.Locale.Set(source, 'de')                      --> ok, err
Nova.Locale.Available()                            --> { 'hu', 'en', 'de' }

-- KLIENS
locale(key, params)                                --> string (a játékos nyelvén)
Nova.Locale.Current()                              --> 'hu'
Nova.Locale.OnChange(function(newLang) end)

-- ÜZENETKÜLDÉS (a szerver soha nem küld kész szöveget)
Nova.Notify(source, 'money.received', { amount = 5000 })
Nova.Notify(source, { key = 'money.received', params = { amount = 5000 },
                      type = 'success', duration = 5000 })
```

Tiltott (a code review elutasítja):

```lua
player.notify("Sikeresen megkaptad a pénzt!")      -- ❌ hardcode
TriggerClientEvent('chat:addMessage', src, {args={'Siker!'}})  -- ❌ kész szöveg
Nova.Notify(src, Nova.Locale.Render('hu', 'money.received'))   -- ❌ szerver rendereli
```
