# Architecture Decision Records (ADR)

Minden nagy, nehezen visszafordítható döntés kap egy ADR-t. Az ADR célja nem az,
hogy okosnak tűnjünk, hanem hogy **fél év múlva is tudjuk, miért így csináltuk**,
és hogy egy új fejlesztő ne kezdje elölről ugyanazt a vitát.

## Állapotok

| Állapot | Jelentés |
| --- | --- |
| `Proposed` | Megírva, jóváhagyásra vár |
| `Accepted` | Elfogadva, ez a hatályos döntés |
| `Rejected` | Elvetve (az indoklás megmarad — ez is érték) |
| `Superseded by ADR-NNNN` | Egy későbbi döntés váltotta fel |

## Lista

| # | Cím | Állapot | Blokkol? |
| --- | --- | --- | --- |
| [0001](ADR-0001-target-platform.md) | Célplatform: FiveM Legacy vs. GTAV Enhanced | `Proposed` | **Igen** |
| [0002](ADR-0002-framework-base.md) | Saját mag vs. meglévő framework (Qbox / ox_core / ESX) | `Proposed` | **Igen** |
| [0003](ADR-0003-hosting-platform.md) | Production hosting: Windows vs. Linux | `Proposed` | Nem (Phase 26-ig halasztható) |
| [0004](ADR-0004-scale-strategy.md) | Skálázási stratégia: egy világ + shard-tudatos adatmodell | `Proposed` | Nem |

A **blokkoló** ADR-ek nélkül a Phase 2 (Project Bootstrap) nem indulhat el, mert
a repository szerkezetét és a függőségeket határozzák meg.

## Sablon

```markdown
# ADR-NNNN: <cím>

- **Állapot:** Proposed
- **Dátum:** ÉÉÉÉ-HH-NN
- **Döntéshozó:** <ki hagyja jóvá>

## Kontextus
Mi a helyzet, milyen kényszerek vannak, mit tudunk (forrásokkal).

## Vizsgált lehetőségek
Opciónként: leírás, előny, hátrány, kockázat.

## Döntés
Mit választunk, és pontosan mit jelent ez a gyakorlatban.

## Indoklás
Miért ezt. Mit mérlegeltünk.

## Következmények
Mi lesz nehezebb, mi lesz könnyebb. Mit kell újratárgyalni, ha X változik.

## Felülvizsgálat
Mikor és mi alapján néznénk újra.
```
