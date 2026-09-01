# ADR-0003: Production hosting platform — Windows vs. Linux

- **Állapot:** ✅ `Accepted` — elfogadva 2026-08-27 (a D) opció: a production platform a Phase 26 mérése után dől el)
- **Dátum:** 2026-08-27
- **Blokkoló:** nem (a fejlesztés Linuxon indulhat)

## Kontextus

A hivatalos Cfx dokumentáció a Linux FXServerről szó szerint ezt írja:

> *"the Linux version of FXServer is only provided as a courtesy port due to issues
> regarding Linux distribution compatibility and availability of diagnostic tools for
> native C++ code. If you're experiencing any issues, you're more likely to see them
> fixed if you use the Windows version."*

Ez ellenőrzött tény, nem vélemény. Ugyanakkor a Linux az automatizálás, a CI, a
konténerizálás és az üzemeltetési eszközök szempontjából egyértelműen erősebb, és
licencköltsége sincs.

Egy 1000 CCU-ra törekvő szervernél a natív crash-diagnosztika nem apróság: egy
reprodukálhatatlan összeomlás hetekre megbéníthatja a projektet.

## Vizsgált lehetőségek

### A) Minden Linuxon
- ➕ Egységes környezet dev/staging/prod között, konténerizálás, olcsó automatizálás.
- ➖ Gyengébb hivatalos támogatás; nehezebb natív crash-diagnózis.

### B) Minden Windows-on
- ➕ Legjobb hivatalos támogatás és diagnosztika.
- ➖ Gyengébb automatizálás, licencköltség, eltérő dev-környezet.

### C) Vegyes: game server Windows, minden más (DB, monitoring, CI, web) Linux
- ➕ A támogatás ott van, ahol számít (a game process), és az ops-előny is megvan.
- ➖ Két platformot kell üzemeltetni; a dev/prod különbség hibaforrás.

### D) Döntés-halasztás mérésig — **javasolt**
- Dev és staging Linuxon indul (olcsó, automatizálható).
- A Phase 26 load teszt **mindkét platformon** lefut, azonos konfigurációval.
- A production platformját a mérés és a stabilitási megfigyelés dönti el.

## Döntés (javaslat)

> **D) — dev/staging Linux; a production platform a Phase 26 mérése után dől el,
> és az eredményt ez az ADR rögzíti.**

Amit ehhez már most megteszünk, hogy a döntés valóban nyitva maradjon:

1. **Nincs platform-specifikus kód.** Nincs shell-hívás, nincs `\` útvonal,
   nincs OS-függő fájlkezelés. Minden útvonal a resource-relatív API-kon keresztül.
2. A tooling (Node CLI) **platformfüggetlen**, a CI Linuxon és Windows-on is lefut.
3. A telepítési dokumentáció **mindkét ágra** készül (a specifikáció 50. pontja
   amúgy is kéri: „A. Windows development, B. Linux development").
4. A `.env` és a konfiguráció formátuma azonos mindkét platformon.

## Következmények

- **Nehezebb lesz:** a CI-t és a dokumentációt két platformra karbantartani.
- **Könnyebb lesz:** a production platformváltás — ha kiderül, hogy szükség van rá,
  nem kell átírni a projektet.
- A load teszt riport kötelező része lesz a platform-összehasonlítás.

## Felülvizsgálat

A Phase 26 load teszt után **kötelezően** véglegesítjük. Ha a mérés nem mutat
érdemi különbséget, a Linux marad (ops-előny); ha a Windows mérhetően stabilabb
vagy jobb tickeket ad, a game process oda kerül (C opció).
