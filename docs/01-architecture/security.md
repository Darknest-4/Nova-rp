# Security Plan

> Alaptétel: **a kliens ellenséges.** Nem „lehet, hogy módosított" — hanem a
> biztonsági modellben mindig annak tekintjük. Ez nem paranoia, hanem a FiveM-környezet
> valósága, amit a hivatalos Cfx dokumentáció is így kezel.

---

## 1. Fenyegetésmodell

| # | Fenyegetés | Példa | Hatás |
| --- | --- | --- | --- |
| T1 | **Event abuse** | Cheat kliensről `nova:money:add` hívása | Gazdaság összeomlása |
| T2 | **Permission bypass** | Admin-event hívása jogosultság nélkül | Teljes szerver-átvétel |
| T3 | **Duplication** | Ugyanaz a trade kétszer, race-ben | Item/pénz-infláció |
| T4 | **Client authority** | Kliens küldi a pénzösszeget/pozíciót | Tetszőleges érték |
| T5 | **Injection** | SQL a játékos nevében, HTML a chatben | Adatlopás, XSS a NUI-ban |
| T6 | **Insecure export** | Export, ami ellenőrzés nélkül ad itemet | Bármely resource-ból kihasználható |
| T7 | **Rate-limit bypass** | Event-flood | DoS, tick-összeomlás |
| T8 | **Race condition** | Egyidejű vásárlás egy fedezetből | Negatív egyenleg |
| T9 | **Sensitive data exposure** | IP/licenc a logban, kliensnek küldött admin-lista | Adatvédelmi incidens |
| T10 | **Entity spam** | Kliens járműveket spawnol | Szerver- és kliens-crash |
| T11 | **Resource injection** | Rosszindulatú third-party resource | Teljes kompromittálódás |
| T12 | **Admin-rendszer megkerülése** | txAdmin menü a NOVA jogosultságok mellett | Auditálatlan beavatkozás |

---

## 2. Védelmi rétegek

```
┌─ 0. PLATFORM ────────── sv_entityLockdown · sv_pureLevel · stateBagStrictMode ·
│                         rate limiterek · block_net_game_event · sv_scriptHookAllowed=false
├─ 1. HÁLÓZAT (nova_net) ─ séma-validáció · típus · tartomány · rate limit · flood-detektor
├─ 2. JOGOSULTSÁG ──────── RBAC node-ellenőrzés minden védett műveletnél
├─ 3. KONTEXTUS ────────── távolság · birtoklás · állapot · cooldown · feature flag
├─ 4. ÜZLETI LOGIKA ────── fedezet · limit · tranzakció · idempotencia
├─ 5. ADAT ─────────────── prepared statement · CHECK · FOR UPDATE · UNIQUE
└─ 6. MEGFIGYELÉS ──────── audit log · anomália-detektor · riasztás
```

Egyetlen réteg sem elég önmagában. Minden érzékeny művelet **mind a hat** rétegen áthalad.

---

## 3. Platform-szintű beállítások (0. réteg)

A `server/cfg/10-security.cfg` generált tartalma, minden érték indoklással:

```cfg
# — Entitás-kontroll ————————————————————————————————
set sv_entityLockdown "strict"        # kliens nem hozhat létre entitást (Enhanced: "full")
setr sv_stateBagStrictMode "true"     # kliens nem írhat replikált state baget

# — Kliens-integritás ————————————————————————————————
sv_scriptHookAllowed 0                # ScriptHook = azonnali sebezhetőség
set sv_pureLevel 2                    # minden módosított kliensfájl blokkolva

# — Ismert visszaélési vektorok ————————————————————————
set sv_enableNetworkedSounds "false"          # NETWORK_PLAY_SOUND_EVENT
set sv_enableNetworkedPhoneExplosions "false" # REQUEST_PHONE_EXPLOSION_EVENT
set sv_enableNetworkedScriptEntityStates "false"

# — Identitás ————————————————————————————————————————
set sv_endpointPrivacy "true"         # IP ne kerüljön publikus reportba
set sv_authMinTrust 4                 # spoofing-ellenállás (mérés alapján hangolandó)
set sv_authMaxVariance 1

# — Entity control kérések szűrése ————————————————————
set sv_filterRequestControl 4         # policy (a pontos mód a Phase 23 tesztje után)

# — Rate limiterek (Enhanced) ————————————————————————
set rateLimiter_netEvent_rate 50
set rateLimiter_netEvent_burst 200
set rateLimiter_stateBag_rate 75
set rateLimiter_stateBag_burst 125
```

> Ezek az értékek **kiindulópontok** a hivatalos dokumentációból, nem végleges
> hangolás. A `sv_filterRequestControl` és az `authMinTrust` konkrét módja a Phase 23
> tesztje után rögzül, mérési adattal — ezt nem tippeljük meg előre.

**Tiltott game eventek** (`block_net_game_event`): a listát a Phase 23-ban állítjuk össze
a Cfx `game-references/net-game-events` alapján, minden tételnél indokolva, hogy
mire használják visszaélésre és mit veszítünk a tiltásával.

---

## 4. A `nova_net` réteg (1–3. réteg)

**Ez a projekt egyik legfontosabb biztonsági eleme.** Nyers `RegisterNetEvent` a
gameplay-kódban **tilos** — minden kliens→szerver kommunikáció a `nova_net`-en megy.

### 4.1 Mit csinál minden bejövő eventnél

```
1.  Ismert-e az event?               → nem: eldobás + biztonsági log
2.  Feature flag aktív?              → nem: csendes eldobás
3.  Rate limit (per player/globális) → túllépés: eldobás + számláló
4.  Flood-detektor                   → küszöb felett: automatikus korlátozás + riasztás
5.  Payload méret                    → limit felett: eldobás
6.  Séma-validáció (típus, tartomány, hossz, enum, minta)
7.  Permission node ellenőrzés       → hiány: eldobás + AUDIT (jogosultatlan kísérlet!)
8.  Kontextus: távolság, birtoklás, állapot, cooldown
9.  Handler futtatása védett módban (pcall) → hiba: naplózás, nem szerver-crash
10. Auditálás, ha a művelet érzékeny
```

Minden elutasítás strukturáltan naplózódik: `event`, `source`, `identifiers`, `reason`,
`payload hash`. **Ez a rendszer legfontosabb anticheat-adatforrása** — nem külső
anticheat-scriptek, hanem a saját elutasítási statisztikánk.

### 4.2 Séma-példa

```lua
Nova.Net.Define('shop:buy', {
    direction = 'c2s',
    schema = {
        shopId   = { type = 'string', maxLen = 32, pattern = '^[a-z0-9_]+$' },
        itemId   = { type = 'string', maxLen = 48, pattern = '^[a-z0-9_]+$' },
        quantity = { type = 'number', integer = true, min = 1, max = 100 },
    },
    rateLimit = { per = 'player', max = 10, window = 10 },
    distance  = { to = 'shop', from = 'shopId', max = 3.0 },   -- a boltnál kell állnia
    feature   = 'economy.shops',
})
```

**Amit a schema NEM tartalmaz, azt a handler nem kapja meg.** Extra mező = elutasítás,
nem csendes figyelmen kívül hagyás (a „mit próbált még beküldeni" információ értékes).

### 4.3 Az ár a szerveré

```lua
-- ❌ SOHA
Nova.Net.On('shop:buy', function(src, d)
    Nova.Money.Remove(src, d.price)          -- a kliens küldte az árat!
    Nova.Inventory.Add(src, d.itemId, d.qty)
end)

-- ✅
Nova.Net.On('shop:buy', function(src, d)
    local shop = Config.Shops[d.shopId]                     -- szerveroldali forrás
    local item = shop and shop.items[d.itemId]
    if not item then return end                             -- nem létező áru
    local total = item.price * d.quantity                   -- SZERVER számol
    Nova.Db.Transaction(function(tx) … end,
        { idempotencyKey = Nova.Net.RequestId() })
end)
```

**Amit a kliens sosem küldhet:** ár, egyenleg, pénzösszeg végeredménye, item-tulajdonságok,
XP, jutalom, job/frakció, admin-státusz, jármű-tulajdon, tekintélyes pozíció (teleport),
cooldown lejárta, „már ellenőriztem" jelzés.

### 4.4 Pozíció-ellenőrzés

A pozíciót **mindig szerveroldalról** kérdezzük le (`GetEntityCoords` a szerveren),
soha nem a kliens küldi. Kiegészítés: sebesség-alapú „lehetetlen mozgás" detektor
(két ellenőrzés között megtett távolság / eltelt idő > küszöb → gyanús esemény).

⚠️ A pozíció a szerveren a sync-adatból származik, ami elvben manipulálható —
ezért a távolság-ellenőrzés **szükséges, de nem elégséges** feltétel. A gazdasági
korlátok (limit, cooldown, könyvelés) ettől függetlenül is érvényesek.

---

## 5. Exportok és belső API-k (T6)

- Minden `exports` hívás mögött **ugyanaz** az ellenőrzés fut, mint a net eventnél
  (permission, feature, validáció) — a hívó resource nem élvez bizalmat.
- Az API-k explicit **hívó-azonosítást** kapnak (`GetInvokingResource()`), és a
  privilegizált műveletekhez (item-adás, pénz-adás) **allowlist** tartozik:
  csak a `Config.Security.PrivilegedResources` listában szereplő resource hívhatja.
- Nincs „belső" export ellenőrzés nélkül. Ha egy támadó egyszer bejuttat egy
  rosszindulatú resource-t, a kárt ez a réteg korlátozza.

---

## 6. NUI-biztonság (T5)

| Kockázat | Védelem |
| --- | --- |
| XSS játékos-tartalomból (név, SMS, cégnév) | React alapértelmezett escape-elése; `dangerouslySetInnerHTML` **tiltott** (lint-szabály) |
| NUI callback-visszaélés | Minden `RegisterNUICallback` ugyanazon a validációs rétegen megy át |
| Adatszivárgás a NUI-ba | A kliens csak azt kapja meg, amit látnia szabad; admin-adat sosem megy ki „elrejtve" |
| CSP | Szigorú CSP a NUI oldalon; nincs külső CDN, minden asset lokális |
| Kliens-oldali „jogosultság" | Csak megjelenítés; a szerver mindig újraellenőriz |

---

## 7. Naplózás és megfigyelés (6. réteg)

### 7.1 Kategóriák

| Kategória | Tartalom | Megőrzés |
| --- | --- | --- |
| `audit` | Admin-műveletek, jogosultság-változások (lásd `permissions.md` 8.) | 365 nap |
| `economy` | Minden pénz- és item-mozgás | 180 nap |
| `security` | Elutasított eventek, rate-limit, gyanús minták | 90 nap |
| `system` | Boot, hiba, teljesítmény | 30 nap |
| `player` | Csatlakozás, kilépés, karakterváltás | 90 nap |

Formátum: strukturált JSON, `requestId`-vel összefűzhető. **Titkok és személyes adatok
maszkolva** (`license:abc…***`), a teljes érték csak
`nova.admin.logs.view_sensitive` joggal kérhető le.

### 7.2 Anomália-detektor

Nem külső anticheat, hanem a saját adatainkból építve:

| Jel | Küszöb (kezdeti) | Reakció |
| --- | --- | --- |
| Elutasított event / játékos / perc | > 20 | Automatikus korlátozás + admin-riasztás |
| Pénznövekmény / óra | > konfigurált limit | Jelölés felülvizsgálatra |
| Azonos item mennyisége hirtelen ugrik | > küszöb | Gazdasági riasztás + tranzakció-visszakövetés |
| Teleport-jellegű mozgás | távolság/idő > küszöb | Log + admin-jelzés |
| Egy fiók több egyidejű session | > 1 | Blokk |
| Jogosulatlan admin-event kísérlet | ≥ 1 | **Azonnali** riasztás (ez sosem véletlen) |

**Fontos önkorlátozás:** automatikus **ban** nem történik. A rendszer korlátoz és
riaszt; a végleges döntést ember hozza. Egy hibás küszöb tömeges téves bannolása
többet árt, mint amennyit egy csaló okoz.

---

## 8. Fejlesztési szabályok (code review checklist)

```
[ ] Nincs nyers RegisterNetEvent gameplay-kódban (csak nova_net)
[ ] Minden c2s eventnek van sémája, rate limitje és — ha kell — permission node-ja
[ ] A kliens nem küld árat, összeget, jutalmat, jogosultságot, tulajdont
[ ] Minden pénz/item művelet tranzakcióban, idempotencia-kulccsal
[ ] Nincs string-összefűzött SQL
[ ] Nincs hardcode-olt szöveg (locale kulcs)
[ ] Nincs hardcode-olt jogosultság (if isAdmin)
[ ] Nincs hardcode-olt szám (gameplay-érték → config)
[ ] Nincs hardcode-olt URL / szervernév
[ ] Nincs while true + Wait(0)
[ ] A hibaágak is naplóznak, és nem nyelik el a hibát
[ ] Érzékeny művelet auditálva (actor, target, old, new, reason, result)
[ ] Titok nem kerül logba, kliensre, repóba
[ ] Az új export nem privilegizált allowlist nélkül
```

---

## 9. Biztonsági audit (Phase 23 és projekt vége)

Módszer: **feltételezzük, hogy már bejutottak.** Nem azt kérdezzük, „be lehet-e törni",
hanem hogy „mit tudna csinálni, aki már bent van".

Vizsgálati területek (a specifikáció listája alapján):

1. Event abuse — minden c2s event végigvétele séma és jogosultság szempontjából
2. Permission bypass — minden védett művelet, `test_ace` és NOVA node keresztellenőrzése
3. Duplication — párhuzamos hívások szimulációja (trade, ATM, bolt, csomagtartó)
4. Money exploit — a `money_transactions` könyvelés zárt-e (bevétel = kiadás)
5. Item exploit — item-mérleg konzisztencia-ellenőrzés
6. Injection — SQL és NUI/HTML felületek
7. Insecure exports — allowlist-lefedettség
8. Unsafe callbacks — NUI és szerver-callback validáció
9. Client trust — grep-alapú keresés kliens-eredetű értékek használatára
10. Rate-limit bypass — flood-teszt
11. Race condition — párhuzamossági tesztkészlet
12. Sensitive data exposure — mi megy ki a kliensre, mi kerül logba

Kimenet: `docs/reports/security-audit-<dátum>.md`, minden találathoz súlyosság
(critical/high/medium/low), reprodukció, javítás és **regressziós teszt**.

**A „production ready" kifejezés addig nem használható**, amíg ebben critical vagy
high súlyosságú, nyitott tétel van.

---

## 10. Ellátási lánc (T11)

- Third-party resource csak a [dependencies.md](../00-research/dependencies.md) 7.
  pontja szerinti adatlappal kerülhet be.
- **Escrow-olt (titkosított forrású) resource tilos** — nem auditálható, és a
  Cfx dokumentáció szerint Enhanced-en nem is támogatott.
- A `vendor/` tartalma **pinned commit hash-re** rögzítve, frissítés = külön PR,
  diff-áttekintéssel.
- A `tools/` npm-függőségei `package-lock.json`-nel rögzítve, `npm audit` a CI-ban.
- A build-lánc nem tölt le futásidőben kódot (a `yarn` resource automatikus
  `node_modules` telepítése is felülvizsgálandó — ha használjuk, akkor rögzített
  lockfile-lal).

---

## 11. Incidenskezelés

```
1. ÉSZLELÉS       riasztás vagy bejelentés
2. IZOLÁLÁS       érintett feature kikapcsolása (feature flag!), nem teljes leállás
3. BIZONYÍTÉK     logok és DB-állapot mentése (a rollback előtt!)
4. HATÁSVIZSGÁLAT mit és mennyit érintett — a könyvelésből visszakereshető
5. HELYREÁLLÍTÁS  javítás, szükség esetén célzott adat-korrekció (nem teljes rollback,
                  ha elkerülhető — az minden ártatlan játékost is büntet)
6. UTÓELEMZÉS     root cause, regressziós teszt, dokumentáció
7. KOMMUNIKÁCIÓ   a közösség felé, arányosan és őszintén
```

A feature flag rendszer itt **biztonsági eszköz is**: egy exploitált modult másodpercek
alatt ki lehet kapcsolni anélkül, hogy a szerver leállna.
