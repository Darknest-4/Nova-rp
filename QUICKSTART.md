# QUICKSTART — NOVA RP fejlesztői környezet

> **Kinek szól:** olyan fejlesztőnek, aki még soha nem látta ezt a projektet.
> **Mire jó:** hogy 20–30 perc alatt fusson a szerver a gépeden, és tudd
> futtatni a teszteket.
>
> **Állapot: Phase 2.** A szerver elindul és lefuttat egy indulási ellenőrzést.
> Gameplay még nincs — belépni még nem tudsz értelmes játékmenetbe.
>
> A teljes, minden lépést részletező telepítési útmutató (`SETUP.md`,
> `INSTALLATION.md`) a Phase 4 végén készül el, amikor már adatbázis is van.

---

## 0. Amire szükséged lesz

| Szoftver | Verzió | Miért |
| --- | --- | --- |
| **Git** | bármi friss | forráskód |
| **Node.js** | **22 LTS** (`.nvmrc`) | fejlesztői eszközök (`nova` CLI) |
| **Lua 5.4 + luarocks + busted** | — | Lua unit tesztek (opcionális, de ajánlott) |
| **FXServer artifact** | a Cfx **recommended** build | maga a szerver |
| **Cfx licenckulcs** | ingyenes | a szerver indításához |

Windows-on a fenti parancsok PowerShellben futnak; ahol eltérés van, jelezzük.

---

## 1. Repository klónozása

```bash
git clone https://github.com/Darknest-4/Nova-rp.git
cd Nova-rp
```

---

## 2. Fejlesztői eszközök telepítése

```bash
cd tools
npm ci          # ha a package-lock.json már létezik
# vagy első alkalommal:  npm install
```

**Várt eredmény:** hibaüzenet nélkül lefut, létrejön a `tools/node_modules/`.

---

## 3. Környezet-ellenőrzés

```bash
npm run doctor
```

**Várt eredmény** (a figyelmeztetések ilyenkor még normálisak):

```
NOVA RP — környezet-ellenőrzés

✔ Node.js                v22.x.x
✔ Git                    git version 2.x.x
✔ Lua 5.4                Lua 5.4.6 ...
✔ busted                 2.3.0
▲ server.cfg             még nincs létrehozva
  cp server/server.cfg.example server/server.cfg
▲ cfg/90-local.cfg       még nincs létrehozva — licenckulcs nélkül a szerver nem indul
  cp server/cfg/90-local.cfg.example server/cfg/90-local.cfg
▲ vendor függőségek      nincsenek telepítve
  cd tools && npm run vendor:install
✔ titok-szivárgás        a titkos fájlok nincsenek verziókövetve
```

A `doctor` minden hiányzó dologhoz megmondja a **pontos parancsot**, amivel
pótolható. Ha a Lua vagy a busted hiányzik, az csak a Lua tesztekhez kell:

```bash
# Debian / Ubuntu
sudo apt-get install -y lua5.4 liblua5.4-dev luarocks
sudo luarocks --lua-version=5.4 install busted
```

---

## 4. Third-party függőségek telepítése

```bash
# a tools/ mappából
npm run vendor:install
```

Ez letölti a `vendor.json`-ban **rögzített verziójú** `ox_lib` és `oxmysql`
csomagokat, **ellenőrzi a SHA-256 összegüket**, és kicsomagolja őket a
`resources/[vendor]/` mappába.

**Várt eredmény:**

```
› ox_lib v3.39.0 (LGPL-3.0-or-later)
  checksum rendben (1df6724dfc1d2d28…)
✔ ox_lib: 174 fájl → ./resources/[vendor]/ox_lib
› oxmysql v2.14.1 (LGPL-3.0-or-later)
  checksum rendben (29fa0992174257f5…)
✔ oxmysql: 11 fájl → ./resources/[vendor]/oxmysql
```

> Ha **checksum-eltérést** jelez: NE telepítsd. Az azt jelenti, hogy a letöltött
> csomag nem az, amit a projekt rögzít. Szólj a csapatnak.

---

## 5. Szerver-konfiguráció létrehozása

```bash
# a repository gyökeréből
cp server/server.cfg.example server/server.cfg
cp server/cfg/90-local.cfg.example server/cfg/90-local.cfg
chmod 600 server/cfg/90-local.cfg          # Linux/macOS
```

Nyisd meg a `server/cfg/90-local.cfg` fájlt, és állítsd be a licenckulcsot:

```cfg
sv_licenseKey "ide_jon_a_kulcsod"
```

**Licenckulcs igénylése:** https://portal.cfx.re/ (ingyenes, Cfx-fiók kell hozzá).

> Fejlesztéshez licenckulcs nélkül is elindulhatsz: vedd ki a
> `# set sv_lan true` sor elől a `#` jelet. Ilyenkor a szerver LAN-módban fut,
> nem kerül a publikus listára, és kihagyja a licenc-ellenőrzést.
> **Éles szerveren ez soha ne legyen bekapcsolva.**

Ez a két fájl **gitignore-olt** — titok nem kerülhet a repóba.

---

## 6. FXServer artifact letöltése

A szerver binárisa nincs a repóban (nem is lehet). Töltsd le a Cfx által
**recommended**-ként jelölt buildet:

- Letöltési oldal: https://docs.fivem.net/docs/server-download/

**Linux:**

```bash
mkdir -p ~/FXServer/server && cd ~/FXServer/server
# másold ki a "recommended" build URL-jét a letöltési oldalról:
wget <recommended_build_url>
tar xf fx.tar.xz
```

**Windows:** csomagold ki a `server.7z`-t egy `C:\FXServer\server` mappába
(7-Zip vagy WinRAR).

> **Minimális build: 12739.** Indoklás: a `sv_stateBagStrictMode` convar —
> a NOVA kötelező biztonsági beállítása — ettől a verziótól létezik.
> A gyakorlatban mindig a friss recommended buildet használd: a 3 hónapnál
> régebbi artifacttal futó szerver eltűnik a szerverlistáról.

---

## 7. A szerver indítása

A szervert a **repository `server/` mappájából** kell indítani, mert a
`server.cfg` innen hivatkozik a `cfg/` fájlokra és a `../resources` mappára.

**Linux:**

```bash
cd /útvonal/a/Nova-rp/server
bash ~/FXServer/server/run.sh +exec server.cfg
```

**Windows (PowerShell):**

```powershell
cd C:\útvonal\Nova-rp\server
C:\FXServer\server\FXServer.exe +exec server.cfg
```

**Várt eredmény** — a konzol végén megjelenik a NOVA banner:

```
  ███ NOVA RP
  Verzió:        0.1.0
  Környezet:     development
  nova_lib:      OK  — betöltve, séma-validátor működik
  identity:      OK  — NOVA RP · development
  security:      OK  — 3 kötelező beállítás rendben
```

Ha `HIBA` sort látsz, a mellette lévő üzenet megmondja, mit kell javítani.

---

## 8. Tesztek futtatása

```bash
# Lua unit tesztek — a repository gyökeréből, FXServer NÉLKÜL futnak
busted

# Tooling tesztek + típusellenőrzés — a tools/ mappából
cd tools
npm test
npm run typecheck

# Statikus elemzés (ha telepítetted a luacheck-et)
luacheck resources tests
```

**Várt eredmény:** minden zöld. Ha nem, az hiba — ne menj tovább.

---

## Gyakori hibák

| Hibaüzenet / tünet | Ok | Megoldás |
| --- | --- | --- |
| `no license key was specified` | nincs licenckulcs a 90-local.cfg-ben | add meg a kulcsot, vagy `set sv_lan true` fejlesztéshez |
| `couldn't find resource nova_lib` | rossz mappából indítottad a szervert | a `server/` mappából indíts (`cd Nova-rp/server`) |
| `Failed to start resource` és nincs resource | hiányzó `+exec server.cfg` | add hozzá a parancshoz |
| `nova_lib: HIBA` a bannerben | a nova_lib nem indult el előbb | ellenőrizd az `ensure` sorrendet a `cfg/20-resources.cfg`-ben |
| `security: HIBA` a bannerben | valamelyik kötelező biztonsági convar hiányzik | ne kommenteld ki a `cfg/10-security.cfg` sorait |
| `identity: HIBA` | a `nova:server:name` vagy `nova:environment` nincs beállítva | `cfg/00-base.cfg` |
| `checksum-eltérés` a vendor:install-nál | a letöltött csomag nem egyezik a rögzítettel | **ne telepítsd**, jelezd a csapatnak |
| `Nem találom a repository gyökerét` | nem a klónozott repóban futtatod a CLI-t | `cd` a repóba |
| busted: `module 'busted' not found` | a luarocks bin nincs a PATH-ban | `export PATH="$HOME/.luarocks/bin:$PATH"` |

Ha itt nincs benne a hibád: nyiss egy issue-t a pontos hibaüzenettel, a
parancssal és a `npm run doctor` kimenetével.

---

## Mi következik

- A projekt állapota és terve: [README.md](README.md)
- Architektúra: [docs/01-architecture/overview.md](docs/01-architecture/overview.md)
- Fázisonkénti haladás: [docs/roadmap.md](docs/roadmap.md)
