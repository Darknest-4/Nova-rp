# Configuration & Feature Flags — `nova_config`

> Cél: minden fontos érték konfigurálható, minden fontos funkció ki/be kapcsolható,
> a hibás konfiguráció pedig **indulásnál** derül ki, értelmes hibaüzenettel — nem
> három hét múlva egy éjszakai crash formájában.

---

## 1. Konfigurációs rétegek

Alulról felfelé, a későbbi felülírja a korábbit:

```
1. Séma-alapértelmezés     a modul config/schema.lua-jában megadott default
2. Alap konfiguráció       resources/[nova-*]/<modul>/config/*.lua   (verziókövetett)
3. Környezeti profil       server/cfg/config.<environment>.lua       (dev/staging/prod)
4. Környezeti változók     NOVA_* env / FXServer convar              (titkok, host-specifikus)
5. Futásidejű felülírás    DB `config_overrides` tábla               (adminpanel, feature flag)
```

**Miért ez a sorrend:** a titkok soha nem kerülnek a repóba (4. réteg), a
környezetspecifikus különbségek explicitek (3.), és az üzemeltető a szerver újraindítása
nélkül tud kapcsolni bizonyos dolgokat (5.) — de csak azokat, amelyeket a séma
`runtime = true`-ként jelöl.

### 1.1 Titkok kezelése

**Soha nem kerülhet verziókövetésbe:** DB jelszó, `sv_licenseKey`, Discord bot token,
webhook URL, Tebex secret, RCON jelszó, Steam Web API kulcs, Prometheus jelszó.

```bash
# server/.env         (gitignore-olt, 0600 jogosultság)
NOVA_DB_HOST=127.0.0.1
NOVA_DB_USER=nova_app
NOVA_DB_PASSWORD=…
NOVA_DISCORD_WEBHOOK_ADMIN=…
NOVA_LICENSE_KEY=…
```

A `server.cfg` ezekre **hivatkozik**, nem tartalmazza őket. A `nova_config` induláskor
ellenőrzi, hogy minden kötelező titok jelen van-e, és **a hiányzó titok nevét** írja ki,
soha nem az értékét. Log-ban a titkok automatikusan maszkolva jelennek meg (`nova_logging`).

---

## 2. Séma és validáció

Minden konfigurációs kulcshoz tartozik séma. Ismeretlen kulcs nem csúszhat át némán.

```lua
-- resources/[nova-gameplay]/nova_money/config/schema.lua
return {
    ['Economy.Currency'] = {
        type = 'string', default = 'HUF', enum = { 'HUF', 'EUR', 'USD' },
        description = 'config.economy.currency',      -- lokalizált leírás
    },
    ['Economy.StartingCash'] = {
        type = 'number', default = 5000, min = 0, max = 1000000,
    },
    ['Economy.Banking.MaxTransfer'] = {
        type = 'number', default = 1000000, min = 1,
        requires = { feature = 'economy.banking' },   -- csak ha a feature él
    },
    ['Economy.Banking.TransferFeePercent'] = {
        type = 'number', default = 0.5, min = 0, max = 100,
        runtime = true,                               -- adminpanelből módosítható
    },
    ['Economy.Payday.IntervalMinutes'] = {
        type = 'number', default = 45, min = 5,
        warnIf = function(v) if v < 10 then
            return 'A 10 percnél gyakoribb payday jelentős DB-terhelést okoz.' end end,
    },
}
```

### 2.1 Boot-időben ellenőrzött hibák

| # | Hiba | Súlyosság |
| --- | --- | --- |
| 1 | Ismeretlen konfigurációs kulcs | ERROR (elgépelés → néma alapértelmezés a legrosszabb hibaforrás) |
| 2 | Hiányzó kötelező kulcs (nincs default) | FATAL |
| 3 | Rossz típus | FATAL |
| 4 | Tartományon kívüli érték / nem engedett enum | FATAL |
| 5 | Kikapcsolt feature-től függő kulcs be van állítva | WARNING |
| 6 | Feature-konfliktus (két kizáró feature aktív) | FATAL |
| 7 | Függőség hiánya (feature A igényli B-t, B ki van kapcsolva) | FATAL |
| 8 | Hiányzó titok | FATAL |
| 9 | `warnIf` visszajelzés | WARNING |
| 10 | Deprecated kulcs használata | WARNING + migrációs javaslat |

Hibaüzenet-formátum:

```
[NOVA][FATAL] Configuration error (2 hiba, 1 figyelmeztetés)

  ✖ Economy.StartingCash
      Várt típus: number, kapott: string ("5000")
      Fájl: server/cfg/config.production.lua:14
      Javítás: Economy.StartingCash = 5000

  ✖ Features.Housing.Enabled = true, de Features.Player.Enabled = false
      A housing modul a player modultól függ.
      Javítás: kapcsold be a player modult, vagy ki a housingot.

  ⚠ Economy.Payday.IntervalMinutes = 5
      A 10 percnél gyakoribb payday jelentős DB-terhelést okoz.

  Dokumentáció: docs/CONFIGURATION.md
```

A validátor **CI-ban is fut** (`npm run config:validate`), FXServer nélkül — így a
konfigurációs hiba nem jut el a szerverre.

---

## 3. Feature flag rendszer

### 3.1 Flag-típusok

| Típus | Példa | Feloldás |
| --- | --- | --- |
| **Global** | `Features.Phone.Enabled` | config |
| **Nested** | `Features.Phone.SocialMedia.Enabled` | csak ha a szülő is aktív |
| **Environment** | `Features.Debug.Enabled` (csak dev) | környezeti profil |
| **Permission-based** | `Features.Admin.NoClip` → csak `nova.admin.*` node-dal | config + RBAC |
| **Experimental** | `Features.Experimental.NewInventoryUI` | explicit opt-in, figyelmeztetéssel |
| **Temporary** | `Features.Events.Halloween2026` (lejárati dátummal) | config + `expiresAt` |
| **Percentage rollout** | `Features.Phone.NewUI.Rollout = 10` (%) | stabil hash a játékos ID-ből |

```lua
Features = {
    Phone = {
        Enabled = true,
        SocialMedia = { Enabled = false },
        Marketplace = { Enabled = true },
        News        = { Enabled = true },
    },
    Housing   = { Enabled = true },
    Crafting  = { Enabled = true },
    Drugs     = { Enabled = false },
    Robberies = { Enabled = true },
    Police    = { Enabled = true },
    EMS       = { Enabled = true },
    Businesses= { Enabled = true },
}
```

### 3.2 Mit jelent pontosan a „kikapcsolva"

Ha `Features.Housing.Enabled = false`, akkor **mind a hat** teljesül:

1. A `nova_housing` resource **el sem indul** — a generált `server/cfg/20-resources.cfg`
   nem tartalmazza az `ensure`-t.
2. Nem regisztrál eventet, nem foglal memóriát, nincs tickje.
3. A `Nova.Housing.*` API hívható marad, de tipizált hibát ad
   (`ok = false, err = 'FEATURE_DISABLED'`) — **nem `nil` index crash**.
4. A többi modul boot-időben megkapja a flag-állapotot, és nem próbál rá hivatkozni;
   a séma `requires` mezője kiszűri a lógó függőségeket.
5. Az adminpanel nem jelenít meg housing-funkciót (a menü a flag-állapot alapján épül).
6. A housing DB-migrációi **alkalmazva maradnak** (az adat nem vész el), csak a
   funkció nem elérhető. Ez teszi biztonságossá a ki-be kapcsolást.

### 3.3 Resource-lista generálás

```bash
npm run resources:generate
# → server/cfg/20-resources.cfg (verziókövetett, diffelhető)
```

A generátor a feature flagek + a modulok deklarált függőségei alapján
**topologikus sorrendet** állít elő, és hibát dob körkörös függőségnél.

```cfg
# GENERÁLT FÁJL — kézzel ne szerkeszd. Forrás: server/cfg/config.production.lua
# Generálva: 2026-08-27T14:02:11Z   Feature hash: 8f3a91c

ensure ox_lib
ensure oxmysql
ensure nova_lib
ensure nova_config
…
ensure nova_housing        # Features.Housing.Enabled = true
# nova_drugs               # KIHAGYVA: Features.Drugs.Enabled = false
```

### 3.4 Futásidejű kapcsolás

A `runtime = true`-ként jelölt flagek adminpanelből kapcsolhatók
(`nova.admin.feature.toggle` jog + audit).

- **Bekapcsolható futásidőben:** viselkedésmódosítók (fee, arány, cooldown), UI-elemek,
  al-funkciók, amelyek nem igényelnek resource-indítást.
- **Csak újraindítással:** olyan flag, ami egy resource elindítását/leállítását
  jelentené. A panel ilyenkor egyértelműen jelzi: *"Ez a változás a következő
  szerverindításkor lép életbe"*, és felajánlja az ütemezett restartot.

Ez tudatos döntés: a resource futásidejű `start`/`stop` parancsolgatása nagy CCU-nál
kiszámíthatatlan állapotot hagy maga után (félbeszakadt tranzakciók, árva entitások).

### 3.5 API

```lua
Nova.Feature.Enabled('phone.socialMedia')          --> boolean
Nova.Feature.Enabled('phone.newUI', source)        --> percentage rollout, játékosfüggő
Nova.Feature.Require('housing')                    --> ok, err  (guard modul-belépéskor)
Nova.Feature.All()                                 --> { ['phone'] = true, … }
Nova.Feature.OnChange('economy.banking', fn)       --> futásidejű változás lekezelése
```

Modul-belépési pont mintája:

```lua
-- resources/[nova-gameplay]/nova_housing/server/main.lua
if not Nova.Feature.Require('housing') then return end   -- csendben kilép, nincs hiba
```

---

## 4. Branding és szerver-identitás

**Semmilyen szervernév, URL vagy márkanév nem lehet kódban.**

```lua
Config.Server = {
    Name        = 'NOVA RP',
    ShortName   = 'NOVA',
    Description = 'server.description',    -- LOKALIZÁLT kulcs, nem szöveg!
    Website     = '',                      -- env: NOVA_URL_WEBSITE
    Discord     = '',                      -- env: NOVA_URL_DISCORD
    Logo        = '',                      -- env: NOVA_URL_LOGO
    Environment = 'production',            -- development | staging | production
    Version     = '',                      -- build-időben injektálva
}
```

- A `Description` **kulcs**, mert a szerverleírás is nyelvfüggő.
- Az URL-ek környezeti változóból jönnek (dev/staging/prod más-más Discord).
- A `Version` a build folyamat során íródik be (git tag + rövid commit hash).

Tiltott:

```lua
print('NOVA RP indul…')                    -- ❌
local DISCORD = 'https://discord.gg/…'     -- ❌
sv_hostname "NOVA RP | Magyar szerver"     -- ❌ kézzel a cfg-ben
```

Helyette a `server.cfg` a configból generált értékeket kapja
(`sets sv_projectName`, `sv_hostname` a `Config.Server.Name` alapján).

---

## 5. Konfigurációs fájl formátuma

**Lua**, mert:

- a FXServer natívan olvassa, nincs parse-lépés,
- kommentelhető (a JSON nem),
- számított értékek megengedettek (`60 * 60`), ami a magic number-ek ellen dolgozik,
- a szerkesztők ismerik.

**Kockázat és kezelése:** a Lua config futtatható kód. Ezért a config fájlok
sandboxolt környezetben töltődnek be (nincs `os`, `io`, `require` a config-kontextusban),
és a betöltés eredménye séma-validáláson megy át. Egy config fájl **nem tud** a
szerverbe kódot injektálni.

---

## 6. Magic number tiltás

Minden gameplay-t befolyásoló szám konfigurálható. A code review ellenőrzi.

```lua
-- ❌
if #(coords - shopCoords) < 3.0 then
Wait(5000)
player.money = player.money - 250

-- ✅
if #(coords - shopCoords) < Config.Interaction.MaxDistance then
Wait(Config.Shop.RestockIntervalMs)
Nova.Money.Remove(src, Config.Shop.Items.water.price)
```

Kivétel, amit nem tekintünk magic numbernek: matematikai konstansok, tömbindexek,
0/1 határok, és a `nova_lib` belső implementációs részletei — ezek nem gameplay-értékek.

---

## 7. Konfiguráció-dokumentáció generálása

```bash
npm run config:docs      # → docs/CONFIGURATION.md
```

A sémákból generált, mindig naprakész referencia: kulcs, típus, alapérték, tartomány,
lokalizált leírás, melyik feature-höz tartozik, futásidőben módosítható-e.
**Nincs kézzel karbantartott konfigurációs dokumentáció** — az mindig elavul.
