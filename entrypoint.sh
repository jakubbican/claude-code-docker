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
# Informace o prostředí
#-------------------------------------------------------------------------------
echo ""
echo -e "${GREEN}[INFO]${NC} Node.js: $(node --version)"
echo -e "${GREEN}[INFO]${NC} npm: $(npm --version)"
echo -e "${GREEN}[INFO]${NC} Claude Code: $(claude --version 2>/dev/null || echo 'checking...')"
echo -e "${GREEN}[INFO]${NC} Git: $(git --version)"
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
