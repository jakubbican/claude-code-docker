# Docker Průvodce pro Claude Code Development

Tento dokument vysvětluje základní Docker příkazy a operace pro tvoje vývojové prostředí.

---

## Základní koncepty

### Co je co?

| Pojem | Vysvětlení | Analogie |
|-------|------------|----------|
| **Image** | Šablona/recept pro kontejner | ISO soubor pro instalaci OS |
| **Container** | Běžící instance image | Nainstalovaný a spuštěný OS |
| **Volume** | Persistentní úložiště | Externí disk připojený k počítači |
| **Dockerfile** | Instrukce pro vytvoření image | Instalační skript |
| **docker-compose.yml** | Konfigurace celého prostředí | Konfigurační soubor |

### Životní cyklus

```
Dockerfile → (build) → Image → (run) → Container
                                ↓
                         Volume (data přežijí)
```

---

## Bezpečnostní features

### Firewall Whitelist

Kontejner má vestavěný firewall s těmito pravidly:

#### Lokální síť (LAN) - PLNĚ POVOLENA

| Rozsah | Popis |
|--------|-------|
| `192.168.0.0/16` | Domácí sítě |
| `10.0.0.0/8` | Privátní sítě class A |
| `172.16.0.0/12` | Privátní sítě class B |
| `255.255.255.255` | UDP broadcast |
| `224.0.0.0/4` | Multicast (mDNS, SSDP) |
| `169.254.0.0/16` | Link-local |

**Všechny porty TCP/UDP** na lokální síti jsou povoleny – můžeš:
- Komunikovat přes WebSockets na libovolném portu
- Posílat/přijímat UDP broadcast pro device discovery
- Připojovat se k lokálním službám (databáze, API, IoT zařízení)

#### Internet - pouze whitelist

| Kategorie | Domény |
|-----------|--------|
| **Anthropic API** | api.anthropic.com, statsig.anthropic.com, sentry.io |
| **npm** | registry.npmjs.org, npmjs.org, npmjs.com |
| **GitHub** | github.com, api.github.com, raw.githubusercontent.com |
| **Playwright** | playwright.azureedge.net |
| **Node.js** | nodejs.org, registry.yarnpkg.com |

**Vše ostatní na veřejném internetu je BLOKOVÁNO** - Claude Code nemůže:
- Stahovat z neznámých zdrojů
- Odesílat data na neznámé servery
- Komunikovat s libovolnými API na internetu

### Konfigurace firewallu

```yaml
# V docker-compose.yml
environment:
  # Zapnout/vypnout firewall (default: true)
  - ENABLE_FIREWALL=true
  
  # Pokud true, kontejner se nespustí když firewall selže
  - FIREWALL_REQUIRED=false
```

### Přidání vlastní domény do whitelist

Uprav soubor `init-firewall.sh`:

```bash
ALLOWED_DOMAINS=(
    # ... existující domény ...
    
    # Přidej vlastní:
    "api.moje-sluzba.com"
    "cdn.example.org"
)
```

Pak rebuild: `docker compose down && docker compose up -d --build`

---

## Volumes - Co kde přežije

Máme 4 volumes:

| Volume | Obsah | Přežije reset? |
|--------|-------|----------------|
| `~/projects` | Tvůj kód, git repos | ✅ Vždy (je na hostu) |
| `claude-config` | Login, session, nastavení Claude | ✅ Ano |
| `npm-cache` | Stažené npm balíčky | ✅ Ano |
| `playwright-cache` | Chromium pro testy | ✅ Ano |

### Proč oddělený claude-config?

- **Credentials přežijí reset** - nemusíš se znovu přihlašovat
- **Session history zůstane** - Claude si pamatuje kontext
- **Oddělené od projektu** - credentials nejsou v git repo

### Práce s volumes

```bash
# Seznam volumes
docker volume ls

# Detail volume
docker volume inspect claude-code-docker_claude-config

# Vymazat konkrétní volume (POZOR - ztratíš data!)
docker volume rm claude-code-docker_claude-config

# Vymazat VŠECHNY volumes tohoto projektu
docker compose down -v
```

---

## Základní příkazy

### Docker Compose (doporučeno)

```bash
# Přejdi do složky s docker-compose.yml
cd ~/claude-code-docker
```

#### Spuštění

```bash
# První spuštění (nebo po změně Dockerfile)
docker compose up -d --build

# Běžné spuštění (když už máš image)
docker compose up -d
```

| Přepínač | Význam |
|----------|--------|
| `up` | Vytvoř a spusť kontejnery |
| `-d` | Detached mode - běží na pozadí |
| `--build` | Přesestavit image před spuštěním |

#### Připojení do kontejneru

```bash
# Otevři bash shell v kontejneru
docker compose exec dev bash

# Spusť jednorázový příkaz
docker compose exec dev node --version
docker compose exec dev claude --version
```

| Přepínač | Význam |
|----------|--------|
| `exec` | Spusť příkaz v běžícím kontejneru |
| `dev` | Název služby z docker-compose.yml |
| `bash` | Příkaz ke spuštění (shell) |

#### Zastavení

```bash
# Zastav kontejner (data zůstanou)
docker compose stop

# Zastav a odstraň kontejner (volumes zůstanou)
docker compose down

# Zastav, odstraň kontejner I volumes (POZOR - smaže cache + credentials!)
docker compose down -v
```

| Přepínač | Význam |
|----------|--------|
| `stop` | Pouze zastav, kontejner zůstane |
| `down` | Zastav a odstraň kontejner |
| `-v` | Odstraň i volumes (npm cache, claude credentials!) |

---

## Tmux - Persistentní sessions

Tmux ti umožní spustit Claude Code, odpojit se, a později se vrátit. Claude pokračuje v práci i když zavřeš SSH.

### Základní workflow

```bash
# Připoj se do kontejneru
docker compose exec dev bash

# Spusť novou tmux session
tmux new -s claude

# Teď jsi v tmux - spusť Claude Code
cd /workspace/canoe-scoreboard
claude --dangerously-skip-permissions

# Claude pracuje... můžeš se odpojit:
# Stiskni: Ctrl+B, pak D (detach)

# Vrátíš se na normální shell, můžeš zavřít SSH
exit
```

### Návrat k běžící session

```bash
# Připoj se zpět do kontejneru
docker compose exec dev bash

# Zobraz běžící sessions
tmux ls

# Připoj se k session "claude"
tmux attach -t claude
```

### Nejdůležitější klávesy

| Klávesa | Akce |
|---------|------|
| `Ctrl+B, D` | Odpojit se (detach) - session běží dál |
| `Ctrl+B, C` | Nové okno |
| `Ctrl+B, N` | Další okno |
| `Ctrl+B, P` | Předchozí okno |
| `Ctrl+B, "` | Rozdělit horizontálně |
| `Ctrl+B, %` | Rozdělit vertikálně |
| `Ctrl+B, šipky` | Přepínání mezi panely |
| `Ctrl+B, [` | Scroll mode (q pro ukončení) |

### Více sessions

```bash
# Vytvoř pojmenovanou session
tmux new -s nazev

# Seznam sessions
tmux ls

# Připoj se ke konkrétní
tmux attach -t nazev

# Ukonči session (zevnitř)
exit

# Nebo zvenku
tmux kill-session -t nazev
```

### Tip: Rychlý alias

Na RPI přidej do `~/.bashrc`:

```bash
alias claude-attach='docker compose exec dev tmux attach -t claude 2>/dev/null || docker compose exec dev tmux new -s claude'
```

Pak stačí: `claude-attach` - připojí se k existující session nebo vytvoří novou.

---

### Level 1: Restart (nejrychlejší)
```bash
docker compose restart
```
- Restartuje kontejner
- Firewall se znovu inicializuje
- Vše zůstane zachováno

### Level 2: Měkký reset
```bash
docker compose down && docker compose up -d
```
- Nový kontejner
- Volumes (credentials, cache) zůstanou
- Systémové změny v kontejneru se ztratí

### Level 3: Reset bez credentials
```bash
docker compose down
docker volume rm claude-code-docker_claude-config
docker compose up -d
```
- Nový kontejner
- Musíš se znovu přihlásit do Claude
- npm cache zůstane

### Level 4: Tvrdý reset (čistý stav)
```bash
docker compose down -v && docker compose up -d --build
```
- Vše od začátku
- Ztratíš: credentials, npm cache, playwright cache
- Tvůj kód v ~/projects zůstane!

### Level 5: Úplný reset včetně image
```bash
docker compose down -v --rmi all && docker compose up -d --build
```
- Stáhne se znovu base image
- Přeinstaluje se Claude Code, Playwright
- Nejdelší, ale nejčistší

---

## Sledování a diagnostika

### Kontrola firewallu

```bash
# Zobraz aktivní iptables pravidla
docker compose exec dev sudo iptables -L OUTPUT -n

# Test - tohle by mělo fungovat:
docker compose exec dev curl -s https://api.anthropic.com

# Test - tohle by mělo SELHAT (blokováno):
docker compose exec dev curl -s https://example.com
# Mělo by timeoutnout nebo vrátit chybu
```

### Logy

```bash
# Zobraz logy (posledních 100 řádků)
docker compose logs --tail 100

# Sleduj logy živě (vidíš firewall inicializaci)
docker compose logs -f

# Logy konkrétní služby
docker compose logs dev
```

### Stav

```bash
# Zobraz běžící kontejnery
docker compose ps

# Využití zdrojů (CPU, RAM)
docker stats
```

---

## Časté scénáře

### 1. Začínám nový den práce

```bash
cd ~/claude-code-docker
docker compose up -d          # Spusť prostředí
docker compose exec dev bash  # Připoj se
cd /workspace/muj-projekt     # Přejdi do projektu
claude                        # Spusť Claude Code
```

### 2. Něco se pokazilo, chci reset

```bash
# Rychlý reset (zachová credentials i cache)
docker compose down && docker compose up -d

# Pokud nepomůže - tvrdý reset
docker compose down -v && docker compose up -d --build
```

### 3. Potřebuji přidat doménu do whitelist

```bash
# 1. Uprav init-firewall.sh
nano init-firewall.sh

# 2. Rebuild
docker compose down && docker compose up -d --build
```

### 4. Chci dočasně vypnout firewall

```bash
# Uprav docker-compose.yml
# Změň: ENABLE_FIREWALL=false

# Restartuj
docker compose down && docker compose up -d
```

⚠️ **POZOR:** S vypnutým firewallem má Claude Code neomezený přístup k síti!

### 5. Dev server není vidět z laptopu

Dev server musí poslouchat na `0.0.0.0`:

```bash
# Vite
npm run dev -- --host 0.0.0.0

# Create React App
HOST=0.0.0.0 npm start

# Next.js
npm run dev -- -H 0.0.0.0
```

Pak na laptopu otevři: `http://<rpi-ip>:5173`

### 6. Ztratil jsem Claude credentials

```bash
# Smaž claude-config volume
docker compose down
docker volume rm claude-code-docker_claude-config
docker compose up -d

# Znovu se přihlas
docker compose exec dev bash
claude  # Vyzve tě k přihlášení
```

---

## Struktura souborů

```
~/
├── claude-code-docker/          # Docker konfigurace
│   ├── Dockerfile               # Definice image
│   ├── docker-compose.yml       # Konfigurace prostředí
│   ├── init-firewall.sh         # Firewall whitelist pravidla
│   ├── entrypoint.sh            # Startup script
│   └── DOCKER-GUIDE.md          # Tento soubor
│
└── projects/                    # TVOJE PROJEKTY (přežijí vše!)
    ├── react-app/
    ├── fullstack-project/
    └── ...
```

---

## Tipy a triky

### Aliasy pro pohodlí

Přidej do `~/.bashrc` na RPI:

```bash
# Docker Compose shortcuts
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dce='docker compose exec dev bash'
alias dcl='docker compose logs -f'
alias dcr='docker compose restart'

# Resety
alias dc-reset='docker compose down && docker compose up -d'
alias dc-hardreset='docker compose down -v && docker compose up -d --build'

# Firewall check
alias dc-firewall='docker compose exec dev sudo iptables -L OUTPUT -n'
```

Po přidání: `source ~/.bashrc`

### Automatické spuštění po restartu RPI

Díky `restart: unless-stopped` v docker-compose.yml se kontejner spustí automaticky po restartu RPI.

---

## Řešení problémů

### Firewall blokuje něco co potřebuji

1. Zjisti jakou doménu potřebuješ (z error message)
2. Přidej ji do `init-firewall.sh` v sekci `ALLOWED_DOMAINS`
3. `docker compose down && docker compose up -d --build`

### "iptables: Permission denied"

Zkontroluj že docker-compose.yml má:
```yaml
cap_add:
  - NET_ADMIN
```

### Kontejner se nespustí

```bash
# Zkontroluj logy
docker compose logs

# Možná příčina: firewall selhal
# Řešení: dočasně vypni FIREWALL_REQUIRED nebo ENABLE_FIREWALL
```

### Playwright testy padají

ARM emulace může být pomalejší. Zvyš timeout:

```typescript
// playwright.config.ts
timeout: 60000,  // 60 sekund
```

---

## Rychlý přehled příkazů

| Co chci udělat | Příkaz |
|----------------|--------|
| Spustit prostředí | `docker compose up -d` |
| Připojit se do shellu | `docker compose exec dev bash` |
| Zastavit prostředí | `docker compose down` |
| Rychlý reset | `docker compose down && docker compose up -d` |
| Tvrdý reset | `docker compose down -v && docker compose up -d --build` |
| Zobrazit logy | `docker compose logs -f` |
| Zkontrolovat firewall | `docker compose exec dev sudo iptables -L OUTPUT -n` |
| Stav kontejnerů | `docker compose ps` |
| Využití zdrojů | `docker stats` |
