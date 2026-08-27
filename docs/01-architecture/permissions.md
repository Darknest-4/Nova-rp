# Permission Plan — `nova_permission`

> Cél: teljes értékű RBAC, ahol **egyetlen jogosultság sincs kódba égetve**, minden
> node külön kezelhető, a role-ok adatvezéreltek, és minden változás auditálva van.

---

## 1. Alapfogalmak

| Fogalom | Jelentés |
| --- | --- |
| **Node** | Egy konkrét jogosultság, pont-elválasztott: `nova.admin.player.kick` |
| **Role** | Node-ok nevesített halmaza, örökölhet más role-tól |
| **Grant** | Egy alanyhoz (játékos vagy role) rendelt engedély vagy tiltás, opcionális lejárattal és scope-pal |
| **Scope** | A jogosultság érvényességi köre: globális, frakció, job, terület |
| **Subject** | Akire a grant vonatkozik: `player:<id>` vagy `role:<name>` |

## 2. Node-ok

### 2.1 Névtér

```
nova.<domain>.<action>[.<qualifier>]
```

Példák (a specifikáció listája leképezve):

```
nova.admin.player.kick
nova.admin.player.ban
nova.admin.player.teleport
nova.admin.player.spectate
nova.admin.player.freeze
nova.admin.player.revive
nova.admin.spawn.vehicle
nova.admin.give.item
nova.admin.give.money
nova.admin.set.job
nova.admin.set.faction
nova.admin.permission.manage
nova.admin.logs.view
nova.admin.logs.view_sensitive
nova.admin.server.restart
nova.admin.config.edit
nova.admin.feature.toggle

nova.police.cuff
nova.police.evidence.view
nova.ems.revive
nova.job.mechanic.repair
nova.faction.<id>.manage_members
nova.business.<id>.withdraw
```

### 2.2 Wildcard és feloldás

Támogatott: `nova.admin.*`, `nova.admin.player.*`, `*` (mindent).

**Feloldási sorrend — a legpontosabb és a legszigorúbb nyer:**

```
1. Explicit DENY az alanyra (player)            → DENY  (mindig nyer)
2. Explicit ALLOW az alanyra (player)           → ALLOW
3. Role-októl örökölt DENY (bármelyik role)     → DENY
4. Role-októl örökölt ALLOW                     → ALLOW
5. Wildcard találat (a leghosszabb prefix nyer) → az adott effect
6. Nincs találat                                → DENY (deny-by-default)
```

Két szabály, amit sosem szegünk meg:

- **Deny-by-default:** ami nincs kifejezetten engedélyezve, az tiltott.
- **Deny wins:** azonos pontosságon a tiltás erősebb. Egy `nova.admin.*` allow nem
  írja felül a `nova.admin.player.ban` denyt.

### 2.3 Node-regisztráció

A node-okat **a modulok deklarálják**, nem egy központi lista:

```lua
-- resources/[nova-gameplay]/nova_police/permissions.lua
return {
    { node = 'nova.police.cuff',           default = 'role:police',
      description = 'permissions.police.cuff' },       -- lokalizált leírás!
    { node = 'nova.police.evidence.view',  default = 'role:police_detective',
      description = 'permissions.police.evidence_view',
      sensitive = true },
}
```

Induláskor a `nova_permission` összegyűjti az összes deklarált node-ot, és:

- ismeretlen node-ra hivatkozó grant → figyelmeztetés a bootnál (elgépelés kiszűrése),
- deklarált, de sehol nem ellenőrzött node → figyelmeztetés a CI-ban (halott jog),
- a `sensitive = true` node-ok külön audit-kategóriába kerülnek.

---

## 3. Role-ok

Alap role-ok (**csak seed adat, nem kód**):

```
owner · developer · head_admin · admin · moderator · helper · support · trial_staff
```

Ezekhez **nincs hardcode-olt jogosultság.** A seed migráció ad nekik kezdő node-készletet,
ami utána adminpanelből szabadon módosítható, és új role bármikor létrehozható.

Öröklés (DAG, körkörösség tiltva, boot-időben ellenőrizve):

```
owner
└── developer
    └── head_admin
        └── admin
            └── moderator
                └── helper
                    └── trial_staff
```

Az `owner` role speciális: **legalább egy owner mindig kell**, az utolsó owner
jogosultsága nem vehető el, és az `owner` nem törölhető. (Enélkül egy hibás
adminpanel-művelet kizárhatná a tulajdonost a saját szerveréről.)

---

## 4. Adatmodell

```sql
CREATE TABLE permission_roles (
    id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(64)  NOT NULL UNIQUE,      -- 'admin'
    label_key     VARCHAR(128) NOT NULL,             -- 'roles.admin.name'  (lokalizált!)
    parent_id     INT UNSIGNED NULL,
    priority      SMALLINT     NOT NULL DEFAULT 0,
    is_protected  TINYINT(1)   NOT NULL DEFAULT 0,   -- owner: nem törölhető
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_role_parent FOREIGN KEY (parent_id)
        REFERENCES permission_roles(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE permission_grants (
    id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    subject_type  ENUM('player','role') NOT NULL,
    subject_id    VARCHAR(64)  NOT NULL,             -- player uuid vagy role név
    node          VARCHAR(128) NOT NULL,             -- 'nova.admin.player.kick' | 'nova.admin.*'
    effect        ENUM('allow','deny') NOT NULL,
    scope_type    VARCHAR(32)  NULL,                 -- 'faction' | 'job' | NULL (globális)
    scope_id      VARCHAR(64)  NULL,
    expires_at    TIMESTAMP    NULL,                 -- temporary permission
    granted_by    VARCHAR(64)  NULL,
    reason        VARCHAR(255) NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_grant (subject_type, subject_id, node, scope_type, scope_id),
    KEY idx_subject (subject_type, subject_id),
    KEY idx_expiry  (expires_at)
) ENGINE=InnoDB;

CREATE TABLE player_roles (
    player_id     BIGINT UNSIGNED NOT NULL,
    role_id       INT UNSIGNED    NOT NULL,
    expires_at    TIMESTAMP       NULL,
    granted_by    VARCHAR(64)     NULL,
    created_at    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (player_id, role_id),
    KEY idx_expiry (expires_at)
) ENGINE=InnoDB;
```

**Temporary permission:** `expires_at` + egy percenkénti takarító job, ami a lejárt
grantokat érvényteleníti és a cache-t frissíti. A lejárat **ellenőrzéskor is** számít
(nem bízunk a takarító időzítésében).

---

## 5. Cache és teljesítmény

A jogosultság-ellenőrzés forró útvonalon van (minden admin művelet, minden védett event),
ezért:

- Játékosonként **előre kiszámított, lapos permission-halmaz** a memóriában
  (allow-set + deny-set + wildcard-szabályok), belépéskor felépítve.
- `Nova.Permission.Has()` → **O(1) hash-lookup**, nem DB-hívás, nem rekurzió.
- Invalidáció: role/grant módosításkor célzottan az érintett játékosoké, event-alapon.
- Lejárat: a cache tárolja a legközelebbi lejárati időpontot; azon a ponton újraszámol.
- Több FXServer példány esetén (Opció B) a cache-invalidáció Redis pub/sub-on megy.

Mérési célérték: 10 000 ellenőrzés < 5 ms.

---

## 6. API

```lua
-- SZERVER (ez az egyetlen authority)
Nova.Permission.Has(source, 'nova.admin.player.kick')          --> boolean
Nova.Permission.Has(source, 'nova.faction.ballas.manage', {    --> scope-os
    scope = { type = 'faction', id = 'ballas' } })
Nova.Permission.Require(source, 'nova.admin.player.ban')       --> ok, err (naplóz is)
Nova.Permission.List(source)                                    --> node-lista (UI-hoz)

-- KEZELÉS
Nova.Permission.GrantRole(playerId, 'moderator', { expiresAt = ..., by = adminId })
Nova.Permission.Grant(subject, node, 'allow'|'deny', opts)
Nova.Permission.Revoke(subject, node, opts)
Nova.Permission.CreateRole({ name = 'event_host', parent = 'helper', ... })

-- KLIENS (kizárólag UI-megjelenítéshez, SOHA nem authority)
Nova.Permission.Can('nova.admin.player.kick')   --> boolean, a szervertől kapott listából
```

### 6.1 A kliensoldali lista státusza

A kliens megkapja a **saját** node-listáját, hogy ne mutasson használhatatlan
gombokat. Ez **kizárólag UX**. A szerver minden művelet előtt újra ellenőriz.
Ha eltérés van (a kliens hívott olyat, amire nincs joga), az **biztonsági esemény**:
naplózzuk, és ismétlődés esetén a `nova_net` automatikusan korlátozza a játékost.

### 6.2 Tiltott minta

```lua
if isAdmin then ... end                          -- ❌
if player.group == 'admin' then ... end          -- ❌
if IsPlayerAceAllowed(src, 'command.kick') then  -- ❌ (kivéve konzol-parancs bridge)
```

Helyette **mindig**:

```lua
if not Nova.Permission.Has(source, 'nova.admin.player.kick') then return end
```

---

## 7. Kapcsolat a Cfx ACE rendszerrel

A Cfx beépített ACE rendszere (`add_ace`, `add_principal`, `test_ace`) statikus és
konzol-orientált; nincs benne lejárat, audit, scope és panel-kezelés.

**Ezért:**

- A **NOVA RBAC az authority** minden játékon belüli műveletre.
- Az ACE-t csak a **szerverkonzol / RCON** szintű parancsokra használjuk
  (`quit`, `restart`, `txadmin`), ahol a NOVA még nem is fut.
- Egyirányú híd: a NOVA role-ok **leképezhetők** ACE principalokra
  (`Config.Permission.AceBridge`), hogy a konzolparancsok is működjenek — de
  visszafelé nincs: egy ACE-jogosultság **nem ad** NOVA node-ot.

**txAdmin:** külön jogosultsági rendszere van (`txData/admins.json`), amit nem tudunk
és nem is akarunk átvenni. Biztonsági szabály: a txAdmin admin-listán csak a
tulajdonos és a szerver-üzemeltető szerepel, mert a txAdmin in-game menü megkerüli
a NOVA jogosultságokat. Ezt a `security.md` és a `PERMISSIONS.md` is rögzíteni fogja.

---

## 8. Audit

Minden jogosultság-változás és minden `sensitive` node használata auditba kerül:

```json
{
  "ts": "2026-08-27T14:30:12.482Z",
  "actor":   { "type": "player", "id": 42, "name": "…", "identifiers": ["license:…"] },
  "target":  { "type": "player", "id": 77 },
  "action":  "permission.role.grant",
  "old":     { "roles": ["helper"] },
  "new":     { "roles": ["helper", "moderator"], "expiresAt": "2026-09-27T00:00:00Z" },
  "reason":  "próbaidős előléptetés",
  "resource": "nova_admin",
  "result":  "success",
  "requestId": "01J…"
}
```

- Az audit log **append-only** táblában (`audit_log`), a rendes logtól elkülönítve.
- Megőrzés: `Config.Logging.Audit.RetentionDays` (default 365).
- Megjelenítés: kulcs-alapú, a néző admin nyelvén (lásd `localization.md` 2.).
- Az audit log **olvasása is** jogosultsághoz kötött: `nova.admin.logs.view` és
  érzékeny adatokhoz `nova.admin.logs.view_sensitive`.
- Az audit írása **soha nem hiúsulhat meg csendben**: ha az audit-írás nem sikerül,
  a művelet visszagörgetésre kerül (kritikus műveleteknél), vagy `FATAL` szintű log
  keletkezik.

---

## 9. Adminpanel-funkciók (Phase 21)

Panelből elvégezhető, mind auditálva, mind jogosultsághoz kötve
(`nova.admin.permission.manage`):

- role létrehozás / törlés / átnevezés / prioritás
- szülő-role beállítása (körkörösség-ellenőrzéssel)
- node hozzáadás / eltávolítás / allow / deny
- ideiglenes jogosultság lejárati idővel
- játékoshoz role rendelése, lejárattal
- scope-os grant (frakció, job)
- **"effektív jogosultságok" nézet:** egy játékosra megmutatja, mely node-ot honnan kap
  (melyik role-tól, melyik grantból) — ez a debugolás legfontosabb eszköze
- **szimuláció:** "mi történne, ha ezt a role-t megkapná" — mentés nélküli előnézet

---

## 10. Tesztterv (kivonat)

| Teszt | Mit igazol |
| --- | --- |
| deny-by-default | ismeretlen node → tiltás |
| deny wins | konkrét deny felülírja a wildcard allow-t |
| leghosszabb prefix | `nova.admin.player.*` erősebb, mint `nova.*` |
| öröklés | role-lánc mentén helyes összegzés |
| körkörös öröklés | boot-időben elutasítva, értelmes hibával |
| lejárat | lejárt grant nem érvényes, akkor sem, ha a takarító még nem futott |
| scope | frakció-scope-os jog más frakcióban nem érvényes |
| cache-invalidáció | grant módosítása után a következő ellenőrzés már az új értéket adja |
| utolsó owner | nem lehet elvenni / törölni |
| kliens-hazugság | jogosulatlan kliens-hívás elutasítva + naplózva |
| teljesítmény | 10 000 ellenőrzés < 5 ms |
