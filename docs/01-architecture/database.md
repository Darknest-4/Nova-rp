# Database Plan — `nova_db`

> Cél: normalizált, indexelt, migrált, tranzakcióbiztos adatréteg, amely 1000+ egyidejű
> játékos írási terhelését úgy viseli, hogy közben **nem lassítja a szerver tickjét**.

---

## 1. Motor és verzió

| Döntés | Érték | Indok |
| --- | --- | --- |
| Motor | **MariaDB 11.4 LTS** (MySQL 8.4 LTS kompatibilis) | Az `oxmysql` a `node-mysql2`-re épül → MySQL protokoll. LTS = hosszú támogatási ablak. |
| Storage engine | **InnoDB** | Tranzakció, sorszintű zárolás, idegen kulcsok |
| Karakterkészlet | `utf8mb4` / `utf8mb4_unicode_ci` | Magyar ékezetek, emoji (telefon, chat) helyesen |
| Időzóna | **UTC tárolás**, megjelenítés lokálisan | Nyári időszámítás nem okozhat adathibát |
| Hozzáférés | `oxmysql` fölé húzott saját `nova_db` réteg | Cserélhetőség, metrika, cache, batch |

**Miért nem PostgreSQL:** technikailag jobb választás lenne több szempontból, de a
FiveM-ökoszisztéma teljes egészében MySQL/MariaDB-re épül (`oxmysql`, minden third-party
resource). Egy PostgreSQL-réteg saját driver megírását és minden későbbi integráció
elvesztését jelentené. **Ez tudatos kompromisszum**, nem véletlen.

---

## 2. Tervezési elvek

1. **Normalizált alapséma**, denormalizáció csak mért indok alapján, dokumentálva.
2. **Minden tábla InnoDB, minden kapcsolat idegen kulccsal**, explicit `ON DELETE`
   viselkedéssel — árva rekord ne keletkezhessen.
3. **Nincs `SELECT *`** gameplay-útvonalon; csak a szükséges oszlopok.
4. **Nincs string-összefűzött SQL.** Kizárólag prepared statement / paraméterezett query.
5. **Minden lekérdezés indexelt** — a CI-ban `EXPLAIN`-ellenőrzés a kritikus query-kre.
6. **Pénz- és item-műveletek mindig tranzakcióban**, sorszintű zárolással.
7. **Shard-tudatos séma:** a világhoz kötött állapot `world_id`-vel, a karakter- és
   gazdasági adat világfüggetlen (lásd `scale-analysis.md` 3.).
8. **Soft delete** ott, ahol az adat vitatható lehet (karakter, jármű, ingatlan),
   `deleted_at` mezővel — a visszaállíthatóság admin-eszköz.

---

## 3. Sématerv (magrészek)

> Ez tervezet, nem végleges DDL. A végleges migrációk a Phase 4-ben készülnek,
> modulonként. A gameplay-táblák (inventory, vehicles, housing…) a saját fázisukban.

```sql
-- ─── Fiók (a játékos, mint ember) ────────────────────────────────────────────
CREATE TABLE accounts (
    id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    license        VARCHAR(64)  NOT NULL UNIQUE,      -- elsődleges Cfx azonosító
    locale         VARCHAR(16)  NOT NULL DEFAULT 'hu',-- STABIL NYELVKÓD, nem 'magyar'
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at   TIMESTAMP    NULL,
    playtime_sec   BIGINT UNSIGNED NOT NULL DEFAULT 0,
    is_banned      TINYINT(1)   NOT NULL DEFAULT 0,
    KEY idx_last_seen (last_seen_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Több azonosító egy fiókhoz (steam, discord, xbl, ip-történet)
CREATE TABLE account_identifiers (
    account_id     BIGINT UNSIGNED NOT NULL,
    kind           VARCHAR(24)  NOT NULL,             -- 'steam' | 'discord' | 'fivem' | 'ip'
    value          VARCHAR(128) NOT NULL,
    first_seen_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (kind, value),
    KEY idx_account (account_id),
    CONSTRAINT fk_ident_account FOREIGN KEY (account_id)
        REFERENCES accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─── Karakter ────────────────────────────────────────────────────────────────
CREATE TABLE characters (
    id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    account_id     BIGINT UNSIGNED NOT NULL,
    slot           TINYINT UNSIGNED NOT NULL,         -- 1..N
    first_name     VARCHAR(32)  NOT NULL,
    last_name      VARCHAR(32)  NOT NULL,
    date_of_birth  DATE         NOT NULL,
    gender         VARCHAR(16)  NOT NULL,
    world_id       SMALLINT UNSIGNED NOT NULL DEFAULT 1,   -- shard-tudatosság
    position       JSON         NULL,                 -- {x,y,z,heading}
    metadata       JSON         NOT NULL,             -- health, armor, hunger, thirst, stress…
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_played_at TIMESTAMP    NULL,
    deleted_at     TIMESTAMP    NULL,
    UNIQUE KEY uq_account_slot (account_id, slot),
    KEY idx_account_active (account_id, deleted_at),
    KEY idx_name (last_name, first_name),
    CONSTRAINT fk_char_account FOREIGN KEY (account_id)
        REFERENCES accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB;
```

**Miért JSON a `metadata`:** a státusz-mezők (éhség, szomjúság, stressz, buffok) gyakran
bővülnek, és mindig együtt olvassuk/írjuk őket. Külön oszlopként minden új státusz
migrációt igényelne. **Amit viszont soha nem teszünk JSON-be:** amire keresni, szűrni,
összegezni vagy idegen kulccsal hivatkozni kell (pénz, item, tulajdon) — az mindig
saját tábla és saját oszlop.

```sql
-- ─── Pénz (számlánként külön sor, nem JSON!) ─────────────────────────────────
CREATE TABLE character_accounts (
    character_id   BIGINT UNSIGNED NOT NULL,
    account_type   VARCHAR(24)  NOT NULL,             -- 'cash' | 'bank' | 'black'
    balance        BIGINT       NOT NULL DEFAULT 0,   -- egész, legkisebb egységben
    updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (character_id, account_type),
    CONSTRAINT fk_money_char FOREIGN KEY (character_id)
        REFERENCES characters(id) ON DELETE CASCADE,
    CONSTRAINT ck_balance_nonneg CHECK (balance >= 0)
) ENGINE=InnoDB;

-- Minden pénzmozgás könyvelve — ez a duplikációs exploitok felderítésének alapja
CREATE TABLE money_transactions (
    id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    character_id   BIGINT UNSIGNED NOT NULL,
    account_type   VARCHAR(24)  NOT NULL,
    amount         BIGINT       NOT NULL,             -- előjeles
    balance_after  BIGINT       NOT NULL,
    reason_key     VARCHAR(64)  NOT NULL,             -- LOKALIZÁLHATÓ KULCS
    reason_params  JSON         NULL,
    counterparty   BIGINT UNSIGNED NULL,
    idempotency_key CHAR(26)    NULL,                 -- dupla végrehajtás ellen
    resource       VARCHAR(64)  NOT NULL,
    created_at     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    UNIQUE KEY uq_idem (idempotency_key),
    KEY idx_char_time (character_id, created_at),
    KEY idx_time (created_at)
) ENGINE=InnoDB;
```

**Fontos:** a pénz **egész szám**, a legkisebb pénzegységben. Lebegőpontos pénzkezelés
kerekítési hibából fakadó exploitot okoz — ezt a `security.md` is tiltja.

**A `reason_key` lokalizálható kulcs**, nem magyar szöveg: így a tranzakciós előzmény
minden játékosnak a saját nyelvén jelenik meg, és a fordítás javítható visszamenőleg.

```sql
-- ─── Naplózás és audit ───────────────────────────────────────────────────────
CREATE TABLE audit_log (
    id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ts             TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    actor_type     VARCHAR(16)  NOT NULL,
    actor_id       VARCHAR(64)  NULL,
    target_type    VARCHAR(16)  NULL,
    target_id      VARCHAR(64)  NULL,
    action         VARCHAR(64)  NOT NULL,
    old_value      JSON         NULL,
    new_value      JSON         NULL,
    reason         VARCHAR(255) NULL,
    resource       VARCHAR(64)  NOT NULL,
    result         VARCHAR(16)  NOT NULL,
    request_id     CHAR(26)     NULL,
    is_sensitive   TINYINT(1)   NOT NULL DEFAULT 0,
    KEY idx_actor (actor_type, actor_id, ts),
    KEY idx_target (target_type, target_id, ts),
    KEY idx_action_time (action, ts)
) ENGINE=InnoDB;

-- Futásidejű konfiguráció-felülírás (adminpanel)
CREATE TABLE config_overrides (
    config_key     VARCHAR(128) PRIMARY KEY,
    value          JSON         NOT NULL,
    updated_by     VARCHAR(64)  NULL,
    updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Migrációs állapot
CREATE TABLE schema_migrations (
    version        VARCHAR(32)  PRIMARY KEY,          -- '0007'
    name           VARCHAR(128) NOT NULL,
    checksum       CHAR(64)     NOT NULL,             -- SHA-256: utólagos módosítás kiszűrése
    applied_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    execution_ms   INT UNSIGNED NOT NULL
) ENGINE=InnoDB;
```

A permission-táblák a [permissions.md](permissions.md) 4. pontjában.

---

## 4. Migrációk

```bash
npm run db:migrate            # up: minden nem alkalmazott migráció
npm run db:migrate:status     # mi van alkalmazva, mi hiányzik
npm run db:migrate:down       # 1 lépés vissza (csak dev!)
npm run db:migrate:verify     # checksum-ellenőrzés: módosítottak-e alkalmazott migrációt
npm run db:migrate:dry        # SQL kiírása futtatás nélkül
```

Szabályok:

- Sorszámozott, **sosem módosított** fájlok: `0007_add_vehicle_liens.sql`.
  Ha egy alkalmazott migráció checksumja megváltozik, a `verify` **hibát dob** — ez
  fogja meg azt a klasszikus esetet, amikor valaki „gyorsan javít" egy már kiment SQL-t.
- Minden migráció párban: `up` és `down` szekció (a `down` lehet explicit
  `-- IRREVERSIBLE: <indok>`).
- **Production-ben `down` nem fut automatikusan.** A rollback ott: visszaállítás
  backupból + előre írt fix-migráció.
- Destruktív művelet (oszlop/tábla törlés) külön migrációban, legalább egy release
  késleltetéssel az azt feleslegessé tévő kód után (expand/contract minta).
- A `nova_db` **indulásnál ellenőrzi** az állapotot:
  production-ben nem alkalmazott migráció = **indulás megtagadva** (fél-migrált séma
  adatvesztést okozhat); development-ben figyelmeztetés.

---

## 5. Írási stratégia — write-behind

Ez a legfontosabb skálázási döntés az adatrétegben.

```
Gameplay művelet
   ↓
Memória-állapot módosul (azonnal, a játékos ezt látja)
   ↓
Dirty-jelölés  →  nova_scheduler batch flush (5–30 mp, prioritásfüggő)
   ↓
Egy tranzakció, több sor  →  MariaDB
```

| Adattípus | Stratégia | Indok |
| --- | --- | --- |
| Pozíció, státusz (éhség, stressz) | write-behind, 30 mp | Elvesztése ~jelentéktelen |
| Inventory | write-behind, 5 mp + **azonnali** kritikus műveletnél (trade, bolt) | Item-vesztés súlyos |
| **Pénz** | **azonnali, tranzakcióban** | Soha nem veszhet el, és nem duplikálódhat |
| Tulajdon (jármű, ingatlan) | azonnali | Ritka és értékes |
| Jogosultság | azonnali + cache-invalidáció | Biztonsági hatás |
| Audit log | azonnali (batch insert 1 mp-en belül) | Bizonyíték-érték |
| Statisztika, playtime | write-behind, 60 mp | Tömeges, alacsony érték |

**Kötelező flush-pontok:** játékos kilépés (`playerDropped`), szerver leállás
(`onResourceStop` + graceful shutdown), karakterváltás, admin művelet, restart-figyelmeztetés.

**Crash-kockázat:** a write-behind ablakon belüli összeomlás esetén a nem-kritikus
adat elveszhet (max. az ablak hossza). Ez tudatosan vállalt kompromisszum; a pénz és a
tulajdon soha nem esik ebbe a kategóriába.

---

## 6. Tranzakciók és versenyhelyzetek

```lua
-- Pénzátutalás mintája
Nova.Db.Transaction(function(tx)
    -- determinisztikus zárolási sorrend (kisebb id előbb) → nincs deadlock
    local a, b = math.min(fromId, toId), math.max(fromId, toId)
    local rows = tx:query('SELECT character_id, balance FROM character_accounts ' ..
                          'WHERE character_id IN (?, ?) AND account_type = ? FOR UPDATE',
                          { a, b, 'bank' })
    -- fedezet-ellenőrzés a ZÁROLT sorokon, nem a cache-ből
    …
    tx:execute('UPDATE character_accounts SET balance = balance - ? WHERE …')
    tx:execute('UPDATE character_accounts SET balance = balance + ? WHERE …')
    tx:execute('INSERT INTO money_transactions …')   -- könyvelés ugyanabban a tranzakcióban
end, { idempotencyKey = key })
```

Védelmi elemek:

| Kockázat | Védelem |
| --- | --- |
| Duplikáció (dupla event) | `idempotency_key` UNIQUE — a második beszúrás elbukik, a művelet no-op |
| Race (egyszerre két átutalás) | `SELECT … FOR UPDATE` sorszintű zárolás |
| Deadlock | Determinisztikus zárolási sorrend + automatikus retry (max. 3, exponenciális backoff) |
| Negatív egyenleg | `CHECK (balance >= 0)` + alkalmazásszintű ellenőrzés |
| Félbemaradt művelet | Tranzakció: minden vagy semmi |
| Lassú query blokkolja a tickt | Timeout (`Config.Database.QueryTimeoutMs`), aszinkron végrehajtás |

---

## 7. Kapcsolatkezelés és metrikák

```lua
Config.Database = {
    ConnectionLimit  = 20,      -- mérés alapján hangolandó
    QueryTimeoutMs   = 5000,
    SlowQueryMs      = 100,     -- efölött WARN + query-terv naplózása
    Charset          = 'utf8mb4',
    Timezone         = 'Z',
}
```

A `nova_db` minden query-ről mér: időtartam, sorok száma, hívó resource, hívási hely.
Ebből származik: p50/p95/p99 latency, lassú query top-lista, resource-onkénti DB-terhelés
— mindez a Grafana dashboardon és a `/nova health` kimenetében.

**Lassú query kezelése:** a `SlowQueryMs` fölötti query naplózásra kerül `EXPLAIN`
tervvel együtt (development-ben), és a `docs/reports/` alá kerülő heti riportban
összesítve — így az index-hiányok nem rejtve maradnak, hanem listát képeznek.

---

## 8. Backup és visszaállítás

| Elem | Módszer | Gyakoriság | Megőrzés |
| --- | --- | --- | --- |
| Teljes DB dump | `mariabackup` (vagy `mysqldump --single-transaction`) | naponta | 30 nap |
| Binlog (PITR) | binlog archiválás | folyamatos | 7 nap |
| Teljes, offsite | titkosított másolat külső tárolóra | naponta | 90 nap |
| `txData` (txAdmin) | fájl-archívum | naponta | 30 nap |
| Szerver konfiguráció | git (titkok nélkül!) | commitonként | örökre |
| Locale fájlok | git | commitonként | örökre |

**A visszaállítás negyedévente kötelezően tesztelendő** — külön környezetben,
mért RTO-val. A backup, amit soha nem állítottak vissza, nem backup, hanem remény.

Célértékek (javaslat, jóváhagyandó):

| Mutató | Cél |
| --- | --- |
| **RPO** (max. adatvesztés) | ≤ 5 perc (binlog PITR-rel) |
| **RTO** (visszaállási idő) | ≤ 60 perc |

Részletes eljárás: `BACKUP.md` és `DEPLOYMENT.md` (Phase 2-től).

---

## 9. Adatvédelem

- IP-cím, Discord ID, licenc-azonosító: **személyes adat.** Csak
  `nova.admin.logs.view_sensitive` joggal olvasható, és a logban maszkolva jelenik meg.
- Törlési kérelem: `accounts` anonimizálása (azonosítók törlése, karakternevek
  álnevesítése), a gazdasági könyvelés megőrzésével — ez utóbbi a csalásfelderítés
  miatt legitim érdek. Az eljárást a `SECURITY.md` rögzíti.
- Megőrzési idők konfigurálhatók (`Config.Logging.*.RetentionDays`), és van rájuk
  automatikus takarító job.
- A backupok titkosítva tárolandók (a bennük lévő személyes adat miatt).

---

## 10. Amit szándékosan nem csinálunk

| Nem csináljuk | Miért |
| --- | --- |
| ORM a gameplay-útvonalon | Kiszámíthatatlan query-k, rejtett N+1, mérhetetlen teljesítmény |
| Minden állapot JSON-ben egy `players` sorban | Nem indexelhető, nem kereshető, race-veszélyes, nem skálázódik |
| Lebegőpontos pénz | Kerekítési exploit |
| Kliens által küldött összegek elfogadása | Lásd `security.md` |
| `SELECT *` gameplay-ben | Felesleges hálózati és memóriaköltség, törékeny séma-kötés |
| DB a game serverrel egy gépen (production) | A DB CPU-lökései rontják a szerver tickjét |
