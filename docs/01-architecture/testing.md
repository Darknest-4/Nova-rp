# Test Plan

> Elv: **ami nincs tesztelve, az nem működik — csak még nem derült ki.**
> Ahol reális, a teszt előbb készül el, mint az implementáció.

---

## 1. Teszt-piramis

```
        ▲  Load test (Phase 26)          ritka, drága, valós adat
       ███ Integration (FXServer + DB)   naponta / PR-onként
      █████ Unit (busted / vitest)       minden commitnál, másodpercek
     ███████ Statikus elemzés            minden mentésnél
```

| Szint | Eszköz | Futásidő-cél | Mikor fut |
| --- | --- | --- | --- |
| Statikus | selene/luacheck, Lua Language Server, tsc, eslint | < 30 mp | commit, PR |
| Séma/adat | locale validátor, config validátor, migráció-verify | < 20 mp | commit, PR |
| Unit (Lua) | **busted** + CFX-mock | < 60 mp | commit, PR |
| Unit (TS/NUI) | **vitest** | < 60 mp | commit, PR |
| Integráció | FXServer (`sv_lan true`) + MariaDB szolgáltatás | < 10 perc | PR, éjszakai |
| Biztonsági | célzott exploit-készlet | < 10 perc | PR, éjszakai |
| Regressziós | minden korábbi hibához tartozó teszt | az integrációval | PR |
| Teljesítmény | szintetikus tick-mérés | < 5 perc | éjszakai |
| Load | `nova_loadtest` + valós hullámok | órák | mérföldkövenként |

---

## 2. Unit tesztek Lua-hoz — a CFX-mock réteg

**A kulcskérdés:** hogyan tesztelünk FiveM-kódot FiveM nélkül. Megoldás: a magmodulok
úgy íródnak, hogy **betöltéskor ne legyen mellékhatásuk**, és a natívokat egy
injektálható rétegen keresztül érjék el.

```lua
-- tests/mocks/cfx.lua
local mock = {}
function mock.install(env)
    env.GetPlayerIdentifiers = function(src) return { 'license:test' .. src } end
    env.GetEntityCoords      = function(e)   return mock.coords[e] or vector3(0,0,0) end
    env.TriggerClientEvent   = function(...) table.insert(mock.sent, {...}) end
    env.GetConvar            = function(k, d) return mock.convars[k] or d end
    env.LoadResourceFile     = function(_, path) return mock.files[path] end
    -- …
end
```

```lua
-- tests/unit/locale_spec.lua
describe('nova_locale', function()
    before_each(function() cfx.reset(); locale = require('nova_locale.shared.locale') end)

    it('a játékos nyelvén renderel', function()
        assert.equals('5 000 Ft érkezett a számládra.',
            locale.render('hu', 'money.received', { amount = 5000 }))
    end)

    it('fallback-láncot követ, ha hiányzik a kulcs', function()
        assert.equals(locale.render('de', 'only.in.en'), locale.render('en', 'only.in.en'))
    end)

    it('soha nem crashel ismeretlen kulcsra', function()
        assert.equals('[nincs.ilyen.kulcs]', locale.render('hu', 'nincs.ilyen.kulcs'))
    end)

    it('nem hagy figyelmen kívül hiányzó placeholdert', function()
        assert.has_error(function()
            locale.strict().render('de', 'money.received', {})
        end)
    end)
end)
```

**Cél:** a `nova_lib`, `nova_config`, `nova_locale`, `nova_permission` és a `nova_db`
query-építő rétege **100%-ban** játék nélkül tesztelhető. Ez a Phase 2 spike egyik
kimenete — ha kiderül, hogy nem megy ésszerű mock-mennyiséggel, azt jelentjük, nem
elkendőzzük.

---

## 3. Integrációs tesztek

### 3.1 Hogyan futtatunk FXServert CI-ban

A `sv_lan true` beállítás mellett a **licenckulcs-ellenőrzés kimarad** (hivatalos
dokumentáció), így a szerver titok nélkül indítható a CI-ban.

```yaml
# .github/workflows/integration.yml (vázlat)
services:
  mariadb:
    image: mariadb:11.4
    env: { MARIADB_ROOT_PASSWORD: test, MARIADB_DATABASE: nova_test }
steps:
  - Artifact letöltése (rögzített build szám, cache-elve)
  - npm run db:migrate           # migrációk a teszt-DB-re
  - FXServer indítása: +set sv_lan true +set nova_mode test +exec test.cfg
  - a nova_test resource lefuttatja a forgatókönyveket
  - eredmény: JSON riport + exit kód (a szerver magától leáll)
```

> ⚠️ Ezt a Phase 2 spike-ban **méréssel** igazoljuk (indulási idő, stabilitás a
> runneren). Ha nem megbízható, az alternatíva egy önhostolt runner egy dedikált
> tesztszerverrel. Nem állítjuk előre, hogy működni fog.

### 3.2 Forgatókönyv-példák

```
[player]     csatlakozás → karakterlétrehozás → mentés → kilépés → visszacsatlakozás
             → az állapot megegyezik
[locale]     nyelvváltás futásidőben → minden felület az új nyelvet mutatja
[permission] role adása → azonnal érvényes; visszavonás → azonnal érvénytelen
[money]      átutalás → mindkét egyenleg helyes → könyvelés zárt
[money]      párhuzamos átutalás ugyanabból az egyenlegből → nincs negatív egyenleg
[inventory]  trade megszakítása félúton → nincs item-vesztés és nincs duplikáció
[feature]    housing kikapcsolása → a resource nem indul, az API tipizált hibát ad
[config]     hibás konfiguráció → a szerver nem indul el, és értelmes hibát ír
[db]         nem alkalmazott migráció production módban → indulás megtagadva
[restart]    szerver leállítása játék közben → az adat mentve, restart után konzisztens
```

---

## 4. Biztonsági tesztkészlet

Automatizált „támadó" forgatókönyvek, amelyek a `nova_net`-en keresztül próbálkoznak:

| Teszt | Elvárt eredmény |
| --- | --- |
| Ismeretlen event hívása | Eldobás + security log |
| Helyes event, rossz típusú mezővel | Eldobás, handler nem fut |
| Extra mező a payloadban | Eldobás |
| Túl nagy payload | Eldobás |
| Admin event jogosultság nélkül | Eldobás + **audit** bejegyzés |
| 1000 event / mp | Rate limit lép életbe, a szerver tickje nem romlik |
| Túl messziről indított bolti vásárlás | Eldobás |
| Ugyanaz a tranzakció kétszer (azonos idempotencia-kulcs) | Második no-op |
| Negatív / tört / óriási mennyiség | Eldobás |
| SQL-jellegű karakterek névben | Tárolás sértetlen, nincs injekció |
| HTML/script a chatben | A NUI szövegként jeleníti meg |

Ezek **regressziós tesztek**: minden megtalált exploithoz kötelezően bekerül egy új eset.

---

## 5. Teljesítmény-tesztek

```lua
-- tests/perf/permission_bench.lua
bench('Permission.Has — 10 000 ellenőrzés', function()
    for i = 1, 10000 do Nova.Permission.Has(1, 'nova.admin.player.kick') end
end, { maxMs = 5 })
```

| Mit mérünk | Küszöb |
| --- | --- |
| `Permission.Has` × 10 000 | < 5 ms |
| `locale.render` × 10 000 | < 10 ms |
| Config-feloldás × 100 000 | < 20 ms |
| `nova_core` teljes szerveroldali tick | < 1 ms |
| Egyedi gameplay-resource tick | < 0,5 ms átlag |
| DB batch flush 1000 játékosra | < 200 ms, tickeken szétterítve |

A küszöb túllépése **hiba**, nem „technikai adósság". A CI ilyenkor pirosat ad.

---

## 6. Load testing (Phase 26)

Részletesen: [scale-analysis.md](../00-research/scale-analysis.md) 5. pont.

Röviden:

1. **Szintetikus szerveroldali terhelés** (`nova_loadtest`) — a mi kódunk költsége
   valós kliensek nélkül. Ez adja a legtöbb információt a legkisebb költséggel.
2. **Entitás-/sync-terhelés** szerveroldali entitásokkal.
3. **Valós játékos-hullámok:** 50 → 100 → 250 → 500 → 750 → 1000 → 1500 → 2000,
   lépcsőnként kötelező riporttal. Lépcsőt átugrani tilos.

**Kimondott szabály:** amíg nincs mérési eredmény, semmilyen CCU-számot nem állítunk —
sem dokumentációban, sem marketingben, sem Discordon.

---

## 7. Kézi tesztelés és QA

Az automatizálás nem fed le mindent: az RP-élmény, az animációk, a UI-érzet, a
hangzás emberi ítéletet kíván.

- Minden modulhoz **QA-forgatókönyv** (`docs/qa/<modul>.md`): lépések, elvárt eredmény,
  élváltozat-esetek.
- Staging-en **playtest** minden nagyobb release előtt, minimum 10 tesztelővel.
- Hibabejelentő sablon: reprodukció, elvárt vs. tényleges, log, `requestId`, verzió.

## 8. Hibakezelési eljárás

A specifikáció szerinti, kötelező sorrend:

```
REPRODUKCIÓ → LOG → DOKUMENTÁCIÓ → ROOT CAUSE → FIX → TESZT → REGRESSZIÓ
```

**Tilos:** találgatásból javítani, „hátha ez volt" commitokat írni, vagy a tünetet
elfedni (pl. `pcall`-lal elnyelni a hibát) a kiváltó ok megértése nélkül.
Minden javított hibához **kötelező** regressziós teszt — enélkül a PR nem mergelhető.

---

## 9. CI pipeline

```yaml
# .github/workflows/ci.yml — vázlat
on: [push, pull_request]
jobs:
  static:      # selene + lua-language-server + tsc + eslint + formázás
  validate:    # locale:validate + config:validate + db:migrate:verify + resources:generate --check
  unit:        # busted + vitest, lefedettségi riporttal
  integration: # FXServer + MariaDB (PR és éjszakai)
  security:    # exploit-készlet + npm audit
  perf:        # benchmarkok küszöbökkel (éjszakai)
```

**Merge-feltételek:**

- minden job zöld,
- nincs új `ERROR` szintű locale/config találat,
- új kódhoz tartozik teszt,
- javított hibához tartozik regressziós teszt,
- a CHANGELOG frissítve,
- a dokumentáció frissítve (ha viselkedés változott).

---

## 10. Fázisonkénti QA-kapu

Minden fázis lezárásának feltétele (a specifikáció 32. pontja szerint):

```
[ ] syntax / statikus elemzés tiszta
[ ] unit tesztek zöldek, az új kód lefedve
[ ] integrációs forgatókönyvek zöldek
[ ] biztonsági tesztek zöldek
[ ] regressziós készlet zöld
[ ] teljesítmény-küszöbök tartva
[ ] locale validátor: 0 ERROR
[ ] config validátor: 0 ERROR
[ ] migrációk alkalmazhatók és visszavonhatók (dev)
[ ] dokumentáció frissítve
[ ] CHANGELOG frissítve
```
