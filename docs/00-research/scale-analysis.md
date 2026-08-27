# Scale Analysis — 2000+ slot / 1000+ CCU

> Ez a dokumentum a projekt egyik legfontosabb, és egyben legkellemetlenebb kérdésére
> válaszol: **elérhető-e a kitűzött 2000 slot / 1000 egyidejű játékos a jelenlegi
> FiveM technológiával, és ha igen, milyen áron.**
>
> A projekt szabálya, hogy nem hamisítjuk a képességeket. Ezért itt szétválasztjuk azt,
> ami **bizonyított**, azt, ami **valószínű**, és azt, amit **csak méréssel** lehet
> eldönteni.

---

## 1. Rövid válasz

| Kérdés | Válasz |
| --- | --- |
| Támogat-e a platform 2048 slotot? | ✅ Igen. `sv_maxClients` 1–2048, OneSync Infinity default. |
| Van-e 1000+ CCU-t kiszolgáló FiveM szerver? | ✅ Igen — a hivatalos dokumentáció is ezt írja. |
| Elér-e **egy teljes RP-featureset** 1000 CCU-t **egy** FXServer-példányon? | ⚠️ **Ez nem platformkérdés, hanem a mi kódunk kérdése.** Erre ma senki nem tud őszinte igent mondani mérés nélkül — beleértve minket is. |
| Van-e hivatalos horizontális skálázás (sharding) FXServerhez? | ❌ **Nincs.** Egy világ = egy FXServer példány. |

**Ezért a NOVA RP hivatalos célja a következő formában lesz kimondva:**

> "A NOVA RP architektúrája 2048 slotra van tervezve. A ténylegesen támogatott
> egyidejű játékosszámot mért adat alapján, fokozatosan emeljük, és minden emelést
> load-test riport támaszt alá (CCU, CPU, RAM, network, DB latency, resource time,
> error rate, tick performance)."

Amíg nincs mérés, a marketinganyagban sem szerepelhet konkrét CCU-szám.

---

## 2. Miért nem triviális a 1000 CCU

### 2.1 A platform-oldali korlátok (VERIFIED)

| Korlát | Érték | Következmény |
| --- | --- | --- |
| Object ID-k | 65535 (Infinity) | Minden hálózati entitás (ped, jármű, objektum, pickup) ezt a készletet fogyasztja. 1000 játékos = 1000 player ped + járművek + világ-objektumok + NPC-k. **Az entitás-költségvetés valós, szűkös erőforrás.** |
| Culling radius | 424 unit, hardcoded | Városközpontban (Legion Square) sok játékos van egymás scope-jában → a sync-költség nem lineáris a CCU-val, hanem a **lokális sűrűséggel** skálázódik. |
| Player culling | van | Minden globális player-lista művelet szerveroldali → a szerver CPU-ját terheli. |
| Sync tick rate | `sv_syncTickRate` 1–120, default 60 (Enhanced) | Magasabb = kisebb latency, **nagyobb CPU**. |
| Pool-limitek | pl. `Object` +2000, `netGameEvent` +400 | Kliensoldali korlátok, amelyek nagy tömegnél elérhetők. |

### 2.2 Az igazi szűk keresztmetszet: a resource-ok szerveroldali ideje

Az FXServer script-környezetében **minden resource szerveroldali tickje ugyanabban a
sorrendben, ugyanazon a végrehajtási folyamon fut**. Ha 60 resource fejenként 1 ms-ot
használ tickenként, az 60 ms — miközben 60 Hz-nél a teljes keret 16,6 ms.

Ez a gyakorlatban azt jelenti:

- **Minden `while true do Wait(0) end` loop tiltott.** Nem stílus kérdése.
- Minden per-player periodikus feladat (éhség/szomjúság, pozíció-mentés, régió-check)
  **batch-elve és időben szétterítve** futhat csak (lásd 4.2).
- Egy lassú SQL-hívás a szerver-loopban 1000 játékost akaszt meg.
- **A "sok kicsi resource" nem ingyen van** — resource-onként van fix event- és
  scheduler-költség. A NOVA RP ezért kevés, jól strukturált resource-ot használ,
  nem 200 apró scriptet.

🟡 **Bizonyossági szint:** a "single-thread bound" megfogalmazás közösségi konszenzus és
a megfigyelt viselkedés; a Cfx nem publikál részletes szálmodell-dokumentációt.
Az architektúránk **úgy tervez, mintha egyetlen végrehajtási folyam lenne** — ez a
konzervatív, biztonságos feltételezés. Ha a mérés kedvezőbb, abból nem lesz baj.

### 2.3 Adatbázis-oldal

1000 játékos × (pozíció + status + inventory + pénz) mentés percenként = nagyságrendileg
több ezer írás percenként, ha naivan csináljuk. Ez nem sok egy MariaDB-nek **önmagában**,
de az FXServer-oldali aszinkron hívások száma és a connection pool telítettsége igen.

Ezért az adatréteg elve: **write-behind cache + batch flush**, nem "minden változás
azonnal INSERT/UPDATE". Részletek: [database.md](../01-architecture/database.md).

---

## 3. Architektúra-opciók a nagy CCU-ra

### Opció A — Egy FXServer példány, agresszív optimalizáció

```
            ┌──────────────────────────┐
Játékosok ─►│  FXServer (1 példány)    │──► MariaDB
            │  OneSync Infinity        │──► Redis (cache/pubsub, opcionális)
            │  NOVA resource-ok        │
            └──────────────────────────┘
```

- **Előny:** egy világ, egy gazdaság, egyszerű mentális modell, nincs cross-instance sync.
- **Hátrány:** minden skálázás vertikális (magas órajelű CPU), és van egy plafon,
  amit nem mi határozunk meg.
- **Realitás:** ez az egyetlen mód arra, hogy **egy** összefüggő RP-világ legyen.

### Opció B — Több FXServer példány, közös adatbázis ("shard"-ok)

```
Játékosok ─►│ FXServer #1 (Los Santos)  │─┐
Játékosok ─►│ FXServer #2 (Los Santos)  │─┼─► MariaDB (közös) + Redis (pub/sub)
Játékosok ─►│ FXServer #3 (Blaine Co.)  │─┘
```

- **Előny:** a CPU-korlát megkerülhető, CCU szinte tetszőlegesen skálázható.
- **Hátrány (súlyos):** a világ **nem** szinkron. A #1-en álló jármű nem látszik a #2-n.
  Két shardon lévő játékos nem tud egymással interakcióba lépni (csak "out-of-world"
  csatornákon: telefon, banki átutalás, Discord).
- **Ami átvihető shardok között:** karakter, pénz, inventory, tulajdon, jogosultság,
  chat/telefon, piac — mert ezek adatbázis-szintűek, nem világ-szintűek.
- **Ami nem:** minden, ami fizikai jelenlét (járműkövetés, rendőri üldözés, RP-jelenet).

### Opció C — Hibrid: fő világ + instance-ok routing bucketekkel

- Egy fő FXServer, benne routing bucketekkel elkülönített tartalom
  (karakterválasztó, tutorial, minigame/heist instance, staff-terület).
- **Ez nem csökkenti érdemben a CPU-terhelést** (ugyanaz a process), de csökkenti
  a lokális entitás-sűrűséget és a sync-költséget, és javítja a játékélményt.
- A hivatalos dokumentáció szerint routing bucket **nem interiorokra való**.

### Ajánlás

> **Opció A + C most, Opció B mint dokumentált, előkészített kiút.**

Konkrétan:

1. Egy világ (Opció A), routing bucketekkel a nem-világ tartalomra (Opció C).
2. **Az adatréteget az első naptól úgy tervezzük, hogy shard-tudatos legyen**
   (`world_id` / `shard_id` oszlop ott, ahol a világhoz kötött állapotot tárolunk;
   a karakter- és gazdasági adat világfüggetlen). Ez később ~0 refaktorral engedi az
   Opció B-t, ha a mérés azt mutatja, hogy egy példány kevés.
3. A "2000 slot" mint **platformkapacitás** marad a célban; a támogatott CCU mért érték.

Ez a döntés az [ADR-0004](../decisions/ADR-0004-scale-strategy.md)-ben van rögzítve.

---

## 4. Tervezési szabályok, amelyek a skálázást szolgálják

Ezek nem "ajánlások", hanem a code review kötelező ellenőrzőpontjai.

### 4.1 Tiltott minták

| Tiltott | Helyette |
| --- | --- |
| `while true do Wait(0) end` szerveroldalon | event-vezérelt logika vagy ütemezett job |
| `GetPlayers()` végigiterálása tickenként | indexelt, karbantartott player-regiszter |
| Per-player timer resource-onként | **egy** központi scheduler, batch-ekkel |
| `playerEnteredScope` / `playerLeftScope` gameplay-logikára | state bag change handler |
| Szinkron/blokkoló DB-hívás gameplay-útvonalon | async query + cache |
| Minden változás azonnali DB-írása | write-behind, batch flush |
| Nagy tábla (JSON) state bagbe írása | lapos kulcs, minimális payload |
| Globális broadcast (`TriggerClientEvent(-1, ...)`) gyakori adatra | scope-alapú vagy state bag |

### 4.2 Tick-költségvetés (kezdeti célérték)

| Kategória | Célérték (szerver, tick) |
| --- | --- |
| `nova_core` összes modul együtt | < 1,0 ms |
| Bármely egyedi gameplay-resource | < 0,5 ms átlag, < 2,0 ms csúcs |
| Teljes szerveroldali resource-idő | **< 8 ms** 60 Hz mellett (50% headroom) |

A CI-ban és a staging-en a `/perf` metrikák és a beépített profiler alapján ezt
**mérjük**, és a küszöb túllépése hibának minősül, nem "majd optimalizáljuk"-nak.

### 4.3 Entitás-költségvetés

65535 object ID mellett tervezett bontás (kezdeti, felülvizsgálandó):

| Kategória | Keret |
| --- | --- |
| Player pedek | max. `sv_maxClients` |
| Játékos-járművek | ~1,5 × CCU |
| Perzisztens világ-objektumok (props, MLO-kiegészítők) | 8 000 |
| NPC / job pedek | 3 000 |
| Ideiglenes (dobott item, effekt) | 2 000 + auto-cleanup |
| Tartalék | ≥ 30% |

Az entitás-létrehozás **kizárólag központi API-n keresztül** történhet
(`nova_world` modul), ami számol, naplóz, limitet érvényesít és takarít.
Ez az egyetlen mód, hogy a költségvetés ne csak papíron létezzen.

---

## 5. Mérési terv (Phase 26 előkészítése)

### 5.1 Mit mérünk

| Metrika | Forrás | Küszöb (kezdeti) |
| --- | --- | --- |
| CCU | szerver | — |
| Szerver tick / frame time | `/perf` Prometheus, profiler | < 16,6 ms (60 Hz) |
| Resource-onkénti CPU idő | profiler, `resmon` | lásd 4.2 |
| RAM (FXServer process) | node_exporter | < 70% |
| Hálózat ki/be | node_exporter | sávszélesség-terv szerint |
| DB query latency (p50/p95/p99) | `nova_db` metrika + mysqld_exporter | p95 < 25 ms |
| DB connection pool telítettség | oxmysql/mysqld_exporter | < 70% |
| Error rate (script error / perc) | `nova_logging` | ~0 |
| Kliens FPS (mintavétel) | önkéntes tesztelők | > 45 |
| Hitch warningok | szerverlog | 0 |

### 5.2 Hogyan mérünk — és miért nem elég a "bot"

**Probléma:** valódi FiveM klienst nagy számban futtatni drága és jogilag kényes.
Léteznek kereskedelmi "fake player" szolgáltatások (🟡 COMMUNITY), de:

- nem ellenőrizhető, hogy a szimulált egység a valós kliens sync-terhelését adja-e,
- ToS-kockázat, amit előzetesen tisztázni kellene,
- külső szolgáltatásnak adnánk szerver-hozzáférést.

**Ezért három rétegű mérési stratégia:**

1. **Szintetikus szerver-oldali terhelés (CI-ban is futtatható).**
   A `nova_loadtest` resource szerveroldalon N szimulált *játékos-állapotot* hoz létre
   (DB-írás, inventory-művelet, permission-lekérdezés, locale-render, event-forgalom),
   valódi kliens nélkül. Ez a **mi kódunk** költségét méri, ami a fő ismeretlen.
   → Ez ad választ arra, hogy a NOVA logika elbírja-e a 1000 játékost.
2. **Entitás- és sync-terhelés szerveroldali entitásokkal.**
   Szerveroldalon létrehozott pedek/járművek adott sűrűséggel, `sync_start_recording`
   (Enhanced) vagy mért `/perf` értékek mellett.
3. **Valódi játékos-hullámok (staged playtest).**
   50 → 100 → 250 → 500 → 750 → 1000 → 1500 → 2000. Minden lépcső előtt kötelező a
   riport az előzőről; **lépcső átugrása tilos**. Mindegyik lépcső után döntés:
   engedélyezzük-e a következőt.

### 5.3 A riport kötelező tartalma

Minden load teszt kimenete egy `docs/reports/loadtest-<dátum>-<CCU>.md`, amely
tartalmazza: a build/artifact verziót, a resource-listát és verziókat, a hardvert,
a mérési módszert, az összes 5.1-es metrikát idősorral, a talált szűk keresztmetszeteket,
és egy explicit "mit szabad ebből állítani" szakaszt.

---

## 6. Hardver-irányelvek (kiinduló feltételezés, mérés írja felül)

| Komponens | Kiinduló ajánlás | Indok |
| --- | --- | --- |
| CPU (game server) | **dedikált fizikai magok, lehető legmagasabb egyszálas teljesítmény** | A sync és a script-végrehajtás egyszálas teljesítményre érzékeny; osztott vCPU-n a scheduler-váltás mikro-akadásokat okoz |
| RAM (game server) | 32–64 GB | Entitás-állapot, script-memória, headroom |
| Hálózat | 1 Gbps+, alacsony jitter, DDoS-védelem | 1000 kliens sync-forgalma |
| DB | külön gép/instance, NVMe, 32 GB+ RAM | Ne versenyezzen a game server CPU-jáért |
| Cache (opcionális) | Redis, külön instance | Csak ha shardolunk vagy külső panel kell |

**Fontos:** a game server és a DB **ne legyen ugyanazon a gépen** production-ben.
A DB CPU-lökései közvetlenül a szerver tick-jét rontanák.

---

## 7. Amit ebből most kimondunk

1. A platform (FXServer + OneSync Infinity) **nem akadálya** a 2048 slotnak.
2. A **saját kódunk** lesz a korlát, és ez jó hír: ez az, amit befolyásolni tudunk.
3. **Nincs hivatalos sharding** — ha egy példány kevés, a világ szétválik, és ezt
   játéktervezési szinten kell kezelni, nem technikaival.
4. Egyetlen CCU-számot sem állítunk mérés nélkül. A `README`-ben, a marketingben és
   a Discordon sem.
5. A skálázási döntéseket a mérési lépcsők után hozzuk meg, dokumentáltan.
