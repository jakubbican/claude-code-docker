#!/bin/bash
#===============================================================================
# Entrypoint Script pro Claude Code Container
#===============================================================================
# Tento script se spustí při každém startu kontejneru:
# 1. Inicializuje firewall (pokud je ENABLE_FIREWALL=true)
# 2. Validuje že pravidla jsou aktivní
# 3. Spustí hlavní příkaz (CMD)
#===============================================================================

set -e

# Barvy
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Claude Code Container Starting...    ${NC}"
echo -e "${GREEN}========================================${NC}"

#-------------------------------------------------------------------------------
# Firewall inicializace
#-------------------------------------------------------------------------------
if [ "${ENABLE_FIREWALL:-true}" = "true" ]; then
    echo -e "${YELLOW}[STARTUP]${NC} Inicializuji firewall whitelist..."
    
    # Spusť firewall script jako root
    if sudo /usr/local/bin/init-firewall.sh; then
        echo -e "${GREEN}[STARTUP]${NC} Firewall úspěšně aktivován"
    else
        echo -e "${RED}[STARTUP]${NC} CHYBA: Firewall se nepodařilo aktivovat!"
        
        # Pokud je FIREWALL_REQUIRED=true, ukonči kontejner
        if [ "${FIREWALL_REQUIRED:-false}" = "true" ]; then
            echo -e "${RED}[STARTUP]${NC} FIREWALL_REQUIRED=true → ukončuji kontejner"
            exit 1
        else
            echo -e "${YELLOW}[STARTUP]${NC} Pokračuji bez firewallu (FIREWALL_REQUIRED=false)"
        fi
    fi
else
    echo -e "${YELLOW}[STARTUP]${NC} Firewall je VYPNUTÝ (ENABLE_FIREWALL=false)"
    echo -e "${YELLOW}[STARTUP]${NC} ⚠️  Kontejner má neomezený přístup k síti!"
fi

#-------------------------------------------------------------------------------
# Inicializace bash history (persistent across rebuilds)
#-------------------------------------------------------------------------------
HIST_DIR="/home/node/.bash_history_dir"
HIST_FILE="${HIST_DIR}/.bash_history"

# Vytvoř adresář a soubor se správnými právy (jako root, pak změň vlastníka)
sudo mkdir -p "${HIST_DIR}" 2>/dev/null || true
sudo touch "${HIST_FILE}" 2>/dev/null || true
sudo chown -R node:node "${HIST_DIR}" 2>/dev/null || true

# Přidej HISTFILE do ~/.bashrc pokud tam ještě není
if ! grep -q "HISTFILE=${HIST_FILE}" /home/node/.bashrc 2>/dev/null; then
    cat >> /home/node/.bashrc << EOF

# Persistent bash history (added by entrypoint.sh)
export HISTFILE=${HIST_FILE}
export HISTSIZE=10000
export HISTFILESIZE=20000
EOF
    echo -e "${GREEN}[STARTUP]${NC} HISTFILE přidán do ~/.bashrc"
fi

#-------------------------------------------------------------------------------
# Informace o prostředí
#-------------------------------------------------------------------------------
echo ""
echo -e "${GREEN}[INFO]${NC} Node.js: $(node --version)"
echo -e "${GREEN}[INFO]${NC} npm: $(npm --version)"
echo -e "${GREEN}[INFO]${NC} Claude Code: $(claude --version 2>/dev/null || echo 'checking...')"
echo -e "${GREEN}[INFO]${NC} Git: $(git --version)"
echo -e "${GREEN}[INFO]${NC} gh CLI: $(gh --version 2>/dev/null | head -1 || echo 'not installed')"
echo -e "${GREEN}[INFO]${NC} Workspace: /workspace"
echo -e "${GREEN}[INFO]${NC} Claude config: ${CLAUDE_CONFIG_DIR:-/home/node/.claude}"
echo ""

#-------------------------------------------------------------------------------
# Kontrola Claude credentials
#-------------------------------------------------------------------------------
if [ -f "${CLAUDE_CONFIG_DIR:-/home/node/.claude}/.credentials.json" ]; then
    echo -e "${GREEN}[INFO]${NC} Claude credentials nalezeny ✓"
else
    echo -e "${YELLOW}[INFO]${NC} Claude credentials nenalezeny"
    echo -e "${YELLOW}[INFO]${NC} Při prvním spuštění 'claude' budeš vyzván k přihlášení"
fi

#-------------------------------------------------------------------------------
# Kontrola SSH klíčů
#-------------------------------------------------------------------------------
if [ -f "/home/node/.ssh/id_ed25519" ] || [ -f "/home/node/.ssh/id_rsa" ]; then
    echo -e "${GREEN}[INFO]${NC} SSH klíče nalezeny ✓"
else
    echo -e "${YELLOW}[INFO]${NC} SSH klíče nenalezeny"
    echo -e "${YELLOW}[INFO]${NC} Pro GitHub: zkopíruj klíče do /home/node/.ssh/ nebo viz keysbackup/INSTRUCTIONS.md"
fi

#-------------------------------------------------------------------------------
# Kontrola gh CLI credentials
#-------------------------------------------------------------------------------
if [ -f "/home/node/.config/gh/hosts.yml" ]; then
    echo -e "${GREEN}[INFO]${NC} GitHub CLI credentials nalezeny ✓"
else
    echo -e "${YELLOW}[INFO]${NC} GitHub CLI credentials nenalezeny"
    echo -e "${YELLOW}[INFO]${NC} Pro přihlášení spusť: gh auth login"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Container ready!                     ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Pro připojení použij: ${YELLOW}docker compose exec dev bash${NC}"
echo -e "Pro spuštění Claude:  ${YELLOW}claude${NC}"
echo -e "Autonomní režim:      ${YELLOW}claude --dangerously-skip-permissions${NC}"
echo ""

#-------------------------------------------------------------------------------
# Spuštění hlavního příkazu (z CMD)
#-------------------------------------------------------------------------------
exec "$@"
