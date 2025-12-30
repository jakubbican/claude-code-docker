# RPI 5 + Claude Code + Docker: Quick Start Guide

Kompletní průvodce nastavením izolovaného vývojového prostředí pro Claude Code na Raspberry Pi 5.

## Bezpečnostní features

| Feature | Popis |
|---------|-------|
| 🔥 **Firewall whitelist** | Pouze npm, GitHub, Anthropic API – zbytek blokován |
| 🔐 **Oddělené credentials** | Claude login v samostatném volume |
| 👤 **Non-root user** | Claude Code běží pod neprivilegovaným uživatelem |
| 📦 **Izolace** | Kontejner oddělený od host systému |

---

## Obsah balíčku

| Soubor | Účel |
|--------|------|
| `setup-host.sh` | Skript pro přípravu RPI (Docker, složky) |
| `Dockerfile` | Definice vývojového prostředí |
| `docker-compose.yml` | Konfigurace kontejneru |
| `init-firewall.sh` | Firewall whitelist pravidla |
| `entrypoint.sh` | Startup script s validací |
| `DOCKER-GUIDE.md` | Podrobný průvodce Docker příkazy |
| `CLAUDE.md.template` | Šablona instrukcí pro Claude Code |
| `docker-compose.research.yml` | Research instance bez firewallu |

---

## Více instancí

Můžeš spustit dvě instance současně:

| Instance | Compose soubor | Firewall | Účel |
|----------|----------------|----------|------|
| **Hlavní** | `docker-compose.yml` | Zapnutý | Vývoj, autonomní režim |
| **Research** | `docker-compose.research.yml` | Vypnutý | Browsing, research, analýza |

### Spuštění research instance

```bash
# Spustit (hlavní instance musí běžet jako první - vytváří volumes)
docker compose -f docker-compose.research.yml up -d

# Připojit se
docker compose -f docker-compose.research.yml exec dev bash

# Zastavit
docker compose -f docker-compose.research.yml down
```

Research instance:
- Sdílí credentials s hlavní instancí
- Sdílí mount `~/projects:/workspace`
- Nemá mapované porty (nepotřebuje dev servery)
- **Má neomezený přístup na internet**

---

## Krok za krokem

### 1. Příprava SD karty (pokud ještě nemáš)

1. Stáhni [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Vyber **Raspberry Pi OS Lite (64-bit)**
3. V nastavení (ozubené kolečko):
   - Nastav hostname (např. `claude-dev`)
   - Povol SSH
   - Nastav uživatele a heslo
   - Nastav WiFi (nebo použij ethernet)
4. Zapiš na SD kartu a vlož do RPI

### 2. První připojení k RPI

```bash
# Z laptopu - najdi RPI v síti
ping claude-dev.local

# Připoj se přes SSH
ssh tvuj-user@claude-dev.local
```

### 3. Přenos souborů na RPI

```bash
# Na laptopu - zkopíruj celou složku na RPI
scp -r /cesta/k/rpi-claude-code tvuj-user@claude-dev.local:~/claude-code-docker
```

### 4. Spuštění setup skriptu

```bash
# Na RPI (přes SSH)
cd ~/claude-code-docker
chmod +x setup-host.sh
./setup-host.sh
```

**Po dokončení se ODHLÁS a znovu PŘIHLAS** (nebo restartuj):

```bash
exit
ssh tvuj-user@claude-dev.local
```

### 5. Ověření Dockeru

```bash
docker run hello-world
```

### 6. Konfigurace Git údajů

Uprav `docker-compose.yml`:

```yaml
environment:
  - GIT_AUTHOR_NAME=Tvoje Jméno
  - GIT_AUTHOR_EMAIL=tvuj@email.cz
  - GIT_COMMITTER_NAME=Tvoje Jméno  
  - GIT_COMMITTER_EMAIL=tvuj@email.cz
```

### 7. Build a spuštění kontejneru

```bash
cd ~/claude-code-docker
docker compose up -d --build
```

První build trvá **10-20 minut**. Sleduj průběh:

```bash
docker compose logs -f
```

Měl bys vidět:
```
[STARTUP] Inicializuji firewall whitelist...
[FIREWALL] Povoluji HTTPS na whitelisted domény...
[FIREWALL] ✓ api.anthropic.com → ...
[STARTUP] Firewall úspěšně aktivován
```

### 8. Připojení do kontejneru

```bash
docker compose exec dev bash
```

Ověř instalaci:

```bash
node --version      # → v20.x.x
claude --version    # → Claude Code verze
```

### 9. Přihlášení do Claude

```bash
claude
# Při prvním spuštění budeš vyzván k přihlášení
# Credentials se uloží do volume a přežijí restart
```

---

## Firewall - Co je povoleno

### Lokální síť (LAN) - vše povoleno

| Rozsah | Popis |
|--------|-------|
| `192.168.0.0/16` | Domácí sítě |
| `10.0.0.0/8` | Privátní sítě class A |
| `172.16.0.0/12` | Privátní sítě class B |
| `255.255.255.255` | UDP broadcast |
| `224.0.0.0/4` | Multicast (mDNS, SSDP) |

→ Můžeš komunikovat s lokálními zařízeními na **libovolných portech** (TCP/UDP)

### Internet - pouze whitelist

| Služba | Domény |
|--------|--------|
| **Anthropic** | api.anthropic.com, statsig.anthropic.com |
| **npm** | registry.npmjs.org, npmjs.org |
| **GitHub** | github.com, api.github.com, raw.githubusercontent.com |
| **Playwright** | playwright.azureedge.net |

**Vše ostatní na internetu je BLOKOVÁNO.**

### Ověření firewallu

```bash
# Tohle funguje:
curl -s https://registry.npmjs.org | head

# Tohle je blokováno (timeout):
curl -s --connect-timeout 5 https://example.com
```

### Přidání vlastní domény

1. Uprav `init-firewall.sh` – přidej doménu do `ALLOWED_DOMAINS`
2. Rebuild: `docker compose down && docker compose up -d --build`

### Dočasné vypnutí firewallu

V `docker-compose.yml` změň:
```yaml
- ENABLE_FIREWALL=false
```

⚠️ **Nedoporučeno pro autonomní režim!**

---

## Volumes - Co přežije restart

| Volume | Obsah | Reset level |
|--------|-------|-------------|
| `~/projects` | Tvůj kód | Nikdy se nesmaže |
| `claude-config` | Login, session | Přežije restart i `down` |
| `npm-cache` | npm balíčky | Přežije restart i `down` |
| `playwright-cache` | Chromium | Přežije restart i `down` |

### Úrovně resetu

```bash
# Level 1: Restart (vše zůstane)
docker compose restart

# Level 2: Měkký reset (volumes zůstanou)
docker compose down && docker compose up -d

# Level 3: Tvrdý reset (ztratíš credentials, cache)
docker compose down -v && docker compose up -d --build
```

---

## Denní workflow

### Začátek práce

```bash
ssh user@claude-dev.local
cd ~/claude-code-docker
docker compose up -d        # Pokud neběží
docker compose exec dev bash
cd /workspace/canoe-scoreboard
claude
```

### První spuštění - klonování projektu

```bash
# V kontejneru
cd /workspace
git clone https://github.com/jakubbican/canoe-scoreboard.git
cd canoe-scoreboard
npm install
```

### Spuštění dev serveru

```bash
# V kontejneru, ve složce projektu
npm run dev -- --host 0.0.0.0

# Na laptopu otevři:
# http://claude-dev.local:3000/?type=horizontal
# http://claude-dev.local:3000/?type=vertical
# http://claude-dev.local:3000/?type=ledwall
```

### Autonomní režim (vypnuté ochrany)

```bash
claude --dangerously-skip-permissions
```

Díky firewallu je to bezpečnější – Claude Code nemůže komunikovat s neznámými servery.

### Testování z laptopu

```bash
# V kontejneru spusť dev server
cd /workspace/canoe-scoreboard
npm run dev -- --host 0.0.0.0

# Na laptopu otevři různé layouty:
http://claude-dev.local:3000/?type=horizontal
http://claude-dev.local:3000/?type=vertical
http://claude-dev.local:3000/?type=ledwall&ledwallExactSize=true
```

### Playwright testy

```bash
# V kontejneru
cd /workspace/canoe-scoreboard
npx playwright test
npx playwright test --update-snapshots  # aktualizace baseline
```

---

## Troubleshooting

### Firewall blokuje potřebnou doménu

```bash
# Zjisti jakou doménu potřebuješ z error message
# Přidej ji do init-firewall.sh
# Rebuild: docker compose down && docker compose up -d --build
```

### "iptables: Permission denied"

Zkontroluj `docker-compose.yml`:
```yaml
cap_add:
  - NET_ADMIN
```

### Ztratil jsem Claude credentials

```bash
docker volume rm claude-code-docker_claude-config
docker compose up -d
docker compose exec dev bash
claude  # Znovu se přihlas
```

### Nedostatek místa na RPI

```bash
docker system prune -a
```

---

## SSH bez hesla

```bash
# Na laptopu
ssh-keygen -t ed25519 -C "tvuj@email.cz"
ssh-copy-id user@claude-dev.local
```

## Užitečné aliasy (na laptopu)

```bash
# ~/.bashrc nebo ~/.zshrc
alias rpi='ssh user@claude-dev.local'
alias rpi-claude='ssh user@claude-dev.local -t "cd ~/claude-code-docker && docker compose exec dev bash"'
```

---

## Další dokumentace

- **DOCKER-GUIDE.md** - Podrobný průvodce Docker příkazy
- **CLAUDE.md.template** - Šablona pro instrukce Claude Code v projektu
