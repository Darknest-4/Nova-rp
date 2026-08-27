# Platform Research — FiveM / Cfx.re környezet

> **Kutatás dátuma:** 2026-08-27
> **Elsődleges forrás:** a hivatalos Cfx.re dokumentáció forrás-repository-ja
> (`github.com/citizenfx/fivem-docs`), ellenőrzött HEAD: `87d92b2`, 2026-08-20.
> A repository-t közvetlenül klónoztuk és a Markdown forrásokat olvastuk, nem
> másodlagos tutorial-okat.

## Jelölések

| Jel | Jelentés |
| --- | --- |
| ✅ **VERIFIED** | Hivatalos Cfx.re dokumentációból vagy közvetlenül a forráskódból ellenőrizve |
| 🟡 **COMMUNITY** | Közösségi/kereskedelmi forrás, nem hivatalos — döntés előtt saját méréssel igazolandó |
| 🔴 **UNVERIFIED** | Nem sikerült megbízhatóan ellenőrizni; feltételezésként kezeljük |

---

## 1. Szerver-runtime alapok

### 1.1 FXServer és artifactok ✅ VERIFIED

- A szerver bináris neve **FXServer** (Windows: `FXServer.exe`, Linux: `run.sh` +
  `fx.tar.xz`). FiveM for GTAV Enhanced esetén a csomag `cfx-server_win_x64` /
  `cfx-server-linux_x64`, a bináris `cfx-server.exe`.
- A Linux build hivatalosan **"courtesy port"**: a dokumentáció szó szerint azt írja,
  hogy Linux-kompatibilitási és natív C++ diagnosztikai eszközök hiánya miatt
  problémák esetén **nagyobb eséllyel javítanak Windows-on jelentett hibát**.
  → Ez production hosting-döntés (ADR-0003), nem ízlés kérdése.
- **Artifact támogatási ablak:** a `recommended` build a következő kiadás után 6 hétig,
  a `latest` a következő kiadás után 2 hétig támogatott. **3 hónapnál régebbi,
  nem támogatott artifacttal futó szerver nem jelenik meg a szerverböngészőben.**
  → Következmény: az artifact-frissítés nem opcionális karbantartás, hanem ütemezett,
  tesztelt release-folyamat része kell legyen (lásd `deployment.md`).
- **Licenckulcs:** `sv_licenseKey`, a portal.cfx.re-ről. **Kivétel:** `sv_lan true`
  esetén a licenckulcs-ellenőrzés kimarad, és a szerver nem kerül a publikus listára.
  → Ez teszi lehetővé a CI-ban futó integrációs teszteket licenckulcs-titok nélkül.

*Forrás: `server-manual/setting-up-a-server-vanilla.md`, `server-manual/end-of-support-end-of-life.md`, `server-manual/server-commands.md`*

### 1.2 Script runtime-ok ✅ VERIFIED

| Runtime | Állapot 2026-08-ban | Megjegyzés |
| --- | --- | --- |
| **Lua** | **Lua 5.4 az alapértelmezett.** 2025 júniusa óta a Lua 5.3 támogatás megszűnt, az `fxmanifest` `lua54 'yes'` direktíva **deprecated**, nem kell megadni. | Ez az elsődleges gameplay-nyelvünk. |
| **JavaScript (V8 / Node)** | Szerveroldalon egy módosított **Node.js 16.x** az alapértelmezett; `node_version '22'` megadásával Node 22 választható resource-onként. Kliensoldalon nincs Node API (nincs DOM/localStorage/fetch-alapú Node modul). | Szerveroldali segéd-service-ekhez és build-toolinghoz. |
| **C# / .NET** | Legacy: Mono. **Enhanced: a Mono helyett .NET, .NET 10 SDK-val.** | A NOVA RP nem tervez C#-ot használni — kettős runtime-karbantartást és Legacy/Enhanced-migrációs kockázatot hozna. |

- A natívok MessagePack-alapú szerializációval hívódnak; a `fxmanifest.lua` deklaratív
  metadata-fájl, `fx_version 'cerulean'` a jelenlegi FXv2 szint (a docs a `rmv2`
  shortcode-ot használja, a gyakorlatban a ma használt érték `cerulean`).

*Forrás: `scripting-reference/resource-manifest/_index.md`, `scripting-manual/runtimes/javascript.md`, `developers/legacy-vs-enhanced.md`, `developers/script-runtimes.md`*

### 1.3 FiveM Legacy vs. FiveM for GTAV Enhanced ✅ VERIFIED

Ez a 2026-os legfontosabb platformdöntés. A hivatalos "What's Changed" dokumentum szerint:

**Enhanced-ben eltávolítva / megváltozva:**

| Terület | Változás | Hatás a NOVA RP-re |
| --- | --- | --- |
| P2P sync | Megszűnt, tiszta client-server modell | Pozitív (kisebb latency) |
| OneSync non-big mode | Megszűnt, csak "big mode" van | A player connect/disconnect eventek csak scope-on belül érkeznek — a player-kezelést eleve szerveroldali listából kell építeni |
| **Asset Escrow** | **"Not implemented yet"** | Ha valaha escrow-olt (védett) third-party resource-t akarunk használni, az Enhanced-en nem működik |
| Mumble | **Deprecated**, új szerveroldali Voice API van | A teljes voice-stack (pl. `pma-voice` típusú megoldások) újratervezendő Enhanced-en |
| Mono | Helyette .NET 10 | Minket nem érint (nincs C#) |
| Pure mode | **Mindig bekapcsolva**, nem kikapcsolható | Grafikai modok tiltva — RP-nél inkább előny, de a játékosbázis egy részének nem tetszik |
| Gamebuild | **Csak a legújabb gamebuild támogatott** | Nem tudunk régebbi buildre rögzülni |
| KVP DB fájlok | **Migrálni kell** | Ha KVP-t használunk, migrációs script kell (a Cfx ígért egyet) |
| `sv_useAccurateSends` | Deprecated → `sv_syncTickRate [1..120]`, default 60 | Új tuning-paraméter |

**Enhanced-exkluzív, számunkra értékes újdonságok:**

- `sv_entityLockdown` **`full`** mód (dummy object creation tiltása) — csak Enhanced-en
- Konfigurálható **rate limiterek** token-bucket algoritmussal
  (`rateLimiter_netEvent_rate/_burst`, `stateBag`, `http_*`, `handshake`, `rcon`, stb.)
- `onesync_mapCellAreaSize`, `onesync_mapBounds*` — world grid tuning
- `sv_ioThreads`, `sv_clientConnectingTimeoutMilliseconds`, `sv_pingIntervalMilliseconds`
- `sv_devMode` (dev mód, **max 8 kliensre korlátoz** — nem production!)
- Sync recording/replay (`sync_start_recording`, `replay_start`) — determinisztikus
  sync-regressziós teszthez elvben használható

**Következtetés:** az Enhanced technikailag jobb alap egy 2026-ban induló, nagy
projektnek (rate limiterek, full lockdown, client-server sync), de **hiányzik belőle
az asset escrow, a voice-stack újratervezést igényel, és a third-party ökoszisztéma
nagy része még Legacy-re készült.** Lásd: [ADR-0001](../decisions/ADR-0001-target-platform.md).

*Forrás: `developers/legacy-vs-enhanced.md`, `server-manual/server-commands.md` (759–913. sor)*

---

## 2. OneSync és a slot-limitek

### 2.1 Kemény limitek ✅ VERIFIED

| Paraméter | Érték | Forrás |
| --- | --- | --- |
| `sv_maxClients` | egész szám **1–2048** | `server-commands.md` |
| 32 slot felett | `onesync` `on` vagy `legacy` kötelező | `server-commands.md` |
| 64 slot felett | `onesync on` kötelező | `server-commands.md` |
| `onesync_enableInfinity` | default `true`, **csak induláskor állítható** | `server-commands.md` |
| Object ID tartomány (Infinity) | 8192 → **65535** | `scripting-reference/onesync/_index.md` |
| Focus zone / culling radius | **424 unit**, hardcoded | `scripting-reference/onesync/_index.md` |
| Player culling | van — **minden player-iteráció szerveroldalon kell történjen** | `scripting-reference/onesync/_index.md` |
| OneSync ingyenes | **48 slotig**; felette Element Club előfizetés a Cfx Portalról (Argentum-tól) | `scripting-reference/onesync/_index.md` |

A hivatalos OneSync dokumentum szó szerint: *"A mode allowing (up to) 2048 players (…)
**There are servers handling 1000+ concurrent players.**"* — tehát a 2048 slot és az
1000+ CCU a platform szintjén nem fantázia. Az, hogy **a mi resource-ainkkal** elérhető-e,
külön kérdés → lásd [scale-analysis.md](scale-analysis.md).

### 2.2 Element Club slot-limitek 🟡 COMMUNITY

Közösségi és hosting-források szerint: Argentum ≤ 64, Aurum ≤ 128, Platinum ≤ 2048 slot.
**Ezt a portal.cfx.re/subscriptions oldalon kell megerősíteni a vásárlás előtt** — az
egyetlen hiteles forrás a Portal maga, és ez a projekt költségvetését közvetlenül érinti.
A `portal.cfx.re` a jelenlegi kutatási környezetből nem volt elérhető.

### 2.3 Routing bucketek ✅ VERIFIED

- Pipeline ID 3245 felett elérhető, "dimension"/"virtual world" jellegű funkció.
- Bucketenként **külön world grid**, külön population-beállítás
  (`SetRoutingBucketPopulationEnabled`), külön entity lockdown mód
  (`SetRoutingBucketEntityLockdownMode`: `full` \| `strict` \| `relaxed` \| `inactive`).
- Hivatalos felhasználási esetek: multi-mode szerver, session/party rendszer,
  karakterválasztó képernyő elkülönítése.
- **Kifejezetten NEM interiorokra való** — arra a `conceal` natívok, illetve a jövőbeli
  3D-scoped routing policy szolgál.

Ez a NOVA RP-nél konkrétan azt jelenti: karakterválasztó/loading külön bucketben,
lakás- és apartman-instance-ok **nem** bucketen keresztül (hacsak nem külön "világ"),
tutorial/onboarding külön bucketben, staff-tesztterület külön bucketben.

### 2.4 Szerveroldali entitások ✅ VERIFIED

- `CreateVehicleServerSetter`, szerveroldali `CreatePed` — az entitás a szerveren jön
  létre, nem a kliensen.
- **Perzisztencia:** `SetEntityOrphanMode(entity, 2)` (`KeepEntity`) — enélkül a szerver
  törölheti az entitást. Fontos: a kliens ettől még kérheti a törlést.
- Vannak **RPC natívok**, amelyek valójában a tulajdonos kliensen futnak le, és
  **nem garantáltan sikeresek** — pl. `CreateVehicle` szerverről.
  → Minden szerveroldali entitás-létrehozásnál hibakezelés és re-try/verify kell.
- A culling natívok (`SET_ENTITY_DISTANCE_CULLING_RADIUS`, `SET_PLAYER_CULLING_RADIUS`)
  a dokumentáció szerint **deprecated, ismert és nem javítható hibákkal** —
  ne építsünk rájuk gameplay-t.

### 2.5 State bagek ✅ VERIFIED

- Entity / player / global state bag, MessagePack-szerializációval.
- **A getterek/setterek naivak**: minden get a teljes szerializált state-et adja vissza,
  és csak a *közvetlen* set szerializál vissza. `Entity(x).state.a.b = 'c'` **nem
  replikálódik** → lapos kulcsokat kell használni (`state['a:b']`).
- Alapértelmezett policy: player state-et a player és a szerver írhatja, entity state-et
  a tulajdonos és a szerver, global state-et csak a szerver.
- **`setr sv_stateBagStrictMode true`** (server build 12739+): a kliens **nem** módosíthat
  replikált entity/player state baget. → **A NOVA RP-nél ez kötelező beállítás.**
- Enhanced-ben: a state bag callback csak akkor fut, ha az entitás létezik; a replikált
  értékek csak explicit set esetén replikálódnak.
- A `playerEnteredScope` / `playerLeftScope` eventek használata a hivatalos doc szerint
  **rossz gyakorlat** skálázódási költség miatt (N játékos scope-jában N-szeres hívás) —
  helyette state bag change handler ajánlott.

*Forrás: `scripting-manual/networking/state-bags.md`, `scripting-reference/onesync/_index.md`*

---

## 3. Biztonsági alapok ✅ VERIFIED

### 3.1 Event-biztonság (hivatalos ajánlás)

- `AddEventHandler` = **csak azonos kontextus** (server→server, client→client), nem
  hálózati. `RegisterNetEvent` = kontextusok közötti.
- `RegisterNetEvent` **nem blokkolja** az azonos kontextusból való hívást. Ha csak
  szerverről érkező eventet akarunk elfogadni a kliensen:
  ```lua
  RegisterNetEvent('name', function(...)
      if source ~= 65535 then return end -- a szerver 65535-öt küld
  end)
  ```
- A dokumentáció explicit példát ad a "bad security" (kliens által küldött item/amount
  közvetlen elfogadása) és "good security" (szerveroldali állapot, távolság-ellenőrzés,
  egyszer-felhasználható job-state) mintákra.

### 3.2 Szerver-convarok, amelyeket a NOVA RP kötelezően használ

| Convar | Beállítás | Indok |
| --- | --- | --- |
| `sv_scriptHookAllowed` | `false` (default) | ScriptHook = azonnali sebezhetőség |
| `sv_entityLockdown` | `strict` (Enhanced-en akár `full`) | Kliens ne hozhasson létre entitást |
| `sv_pureLevel` | `2` (vagy `1`, ha grafikai mod engedett) | Módosított kliensfájlok blokkolása |
| `setr sv_stateBagStrictMode` | `true` | Kliens ne írhasson replikált state baget |
| `sv_endpointPrivacy` | `true` | Játékos-IP ne kerüljön publikus reportba |
| `sv_enableNetworkedSounds` | `false` | `NETWORK_PLAY_SOUND_EVENT` visszaélés tiltása |
| `sv_enableNetworkedPhoneExplosions` | `false` (default) | Ismert visszaélési vektor |
| `sv_enableNetworkedScriptEntityStates` | mérlegelendő (`false` a biztonságosabb) | `SCRIPT_ENTITY_STATE_CHANGE_EVENT` visszaélés |
| `sv_filterRequestControl` | policy-alapú `REQUEST_CONTROL_EVENT` szűrés | Entity-lopás elleni védelem |
| `sv_authMinTrust` / `sv_authMaxVariance` | szigorítva | Identitás-spoofing elleni védelem |
| `block_net_game_event` | tiltólistás game eventek | Ismert exploit-eventek kizárása |

Ezek pontos, indokolt értékei a `security.md`-ben és a generált `cfg/security.cfg`-ben
lesznek, konfigurációként — nem kézzel a szerveren.

### 3.3 Rate limiterek (Enhanced) ✅ VERIFIED

Token bucket, `rateLimiter_<name>_rate` és `rateLimiter_<name>_burst` convarokkal.
Alapértékek közül a számunkra fontosak: `netEvent` 50/200, `netEventFlood` 75/300,
`stateBag` 75/125, `stateBagFlood` 150/175, `netCommand` 7/14, `http_dynamic` 4/10.

**Fontos:** ez platform-szintű védelem, ami **nem helyettesíti** a saját, event-szintű
rate limitünket (a platform limiter nem tudja, hogy egy `nova:sv:bank:transfer` event
másodpercenként legfeljebb 1× jogos).

### 3.4 ACE / principal rendszer ✅ VERIFIED

A beépített Cfx jogosultsági rendszer: `add_ace`, `add_principal`, `remove_ace`,
`remove_principal`, `test_ace`. Objektum-alapú (`command.x`), principal-öröklődéssel.

**Miért nem elég nekünk:** az ACE statikus, `server.cfg`-ből vagy konzolról kezelt,
nincs benne lejáró jogosultság, audit trail, scope (frakció/job), és nem
adminpanelből menedzselhető. → Saját RBAC kell, az ACE-t **csak** a konzol- és
RCON-szintű parancsokhoz hidaljuk. Lásd `permissions.md`.

---

## 4. Üzemeltetés

### 4.1 txAdmin ✅ VERIFIED

- **Minden 2524+ FXServer buildben előre telepítve** — nem kell külön letölteni.
- Tud: recipe-alapú deploy, start/stop/restart, in-game admin menü, saját
  permission rendszer (`txData/admins.json`), action logging, brute-force védelem,
  Discord integráció (státusz-embed, whitelist parancs), monitoring (crash/hang esetén
  auto-restart, CPU/RAM, live console, thread performance chart), player manager
  (warn/ban/whitelist, saját, MySQL-független adatbázissal), ütemezett restartok,
  `server.cfg` szerkesztő és validátor.
- Alapértelmezett port: `40120` (`txAdminPort`), profilok a `txData` mappában.

**NOVA RP álláspont:** a txAdmin **kiegészítő üzemeltetői eszköz**, nem a mi
admin-rendszerünk. A játékon belüli admin-műveletek (ban, kick, item, pénz, job)
a NOVA permission- és audit-rendszerén keresztül mennek, mert csak ott van
saját audit trail, lokalizáció és feature flag. A txAdmin marad: process-felügyelet,
restart-ütemezés, live console, vészhelyzeti hozzáférés.
**Kockázat:** a txAdmin admin menüje megkerüli a mi jogosultsági rendszerünket →
a txAdmin admin-listát szigorúan minimálisan tartjuk (lásd `security.md`).

### 4.2 Monitoring-felület ✅ VERIFIED

- A szerver `/perf` végpontján **Prometheus-kompatibilis metrikák** érhetők el,
  `sv_prometheusBasicAuthUser` / `sv_prometheusBasicAuthPassword` védelemmel.
  → Ez a monitoring-stack alapja (Prometheus + Grafana), nem kell saját exporter.
- A resource-ok saját HTTP handlert regisztrálhatnak → `/health` végpont
  megvalósítható resource szinten.
- `sv_httpFileServerProxyOnly` + `sv_proxyIPRanges`: fájlkiszolgálás proxy mögé zárása.

### 4.3 Pool-méretek ✅ VERIFIED

`increase_pool_size [poolName] [increase]` — csak induláskor, szerver- és
kliensoldalon is validálva, a limitek `content.cfx.re`-ből jönnek. Néhány releváns
maximum FiveM-en: `TxdStore` +26000, `AnimStore` +20480, `Building` +20000,
`FragmentStore` +14000, `Object` +2000, `netGameEvent` +400, `StaticBounds` +5000.

**Fontos következmény:** eltérő pool-beállítású szerverek között a kliensnek újra kell
indulnia. Tehát a pool-konfigurációt **korán rögzíteni kell**, és dev/staging/prod
között azonosnak érdemes lennie, különben a tesztelők folyamatosan újraindítják a játékot.

### 4.4 Csatlakozási folyamat (deferrals) ✅ VERIFIED

A `playerConnecting` event `deferrals` objektuma: `defer()`, `update(msg)`,
`presentCard(card, cb)` (Adaptive Card!), `done(failureReason?)`, `handover(data)`.
Szabály: `defer()` után **legalább egy tick** kell `update`/`done` előtt.

Ez adja a NOVA RP onboarding-jának technikai alapját: whitelist-ellenőrzés, ban-check,
verzió-ellenőrzés, **és akár a nyelvválasztó is megjelenhet Adaptive Card-ként a
csatlakozás közben** (a `presentCard` callback visszaadja a kitöltött adatokat).

---

## 5. Amit NEM sikerült ellenőrizni

| Kérdés | Állapot | Teendő |
| --- | --- | --- |
| Element Club tier → slot limit pontos leképezés | 🟡 COMMUNITY | Ellenőrzés a portal.cfx.re/subscriptions oldalon vásárlás előtt |
| Valós CCU-adatok konkrét nagy szervereken | 🔴 UNVERIFIED | Csak saját mérés számít — lásd `scale-analysis.md` |
| Enhanced ökoszisztéma-lefedettség (mely third-party resource-ok működnek) | 🔴 UNVERIFIED | Phase 2 spike: Enhanced tesztszerver a kiválasztott függőségekkel |
| FXServer belső szálmodell pontos részletei (mi fut a fő szálon) | 🔴 UNVERIFIED | Nincs hivatalos dokumentáció; méréssel közelítjük (`/perf`, profiler) |
| Kereskedelmi "fake player" load-test eszközök megbízhatósága és ToS-megfelelése | 🟡 COMMUNITY | Nem építünk rájuk; saját mérési tervet használunk |

---

## 6. Fő tanulságok az architektúrára

1. **A kliens sosem authority** — ezt a platform maga is így modellezi
   (entity lockdown, state bag strict mode, player culling).
2. **Minden player-iteráció szerveroldali** (player culling miatt) → nincs
   "kliensen összeszedem a közeli játékosokat és elküldöm" minta.
3. **A state bag lapos kulcsokat kíván**, és a scope-eventek drágák → az állapot-
   szinkronizációt előre meg kell tervezni, nem menet közben.
4. **Az artifact-frissítés kötelező üzemeltetési ciklus** (3 hónap után lekerülünk a
   listáról) → verziókövetés, tesztelt frissítési folyamat, rollback terv kell.
5. **A Legacy/Enhanced döntés minden más döntést befolyásol** (voice, escrow, rate
   limiter, lockdown mód) → ez az első jóváhagyandó ADR.
6. **A platform ad rate limitert, pure mode-ot, entity lockdownt** — de az
   üzleti logika (pénz, item, jogosultság) védelme kizárólag a mi felelősségünk.

---

## Források

Elsődleges (hivatalos, közvetlenül olvasott forrásfájlok a `citizenfx/fivem-docs` repo
`87d92b2` commitjából):

- `content/docs/scripting-reference/onesync/_index.md`
- `content/docs/server-manual/server-commands.md`
- `content/docs/server-manual/setting-up-a-server.md`, `setting-up-a-server-vanilla.md`
- `content/docs/server-manual/end-of-support-end-of-life.md`, `frameworks.md`
- `content/docs/developers/legacy-vs-enhanced.md`, `server-security.md`, `script-runtimes.md`
- `content/docs/scripting-reference/resource-manifest/_index.md`
- `content/docs/scripting-manual/networking/state-bags.md`, `runtimes/javascript.md`, `voice/_index.md`
- `content/docs/scripting-reference/events/list/playerConnecting.md`
- `content/docs/resources/txAdmin/_index.md`, `permissions.md`

Online (nyilvános dokumentáció-tükrök és közösségi források, másodlagos):

- [OneSync — Cfx Documentation](https://docs.fivem.net/docs/scripting-reference/onesync/)
- [Server commands — Cfx Documentation](https://docs.fivem.net/docs/server-manual/server-commands/)
- [Cfx Portal — subscriptions](https://portal.cfx.re/subscriptions)
