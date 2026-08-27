# ADR-0004: Skálázási stratégia

- **Állapot:** `Proposed`
- **Dátum:** 2026-08-27
- **Blokkoló:** nem, de az adatmodellt már a Phase 4-ben befolyásolja

## Kontextus

Cél: 2000+ slot, 1000+ CCU. Ellenőrzött tények
([scale-analysis.md](../00-research/scale-analysis.md)):

- `sv_maxClients` maximuma **2048**; OneSync Infinity ezt támogatja.
- A hivatalos dokumentáció szerint **léteznek 1000+ CCU-t kiszolgáló szerverek**.
- **Nincs hivatalos horizontális skálázás** (sharding) az FXServerhez: egy világ = egy példány.
- Az object ID készlet 65535; a culling radius 424 unit; minden player-iteráció szerveroldali.
- A szűk keresztmetszet nem a platform, hanem a **resource-ok szerveroldali ideje**.

## Vizsgált lehetőségek

| Opció | Leírás | Ár |
| --- | --- | --- |
| **A** | Egy példány, agresszív optimalizáció | Vertikális skálázás; van egy plafon, amit nem mi szabunk meg |
| **B** | Több példány, közös DB (shardok) | A világ szétesik: a shardok között nincs fizikai jelenlét |
| **C** | Egy példány + routing bucket instance-ok | CPU-t alig spórol, de sűrűséget és élményt javít |

## Döntés (javaslat)

> **A + C most, B előkészítve — de nem megvalósítva.**

1. **Egy világ, egy FXServer példány** (A), routing bucketekkel a nem-világ tartalomra
   (C): karakterválasztó, tutorial/onboarding, instance-olt küldetés, staff-terület.
   A hivatalos ajánlás szerint **routing bucket nem interiorokra való** — belső tereknél
   a `conceal` natívokat használjuk.
2. **Az adatmodell az első naptól shard-tudatos:** a világhoz kötött állapot kap
   `world_id` oszlopot, a karakter- és gazdasági adat világfüggetlen marad.
   Ez ma ~0 többletköltség, később viszont ez különbözteti meg a „bekapcsoljuk"
   és a „hónapokig migrálunk" forgatókönyvet.
3. **Az entitás-létrehozás központi API-n megy** (`nova_world`), költségvetéssel,
   számlálással és automatikus takarítással — a 65535-ös keret így nem elméleti szám,
   hanem érvényesített korlát.
4. **Tick-költségvetés** modulonként, CI-ban mérve
   ([testing.md](../01-architecture/testing.md) 5.).
5. **A támogatott CCU mért érték**, és lépcsőnként emeljük
   (50 → 100 → 250 → 500 → 750 → 1000 → 1500 → 2000), minden lépcsőhöz riporttal.

## Amit ez a döntés kimond

- **Nem ígérünk 1000 CCU-t.** A platform képes rá; hogy a mi szerverünk képes-e,
  azt a mérés dönti el.
- Ha a mérés azt mutatja, hogy egy példány kevés a tervezett feature-készlettel,
  **két őszinte út marad**: (a) feature-készlet szűkítése/optimalizálás, vagy
  (b) shardolás vállalt játékélmény-kompromisszummal. Egy harmadik, „majd valahogy
  megoldjuk" út nincs, és ezt előre kimondjuk.

## Következmények

- Az adatmodell egy oszloppal bővül ott, ahol világhoz kötött állapot van.
- Minden entitás-létrehozás egy API-n megy át — kényelmetlenebb, mint közvetlenül
  natívot hívni, de ez az egyetlen mód a költségvetés betartására.
- A CI-ban a teljesítmény-küszöb túllépése hibának számít.

## Felülvizsgálat

Minden load teszt lépcső után. Az 500 CCU-s mérés lesz az első valódi
információ arról, hogy a cél reális-e a tervezett feature-készlettel.
